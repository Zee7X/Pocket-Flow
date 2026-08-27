-- =============================================================================
-- PocketFlow Migration: Fix pf_allocate_salary with re-allocation upsert and unified JSON keys
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pf_allocate_salary(
    p_salary_amount BIGINT,
    p_salary_date   DATE,
    p_period_month  INT,
    p_period_year   INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id            UUID;
    v_salary_entry_id    UUID;
    v_baseline_income    BIGINT;
    v_extra_income       BIGINT;
    v_remaining          BIGINT;
    v_total_income       BIGINT;
    v_allow_overalloc    BOOLEAN;

    v_rule               RECORD;
    v_allocation_amount  BIGINT;
    v_pct_base           BIGINT;

    v_prop_total_pct     NUMERIC;
    v_prop_rules         JSONB := '[]'::JSONB;
    v_prop_rule          JSONB;

    v_allocations        JSONB := '[]'::JSONB;
    v_warnings           JSONB := '[]'::JSONB;
    v_total_allocated    BIGINT := 0;

    v_existing_entry_id  UUID;
    v_income_cat_id      UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_salary_amount <= 0 THEN
        RAISE EXCEPTION 'salary_amount must be > 0';
    END IF;
    IF p_period_month < 1 OR p_period_month > 12 THEN
        RAISE EXCEPTION 'period_month must be between 1 and 12';
    END IF;
    IF p_period_year < 2000 THEN
        RAISE EXCEPTION 'period_year must be >= 2000';
    END IF;

    -- Check if salary entry already exists for this period. If yes, update it & re-generate budgets cleanly.
    SELECT id INTO v_existing_entry_id
    FROM public.pf_salary_entries
    WHERE user_id = v_user_id
      AND period_month = p_period_month
      AND period_year  = p_period_year;

    IF FOUND THEN
        UPDATE public.pf_salary_entries
        SET amount = p_salary_amount,
            salary_date = p_salary_date,
            updated_at = NOW()
        WHERE id = v_existing_entry_id
        RETURNING id INTO v_salary_entry_id;

        -- Clean up existing monthly budgets for this period
        DELETE FROM public.pf_monthly_budgets
        WHERE user_id = v_user_id
          AND period_month = p_period_month
          AND period_year  = p_period_year;
    ELSE
        -- 1. Insert salary entry
        INSERT INTO public.pf_salary_entries (user_id, amount, salary_date, period_month, period_year)
        VALUES (v_user_id, p_salary_amount, p_salary_date, p_period_month, p_period_year)
        RETURNING id INTO v_salary_entry_id;

        -- 2. Automatically record Income Transaction
        SELECT id INTO v_income_cat_id
        FROM public.pf_categories
        WHERE user_id = v_user_id
          AND type = 'income'
        ORDER BY (name = 'Gaji Pokok') DESC, sort_order ASC
        LIMIT 1;

        INSERT INTO public.pf_transactions (
            user_id,
            category_id,
            type,
            amount,
            transaction_date,
            description,
            payment_method
        )
        VALUES (
            v_user_id,
            v_income_cat_id,
            'income',
            p_salary_amount,
            p_salary_date,
            'Gaji Periode ' || p_period_month || '/' || p_period_year,
            'Transfer Bank'
        );
    END IF;

    v_total_income := p_salary_amount;
    v_remaining    := p_salary_amount;

    SELECT
        COALESCE(baseline_income, 0),
        COALESCE(allow_overallocation, FALSE)
    INTO v_baseline_income, v_allow_overalloc
    FROM public.pf_user_finance_settings
    WHERE user_id = v_user_id;

    IF NOT FOUND THEN
        v_baseline_income := 0;
        v_allow_overalloc := FALSE;
    END IF;

    IF v_baseline_income > 0 AND p_salary_amount > v_baseline_income THEN
        v_extra_income := p_salary_amount - v_baseline_income;
    ELSE
        v_extra_income := 0;
    END IF;

    -- Process allocation rules in priority order
    FOR v_rule IN
        SELECT
            ar.id,
            ar.name,
            ar.category_id,
            ar.allocation_type,
            ar.fixed_amount,
            ar.percentage,
            ar.percentage_base,
            ar.min_amount,
            ar.max_amount,
            ar.priority,
            ar.is_required
        FROM public.pf_allocation_rules ar
        WHERE ar.user_id  = v_user_id
          AND ar.is_active = TRUE
        ORDER BY ar.priority ASC, ar.created_at ASC
    LOOP
        v_allocation_amount := 0;

        IF v_remaining <= 0 THEN
            IF v_rule.is_required THEN
                v_warnings := v_warnings || jsonb_build_object(
                    'rule_id',   v_rule.id,
                    'rule_name', v_rule.name,
                    'code',      'INSUFFICIENT_FUNDS',
                    'message',   'No remaining income for required rule: ' || v_rule.name
                );
                v_allocation_amount := 0;
            ELSE
                CONTINUE;
            END IF;
        ELSE
            IF v_rule.allocation_type = 'fixed' THEN
                v_allocation_amount := v_rule.fixed_amount;
                IF v_allocation_amount > v_remaining THEN
                    IF v_rule.is_required THEN
                        v_warnings := v_warnings || jsonb_build_object(
                            'rule_id',   v_rule.id,
                            'rule_name', v_rule.name,
                            'code',      'SHORTFALL',
                            'shortfall', v_allocation_amount - v_remaining,
                            'message',   'Insufficient income for required fixed rule: ' || v_rule.name
                        );
                    END IF;
                    v_allocation_amount := GREATEST(v_remaining, 0);
                END IF;

            ELSIF v_rule.allocation_type = 'capped' THEN
                v_allocation_amount := LEAST(v_rule.fixed_amount, v_remaining);

            ELSIF v_rule.allocation_type = 'percentage' THEN
                IF v_rule.percentage_base = 'total_income' THEN
                    v_pct_base := v_total_income;
                ELSIF v_rule.percentage_base = 'extra_income' THEN
                    v_pct_base := v_extra_income;
                ELSE
                    v_pct_base := v_remaining;
                END IF;

                v_allocation_amount := FLOOR((v_pct_base * v_rule.percentage) / 100.0);

                IF v_rule.min_amount IS NOT NULL AND v_allocation_amount < v_rule.min_amount THEN
                    v_allocation_amount := v_rule.min_amount;
                END IF;
                IF v_rule.max_amount IS NOT NULL AND v_allocation_amount > v_rule.max_amount THEN
                    v_allocation_amount := v_rule.max_amount;
                END IF;

                v_allocation_amount := LEAST(v_allocation_amount, v_remaining);

            ELSIF v_rule.allocation_type = 'proportional' THEN
                v_prop_rules := v_prop_rules || jsonb_build_object(
                    'rule_id',     v_rule.id,
                    'category_id', v_rule.category_id,
                    'name',        v_rule.name,
                    'percentage',  v_rule.percentage,
                    'min_amount',  v_rule.min_amount,
                    'max_amount',  v_rule.max_amount
                );
                CONTINUE;

            ELSIF v_rule.allocation_type = 'remaining' THEN
                v_allocation_amount := v_remaining;
            END IF;
        END IF;

        IF v_allocation_amount > 0 THEN
            INSERT INTO public.pf_monthly_budgets (
                user_id,
                category_id,
                salary_entry_id,
                allocation_rule_id,
                period_month,
                period_year,
                allocated_amount,
                spent_amount
            )
            VALUES (
                v_user_id,
                v_rule.category_id,
                v_salary_entry_id,
                v_rule.id,
                p_period_month,
                p_period_year,
                v_allocation_amount,
                0
            );

            v_remaining         := v_remaining - v_allocation_amount;
            v_total_allocated   := v_total_allocated + v_allocation_amount;

            v_allocations := v_allocations || jsonb_build_object(
                'rule_id',          v_rule.id,
                'rule_name',        v_rule.name,
                'category_id',      v_rule.category_id,
                'category_name',    v_rule.name,
                'allocation_type',  v_rule.allocation_type,
                'allocated_amount', v_allocation_amount
            );
        END IF;
    END LOOP;

    -- Process proportional rules
    IF jsonb_array_length(v_prop_rules) > 0 AND v_remaining > 0 THEN
        SELECT COALESCE(SUM((elem->>'percentage')::NUMERIC), 0)
        INTO v_prop_total_pct
        FROM jsonb_array_elements(v_prop_rules) AS elem;

        IF v_prop_total_pct > 0 THEN
            FOR v_prop_rule IN SELECT * FROM jsonb_array_elements(v_prop_rules)
            LOOP
                v_allocation_amount := FLOOR(
                    (v_remaining * (v_prop_rule->>'percentage')::NUMERIC) / v_prop_total_pct
                );

                IF (v_prop_rule->>'min_amount') IS NOT NULL AND
                   v_allocation_amount < (v_prop_rule->>'min_amount')::BIGINT THEN
                    v_allocation_amount := (v_prop_rule->>'min_amount')::BIGINT;
                END IF;
                IF (v_prop_rule->>'max_amount') IS NOT NULL AND
                   v_allocation_amount > (v_prop_rule->>'max_amount')::BIGINT THEN
                    v_allocation_amount := (v_prop_rule->>'max_amount')::BIGINT;
                END IF;

                v_allocation_amount := LEAST(v_allocation_amount, v_remaining);

                IF v_allocation_amount > 0 THEN
                    INSERT INTO public.pf_monthly_budgets (
                        user_id,
                        category_id,
                        salary_entry_id,
                        allocation_rule_id,
                        period_month,
                        period_year,
                        allocated_amount,
                        spent_amount
                    )
                    VALUES (
                        v_user_id,
                        (v_prop_rule->>'category_id')::UUID,
                        v_salary_entry_id,
                        (v_prop_rule->>'rule_id')::UUID,
                        p_period_month,
                        p_period_year,
                        v_allocation_amount,
                        0
                    );

                    v_total_allocated := v_total_allocated + v_allocation_amount;

                    v_allocations := v_allocations || jsonb_build_object(
                        'rule_id',          v_prop_rule->>'rule_id',
                        'rule_name',        v_prop_rule->>'name',
                        'category_id',      v_prop_rule->>'category_id',
                        'category_name',    v_prop_rule->>'name',
                        'allocation_type',  'proportional',
                        'allocated_amount', v_allocation_amount
                    );
                END IF;
            END LOOP;

            v_remaining := GREATEST(p_salary_amount - v_total_allocated, 0);
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success',           TRUE,
        'salary_entry_id',   v_salary_entry_id,
        'salary_amount',     p_salary_amount,
        'period_month',      p_period_month,
        'period_year',       p_period_year,
        'total_allocated',   v_total_allocated,
        'remaining',         v_remaining,
        'remaining_income',  v_remaining,
        'extra_income',      v_extra_income,
        'allocations',       v_allocations,
        'warnings',          v_warnings
    );
END;
$$;
