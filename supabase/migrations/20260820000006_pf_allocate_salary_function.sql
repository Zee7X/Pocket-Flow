-- =============================================================================
-- PocketFlow Migration 006: pf_allocate_salary() core RPC + pf_preview_allocation()
-- =============================================================================
-- pf_allocate_salary: Atomically creates salary entry + monthly budgets.
-- pf_preview_allocation: Read-only version — same logic, never writes to DB.
-- =============================================================================

-- =============================================================================
-- pf_allocate_salary
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

    SELECT id INTO v_existing_entry_id
    FROM public.pf_salary_entries
    WHERE user_id = v_user_id
      AND period_month = p_period_month
      AND period_year  = p_period_year;

    IF FOUND THEN
        RAISE EXCEPTION 'Salary entry already exists for period %/%', p_period_month, p_period_year;
    END IF;

    INSERT INTO public.pf_salary_entries (user_id, amount, salary_date, period_month, period_year)
    VALUES (v_user_id, p_salary_amount, p_salary_date, p_period_month, p_period_year)
    RETURNING id INTO v_salary_entry_id;

    v_total_income := p_salary_amount;
    v_remaining    := p_salary_amount;

    IF v_baseline_income > 0 AND p_salary_amount > v_baseline_income THEN
        v_extra_income := p_salary_amount - v_baseline_income;
    ELSE
        v_extra_income := 0;
    END IF;

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
                IF v_rule.percentage IS NULL OR v_rule.percentage <= 0 THEN
                    CONTINUE;
                END IF;
                CASE v_rule.percentage_base
                    WHEN 'total_income' THEN v_pct_base := v_total_income;
                    WHEN 'extra_income' THEN v_pct_base := v_extra_income;
                    ELSE                     v_pct_base := v_remaining;
                END CASE;
                v_allocation_amount := FLOOR(v_pct_base * v_rule.percentage / 100.0)::BIGINT;
                v_allocation_amount := LEAST(v_allocation_amount, v_remaining);

            ELSIF v_rule.allocation_type = 'remaining' THEN
                v_allocation_amount := v_remaining;

            ELSIF v_rule.allocation_type = 'proportional' THEN
                v_prop_rules := v_prop_rules || jsonb_build_object(
                    'id',          v_rule.id,
                    'name',        v_rule.name,
                    'category_id', v_rule.category_id,
                    'percentage',  v_rule.percentage,
                    'min_amount',  v_rule.min_amount,
                    'max_amount',  v_rule.max_amount
                );
                CONTINUE;
            END IF;

            IF v_rule.min_amount IS NOT NULL AND v_rule.min_amount > 0 THEN
                v_allocation_amount := GREATEST(v_allocation_amount, v_rule.min_amount);
                IF v_allocation_amount > v_remaining THEN
                    v_allocation_amount := v_remaining;
                END IF;
            END IF;

            IF v_rule.max_amount IS NOT NULL THEN
                v_allocation_amount := LEAST(v_allocation_amount, v_rule.max_amount);
            END IF;

            v_remaining := v_remaining - v_allocation_amount;
        END IF;

        INSERT INTO public.pf_monthly_budgets (
            user_id, category_id, salary_entry_id, allocation_rule_id,
            period_month, period_year, allocated_amount, spent_amount
        )
        VALUES (
            v_user_id, v_rule.category_id, v_salary_entry_id, v_rule.id,
            p_period_month, p_period_year, v_allocation_amount, 0
        )
        ON CONFLICT (user_id, category_id, period_month, period_year)
        DO UPDATE SET
            allocated_amount   = EXCLUDED.allocated_amount,
            salary_entry_id    = EXCLUDED.salary_entry_id,
            allocation_rule_id = EXCLUDED.allocation_rule_id,
            updated_at         = NOW();

        v_allocations := v_allocations || jsonb_build_object(
            'rule_id',          v_rule.id,
            'rule_name',        v_rule.name,
            'category_id',      v_rule.category_id,
            'allocation_type',  v_rule.allocation_type,
            'allocated_amount', v_allocation_amount
        );
        v_total_allocated := v_total_allocated + v_allocation_amount;
    END LOOP;

    -- Proportional rules (deferred, share remaining pool proportionally)
    IF jsonb_array_length(v_prop_rules) > 0 AND v_remaining > 0 THEN
        SELECT COALESCE(SUM((r->>'percentage')::NUMERIC), 0)
        INTO v_prop_total_pct
        FROM jsonb_array_elements(v_prop_rules) r;

        FOR v_prop_rule IN SELECT r FROM jsonb_array_elements(v_prop_rules) r LOOP
            DECLARE
                v_prop_pct     NUMERIC;
                v_prop_amount  BIGINT;
                v_prop_max     BIGINT;
                v_prop_min     BIGINT;
                v_prop_cat_id  UUID;
                v_prop_rule_id UUID;
                v_prop_name    TEXT;
            BEGIN
                v_prop_pct     := (v_prop_rule->>'percentage')::NUMERIC;
                v_prop_cat_id  := (v_prop_rule->>'category_id')::UUID;
                v_prop_rule_id := (v_prop_rule->>'id')::UUID;
                v_prop_name    := v_prop_rule->>'name';
                v_prop_min     := COALESCE((v_prop_rule->>'min_amount')::BIGINT, 0);
                v_prop_max     := (v_prop_rule->>'max_amount')::BIGINT;

                IF v_prop_total_pct > 0 THEN
                    v_prop_amount := FLOOR(v_remaining * (v_prop_pct / v_prop_total_pct))::BIGINT;
                ELSE
                    v_prop_amount := 0;
                END IF;
                IF v_prop_min > 0 THEN
                    v_prop_amount := GREATEST(v_prop_amount, v_prop_min);
                END IF;
                IF v_prop_max IS NOT NULL THEN
                    v_prop_amount := LEAST(v_prop_amount, v_prop_max);
                END IF;

                INSERT INTO public.pf_monthly_budgets (
                    user_id, category_id, salary_entry_id, allocation_rule_id,
                    period_month, period_year, allocated_amount, spent_amount
                )
                VALUES (
                    v_user_id, v_prop_cat_id, v_salary_entry_id, v_prop_rule_id,
                    p_period_month, p_period_year, v_prop_amount, 0
                )
                ON CONFLICT (user_id, category_id, period_month, period_year)
                DO UPDATE SET
                    allocated_amount   = EXCLUDED.allocated_amount,
                    salary_entry_id    = EXCLUDED.salary_entry_id,
                    allocation_rule_id = EXCLUDED.allocation_rule_id,
                    updated_at         = NOW();

                v_allocations := v_allocations || jsonb_build_object(
                    'rule_id',          v_prop_rule_id,
                    'rule_name',        v_prop_name,
                    'category_id',      v_prop_cat_id,
                    'allocation_type',  'proportional',
                    'allocated_amount', v_prop_amount
                );
                v_total_allocated := v_total_allocated + v_prop_amount;
            END;
        END LOOP;
    END IF;

    IF v_total_allocated > p_salary_amount AND NOT v_allow_overalloc THEN
        v_warnings := v_warnings || jsonb_build_object(
            'code',            'OVERALLOCATION',
            'total_allocated', v_total_allocated,
            'salary_amount',   p_salary_amount,
            'message',         'Total allocated exceeds salary amount'
        );
    END IF;

    RETURN jsonb_build_object(
        'success',          TRUE,
        'salary_entry_id',  v_salary_entry_id,
        'salary_amount',    p_salary_amount,
        'total_allocated',  v_total_allocated,
        'remaining',        v_remaining,
        'extra_income',     v_extra_income,
        'period_month',     p_period_month,
        'period_year',      p_period_year,
        'allocations',      v_allocations,
        'warnings',         v_warnings
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

COMMENT ON FUNCTION public.pf_allocate_salary IS
'PocketFlow: Atomically creates a salary entry and allocates it across all active allocation rules. Returns JSON with allocations and warnings. Call via Supabase RPC.';

REVOKE ALL ON FUNCTION public.pf_allocate_salary FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pf_allocate_salary TO authenticated;

-- =============================================================================
-- pf_preview_allocation (read-only, never writes to DB)
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
                IF v_rule.percentage IS NULL OR v_rule.percentage <= 0 THEN
                    CONTINUE;
                END IF;
                CASE v_rule.percentage_base
                    WHEN 'total_income' THEN v_pct_base := v_total_income;
                    WHEN 'extra_income' THEN v_pct_base := v_extra_income;
                    ELSE                     v_pct_base := v_remaining;
                END CASE;
                v_allocation_amount := FLOOR(v_pct_base * v_rule.percentage / 100.0)::BIGINT;
                v_allocation_amount := LEAST(v_allocation_amount, v_remaining);

            ELSIF v_rule.allocation_type = 'remaining' THEN
                v_allocation_amount := v_remaining;

            ELSIF v_rule.allocation_type = 'proportional' THEN
                v_prop_rules := v_prop_rules || jsonb_build_object(
                    'id',          v_rule.id,
                    'name',        v_rule.name,
                    'category_id', v_rule.category_id,
                    'percentage',  v_rule.percentage,
                    'min_amount',  v_rule.min_amount,
                    'max_amount',  v_rule.max_amount
                );
                CONTINUE;
            END IF;

            IF v_rule.min_amount IS NOT NULL AND v_rule.min_amount > 0 THEN
                v_allocation_amount := GREATEST(v_allocation_amount, v_rule.min_amount);
                IF v_allocation_amount > v_remaining THEN
                    v_allocation_amount := v_remaining;
                END IF;
            END IF;

            IF v_rule.max_amount IS NOT NULL THEN
                v_allocation_amount := LEAST(v_allocation_amount, v_rule.max_amount);
            END IF;

            v_remaining := v_remaining - v_allocation_amount;
        END IF;

        v_allocations := v_allocations || jsonb_build_object(
            'rule_id',          v_rule.id,
            'rule_name',        v_rule.name,
            'category_id',      v_rule.category_id,
            'allocation_type',  v_rule.allocation_type,
            'allocated_amount', v_allocation_amount
        );
        v_total_allocated := v_total_allocated + v_allocation_amount;
    END LOOP;

    IF jsonb_array_length(v_prop_rules) > 0 AND v_remaining > 0 THEN
        SELECT COALESCE(SUM((r->>'percentage')::NUMERIC), 0)
        INTO v_prop_total_pct
        FROM jsonb_array_elements(v_prop_rules) r;

        FOR v_prop_rule IN SELECT r FROM jsonb_array_elements(v_prop_rules) r LOOP
            DECLARE
                v_prop_pct     NUMERIC;
                v_prop_amount  BIGINT;
                v_prop_max     BIGINT;
                v_prop_min     BIGINT;
                v_prop_cat_id  UUID;
                v_prop_rule_id UUID;
                v_prop_name    TEXT;
            BEGIN
                v_prop_pct     := (v_prop_rule->>'percentage')::NUMERIC;
                v_prop_cat_id  := (v_prop_rule->>'category_id')::UUID;
                v_prop_rule_id := (v_prop_rule->>'id')::UUID;
                v_prop_name    := v_prop_rule->>'name';
                v_prop_min     := COALESCE((v_prop_rule->>'min_amount')::BIGINT, 0);
                v_prop_max     := (v_prop_rule->>'max_amount')::BIGINT;

                IF v_prop_total_pct > 0 THEN
                    v_prop_amount := FLOOR(v_remaining * (v_prop_pct / v_prop_total_pct))::BIGINT;
                ELSE
                    v_prop_amount := 0;
                END IF;
                IF v_prop_min > 0 THEN
                    v_prop_amount := GREATEST(v_prop_amount, v_prop_min);
                END IF;
                IF v_prop_max IS NOT NULL THEN
                    v_prop_amount := LEAST(v_prop_amount, v_prop_max);
                END IF;

                v_allocations := v_allocations || jsonb_build_object(
                    'rule_id',          v_prop_rule_id,
                    'rule_name',        v_prop_name,
                    'category_id',      v_prop_cat_id,
                    'allocation_type',  'proportional',
                    'allocated_amount', v_prop_amount
                );
                v_total_allocated := v_total_allocated + v_prop_amount;
            END;
        END LOOP;
    END IF;

    IF v_total_allocated > p_salary_amount AND NOT v_allow_overalloc THEN
        v_warnings := v_warnings || jsonb_build_object(
            'code',            'OVERALLOCATION',
            'total_allocated', v_total_allocated,
            'salary_amount',   p_salary_amount,
            'message',         'Total allocated exceeds salary amount'
        );
    END IF;

    RETURN jsonb_build_object(
        'success',         TRUE,
        'is_preview',      TRUE,
        'salary_amount',   p_salary_amount,
        'total_allocated', v_total_allocated,
        'remaining',       v_remaining,
        'extra_income',    v_extra_income,
        'period_month',    p_period_month,
        'period_year',     p_period_year,
        'allocations',     v_allocations,
        'warnings',        v_warnings
    );
END;
$$;

COMMENT ON FUNCTION public.pf_preview_allocation IS
'PocketFlow: Read-only preview of allocation. Same logic as pf_allocate_salary but never writes to DB. Safe to call any number of times.';

REVOKE ALL ON FUNCTION public.pf_preview_allocation FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pf_preview_allocation TO authenticated;
