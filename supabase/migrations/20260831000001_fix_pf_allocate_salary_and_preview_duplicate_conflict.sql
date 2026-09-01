-- =============================================================================
-- Migration: Fix pf_allocate_salary & pf_preview_allocation duplicate category conflict and formula logic
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pf_preview_allocation(
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
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Pengguna tidak terautentikasi (Not authenticated)';
    END IF;

    IF p_salary_amount <= 0 THEN
        RAISE EXCEPTION 'Nominal gaji harus lebih besar dari 0';
    END IF;
    IF p_period_month < 1 OR p_period_month > 12 THEN
        RAISE EXCEPTION 'Bulan periode harus antara 1 sampai 12';
    END IF;
    IF p_period_year < 2000 THEN
        RAISE EXCEPTION 'Tahun periode harus >= 2000';
    END IF;

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

    v_total_income := p_salary_amount;
    v_remaining    := p_salary_amount;

    IF v_baseline_income > 0 AND p_salary_amount > v_baseline_income THEN
        v_extra_income := p_salary_amount - v_baseline_income;
    ELSE
        v_extra_income := 0;
    END IF;

    FOR v_rule IN
        SELECT
            r.id,
            r.category_id,
            r.name,
            r.allocation_type,
            r.fixed_amount,
            r.percentage,
            r.percentage_base,
            r.min_amount,
            r.max_amount,
            r.priority,
            r.is_required,
            c.is_fixed,
            c.type AS cat_type
        FROM public.pf_allocation_rules r
        JOIN public.pf_categories c ON c.id = r.category_id
        WHERE r.user_id = v_user_id
          AND r.is_active = TRUE
        ORDER BY r.priority ASC, r.created_at ASC
    LOOP
        v_allocation_amount := 0;

        IF v_rule.allocation_type = 'fixed' THEN
            v_allocation_amount := COALESCE(v_rule.fixed_amount, 0);
            IF NOT v_allow_overalloc THEN
                v_allocation_amount := LEAST(v_allocation_amount, v_remaining);
            END IF;

        ELSIF v_rule.allocation_type = 'capped' THEN
            v_allocation_amount := COALESCE(v_rule.fixed_amount, v_rule.max_amount, 0);
            IF NOT v_allow_overalloc THEN
                v_allocation_amount := LEAST(v_allocation_amount, v_remaining);
            END IF;

        ELSIF v_rule.allocation_type = 'percentage' THEN
            IF v_rule.percentage IS NOT NULL AND v_rule.percentage > 0 THEN
                IF v_rule.percentage_base IN ('baseline') AND v_baseline_income > 0 THEN
                    v_pct_base := v_baseline_income;
                ELSIF v_rule.percentage_base IN ('extra', 'extra_income') THEN
                    v_pct_base := v_extra_income;
                ELSIF v_rule.percentage_base IN ('remaining', 'remaining_income') THEN
                    v_pct_base := v_remaining;
                ELSE
                    v_pct_base := v_total_income;
                END IF;

                v_allocation_amount := FLOOR((v_pct_base * v_rule.percentage) / 100.0);

                IF v_rule.min_amount IS NOT NULL AND v_rule.min_amount > 0 AND v_allocation_amount < v_rule.min_amount THEN
                    v_allocation_amount := v_rule.min_amount;
                END IF;
                IF v_rule.max_amount IS NOT NULL AND v_allocation_amount > v_rule.max_amount THEN
                    v_allocation_amount := v_rule.max_amount;
                END IF;

                IF NOT v_allow_overalloc THEN
                    v_allocation_amount := LEAST(v_allocation_amount, v_remaining);
                END IF;
            END IF;

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
            v_allocation_amount := GREATEST(v_remaining, 0);
        END IF;

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
                    v_total_allocated := v_total_allocated + v_allocation_amount;
                    v_remaining       := v_remaining - v_allocation_amount;

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
        END IF;
    END IF;

    IF v_remaining > 0 THEN
        v_warnings := v_warnings || jsonb_build_object(
            'code',    'UNALLOCATED_REMAINDER',
            'message', 'Terdapat sisa gaji sebesar ' || v_remaining || ' yang belum teralokasi ke aturan manapun.',
            'amount',  v_remaining
        );
    END IF;

    RETURN jsonb_build_object(
        'success',         TRUE,
        'is_preview',      TRUE,
        'salary_amount',   p_salary_amount,
        'salary_date',     p_salary_date,
        'period_month',    p_period_month,
        'period_year',     p_period_year,
        'allocations',     v_allocations,
        'total_allocated', v_total_allocated,
        'unallocated',     v_remaining,
        'remaining',       v_remaining,
        'extra_income',    v_extra_income,
        'warnings',        v_warnings
    );
END;
$$;

COMMENT ON FUNCTION public.pf_preview_allocation IS
'PocketFlow: Read-only preview of allocation. Same logic as pf_allocate_salary but never writes to DB. Safe to call any number of times.';

REVOKE ALL ON FUNCTION public.pf_preview_allocation FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pf_preview_allocation TO authenticated;


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
    v_spent_amount       BIGINT;
    v_pct_base           BIGINT;

    v_prop_total_pct     NUMERIC;
    v_prop_rules         JSONB := '[]'::JSONB;
    v_prop_rule          JSONB;

    v_allocations        JSONB := '[]'::JSONB;
    v_warnings           JSONB := '[]'::JSONB;
    v_total_allocated    BIGINT := 0;

    v_income_cat_id      UUID;
    v_existing_tx_id     UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Pengguna tidak terautentikasi (Not authenticated)';
    END IF;

    IF p_salary_amount <= 0 THEN
        RAISE EXCEPTION 'Nominal gaji harus lebih besar dari 0';
    END IF;
    IF p_period_month < 1 OR p_period_month > 12 THEN
        RAISE EXCEPTION 'Bulan periode harus antara 1 sampai 12';
    END IF;
    IF p_period_year < 2000 THEN
        RAISE EXCEPTION 'Tahun periode harus >= 2000';
    END IF;

    -- 1. Get default income category for salary
    SELECT id INTO v_income_cat_id
    FROM public.pf_categories
    WHERE user_id = v_user_id
      AND type = 'income'
    ORDER BY (name ILIKE '%gaji%') DESC, sort_order ASC
    LIMIT 1;

    -- 2. Atomic UPSERT for pf_salary_entries
    INSERT INTO public.pf_salary_entries (
        user_id,
        amount,
        salary_date,
        period_month,
        period_year,
        updated_at
    )
    VALUES (
        v_user_id,
        p_salary_amount,
        p_salary_date,
        p_period_month,
        p_period_year,
        NOW()
    )
    ON CONFLICT (user_id, period_month, period_year)
    DO UPDATE SET
        amount = EXCLUDED.amount,
        salary_date = EXCLUDED.salary_date,
        updated_at = NOW()
    RETURNING id INTO v_salary_entry_id;

    -- 3. Sync or Insert Income Transaction
    SELECT id INTO v_existing_tx_id
    FROM public.pf_transactions
    WHERE user_id = v_user_id
      AND type = 'income'
      AND (
          note = 'Gaji Periode ' || p_period_month || '/' || p_period_year
          OR (note ILIKE '%gaji%' AND EXTRACT(MONTH FROM transaction_date) = p_period_month AND EXTRACT(YEAR FROM transaction_date) = p_period_year)
      )
    LIMIT 1;

    IF v_existing_tx_id IS NOT NULL THEN
        UPDATE public.pf_transactions
        SET amount = p_salary_amount,
            note = 'Gaji Periode ' || p_period_month || '/' || p_period_year,
            transaction_date = p_salary_date
        WHERE id = v_existing_tx_id;
    ELSE
        INSERT INTO public.pf_transactions (
            user_id,
            category_id,
            type,
            amount,
            transaction_date,
            note
        )
        VALUES (
            v_user_id,
            v_income_cat_id,
            'income',
            p_salary_amount,
            p_salary_date,
            'Gaji Periode ' || p_period_month || '/' || p_period_year
        );
    END IF;

    -- 4. Clean up any existing monthly budgets for this period before regenerating
    DELETE FROM public.pf_monthly_budgets
    WHERE user_id = v_user_id
      AND period_month = p_period_month
      AND period_year  = p_period_year;

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
            r.id,
            r.category_id,
            r.name,
            r.allocation_type,
            r.fixed_amount,
            r.percentage,
            r.percentage_base,
            r.min_amount,
            r.max_amount,
            r.priority,
            c.is_fixed,
            c.type AS cat_type
        FROM public.pf_allocation_rules r
        JOIN public.pf_categories c ON c.id = r.category_id
        WHERE r.user_id = v_user_id
          AND r.is_active = TRUE
        ORDER BY r.priority ASC, r.created_at ASC
    LOOP
        v_allocation_amount := 0;

        IF v_rule.allocation_type = 'fixed' THEN
            v_allocation_amount := COALESCE(v_rule.fixed_amount, 0);
            IF NOT v_allow_overalloc THEN
                v_allocation_amount := LEAST(v_allocation_amount, v_remaining);
            END IF;

        ELSIF v_rule.allocation_type = 'capped' THEN
            v_allocation_amount := COALESCE(v_rule.fixed_amount, v_rule.max_amount, 0);
            IF NOT v_allow_overalloc THEN
                v_allocation_amount := LEAST(v_allocation_amount, v_remaining);
            END IF;

        ELSIF v_rule.allocation_type = 'percentage' THEN
            IF v_rule.percentage IS NOT NULL AND v_rule.percentage > 0 THEN
                IF v_rule.percentage_base IN ('baseline') AND v_baseline_income > 0 THEN
                    v_pct_base := v_baseline_income;
                ELSIF v_rule.percentage_base IN ('extra', 'extra_income') THEN
                    v_pct_base := v_extra_income;
                ELSIF v_rule.percentage_base IN ('remaining', 'remaining_income') THEN
                    v_pct_base := v_remaining;
                ELSE
                    v_pct_base := v_total_income;
                END IF;

                v_allocation_amount := FLOOR((v_pct_base * v_rule.percentage) / 100.0);

                IF v_rule.min_amount IS NOT NULL AND v_rule.min_amount > 0 AND v_allocation_amount < v_rule.min_amount THEN
                    v_allocation_amount := v_rule.min_amount;
                END IF;
                IF v_rule.max_amount IS NOT NULL AND v_allocation_amount > v_rule.max_amount THEN
                    v_allocation_amount := v_rule.max_amount;
                END IF;

                IF NOT v_allow_overalloc THEN
                    v_allocation_amount := LEAST(v_allocation_amount, v_remaining);
                END IF;
            END IF;

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
            v_allocation_amount := GREATEST(v_remaining, 0);
        END IF;

        IF v_allocation_amount > 0 THEN
            -- Calculate spent_amount from any pre-existing transactions in this month & category
            SELECT COALESCE(SUM(amount), 0)
            INTO v_spent_amount
            FROM public.pf_transactions
            WHERE user_id = v_user_id
              AND category_id = v_rule.category_id
              AND type = 'expense'
              AND EXTRACT(MONTH FROM transaction_date) = p_period_month
              AND EXTRACT(YEAR FROM transaction_date) = p_period_year;

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
                COALESCE(v_spent_amount, 0)
            )
            ON CONFLICT (user_id, category_id, period_month, period_year)
            DO UPDATE SET
                allocated_amount = pf_monthly_budgets.allocated_amount + EXCLUDED.allocated_amount,
                salary_entry_id = EXCLUDED.salary_entry_id,
                allocation_rule_id = EXCLUDED.allocation_rule_id;

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
                    -- Calculate spent_amount from any pre-existing transactions in this month & category
                    SELECT COALESCE(SUM(amount), 0)
                    INTO v_spent_amount
                    FROM public.pf_transactions
                    WHERE user_id = v_user_id
                      AND category_id = (v_prop_rule->>'category_id')::UUID
                      AND type = 'expense'
                      AND EXTRACT(MONTH FROM transaction_date) = p_period_month
                      AND EXTRACT(YEAR FROM transaction_date) = p_period_year;

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
                        COALESCE(v_spent_amount, 0)
                    )
                    ON CONFLICT (user_id, category_id, period_month, period_year)
                    DO UPDATE SET
                        allocated_amount = pf_monthly_budgets.allocated_amount + EXCLUDED.allocated_amount,
                        salary_entry_id = EXCLUDED.salary_entry_id,
                        allocation_rule_id = EXCLUDED.allocation_rule_id;

                    v_total_allocated := v_total_allocated + v_allocation_amount;
                    v_remaining       := v_remaining - v_allocation_amount;

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
        END IF;
    END IF;

    IF v_remaining > 0 THEN
        v_warnings := v_warnings || jsonb_build_object(
            'code',    'UNALLOCATED_REMAINDER',
            'message', 'Terdapat sisa gaji sebesar ' || v_remaining || ' yang belum teralokasi ke aturan manapun.',
            'amount',  v_remaining
        );
    END IF;

    RETURN jsonb_build_object(
        'success',         TRUE,
        'is_preview',      FALSE,
        'salary_entry_id', v_salary_entry_id,
        'salary_amount',   p_salary_amount,
        'salary_date',     p_salary_date,
        'period_month',    p_period_month,
        'period_year',     p_period_year,
        'allocations',     v_allocations,
        'total_allocated', v_total_allocated,
        'unallocated',     v_remaining,
        'remaining',       v_remaining,
        'extra_income',    v_extra_income,
        'warnings',        v_warnings
    );
END;
$$;

COMMENT ON FUNCTION public.pf_allocate_salary IS
'PocketFlow: Core allocation engine with ON CONFLICT resolution for pf_monthly_budgets and unified calculation logic.';

REVOKE ALL ON FUNCTION public.pf_allocate_salary FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pf_allocate_salary TO authenticated;
