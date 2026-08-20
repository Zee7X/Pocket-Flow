-- =============================================================================
-- PocketFlow Migration 001: Create Core Tables
-- =============================================================================
-- All tables use pf_ prefix for namespace isolation on shared Supabase instance.
-- All monetary values stored as BIGINT (integer, no floating point).
-- All user-owned tables reference auth.users(id) via user_id.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- pf_profiles
-- One profile per auth user. Created automatically on first login.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_profiles (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name        TEXT,
    avatar_url  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.pf_profiles IS 'PocketFlow: User profile, 1-to-1 with auth.users';

-- -----------------------------------------------------------------------------
-- pf_user_finance_settings
-- All configurable finance parameters per user. Nothing hardcoded.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_user_finance_settings (
    id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    currency                  TEXT NOT NULL DEFAULT 'IDR',
    salary_day                SMALLINT CHECK (salary_day BETWEEN 1 AND 31),
    baseline_income           BIGINT NOT NULL DEFAULT 0,
    default_emergency_target  BIGINT NOT NULL DEFAULT 0,
    extra_income_strategy     JSONB,
    allow_overallocation      BOOLEAN NOT NULL DEFAULT FALSE,
    spendable_category_ids    JSONB,
    created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id)
);

COMMENT ON TABLE public.pf_user_finance_settings IS 'PocketFlow: Per-user configurable finance settings';
COMMENT ON COLUMN public.pf_user_finance_settings.baseline_income IS 'User-defined baseline income for extra income detection. 0 = feature disabled.';
COMMENT ON COLUMN public.pf_user_finance_settings.extra_income_strategy IS 'JSON array defining how extra income is split. E.g. [{"category_id": "uuid", "percentage": 60}]';

-- -----------------------------------------------------------------------------
-- pf_categories
-- User-defined categories. Type drives behavior in allocation engine.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_categories (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name         TEXT NOT NULL,
    icon         TEXT,
    color        TEXT,
    type         TEXT NOT NULL DEFAULT 'expense'
                 CHECK (type IN ('income', 'expense', 'saving', 'debt')),
    is_required  BOOLEAN NOT NULL DEFAULT FALSE,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    is_spendable BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order   INT NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.pf_categories IS 'PocketFlow: User-defined spending/saving/income/debt categories';
COMMENT ON COLUMN public.pf_categories.is_spendable IS 'True = counted in safe spending. False for savings, debts, emergency fund.';

-- -----------------------------------------------------------------------------
-- pf_allocation_rules
-- The core engine data. Each rule tells the engine how to assign salary money.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_allocation_rules (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id     UUID REFERENCES public.pf_categories(id) ON DELETE SET NULL,
    name            TEXT NOT NULL,
    allocation_type TEXT NOT NULL DEFAULT 'fixed'
                    CHECK (allocation_type IN ('fixed', 'capped', 'percentage', 'remaining', 'proportional')),
    fixed_amount    BIGINT NOT NULL DEFAULT 0,
    percentage      NUMERIC(5,2) CHECK (percentage BETWEEN 0 AND 100),
    percentage_base TEXT NOT NULL DEFAULT 'remaining_income'
                    CHECK (percentage_base IN ('total_income', 'remaining_income', 'extra_income', 'custom_base')),
    min_amount      BIGINT NOT NULL DEFAULT 0,
    max_amount      BIGINT,
    priority        INT NOT NULL DEFAULT 10,
    is_required     BOOLEAN NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    metadata        JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pf_allocation_rules_min_max_check
        CHECK (max_amount IS NULL OR min_amount <= max_amount),
    CONSTRAINT pf_allocation_rules_fixed_amount_non_negative
        CHECK (fixed_amount >= 0),
    CONSTRAINT pf_allocation_rules_min_amount_non_negative
        CHECK (min_amount >= 0)
);

COMMENT ON TABLE public.pf_allocation_rules IS 'PocketFlow: User-configured allocation rules for the salary allocation engine';
COMMENT ON COLUMN public.pf_allocation_rules.priority IS 'Lower = higher priority. Processed in ASC order.';
COMMENT ON COLUMN public.pf_allocation_rules.percentage IS 'Stored as 0-100. E.g. 40 means 40%.';

-- -----------------------------------------------------------------------------
-- pf_salary_entries
-- Each time a user receives salary, one record is created.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_salary_entries (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount       BIGINT NOT NULL CHECK (amount > 0),
    salary_date  DATE NOT NULL,
    period_month SMALLINT NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    period_year  SMALLINT NOT NULL CHECK (period_year >= 2000),
    note         TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, period_month, period_year)
);

COMMENT ON TABLE public.pf_salary_entries IS 'PocketFlow: Monthly salary income entries';

-- -----------------------------------------------------------------------------
-- pf_monthly_budgets
-- The output of the allocation engine. One row per category per period.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_monthly_budgets (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id        UUID REFERENCES public.pf_categories(id) ON DELETE SET NULL,
    salary_entry_id    UUID REFERENCES public.pf_salary_entries(id) ON DELETE SET NULL,
    allocation_rule_id UUID REFERENCES public.pf_allocation_rules(id) ON DELETE SET NULL,
    period_month       SMALLINT NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    period_year        SMALLINT NOT NULL CHECK (period_year >= 2000),
    allocated_amount   BIGINT NOT NULL DEFAULT 0 CHECK (allocated_amount >= 0),
    spent_amount       BIGINT NOT NULL DEFAULT 0 CHECK (spent_amount >= 0),
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, category_id, period_month, period_year)
);

COMMENT ON TABLE public.pf_monthly_budgets IS 'PocketFlow: Allocated budget per category per month, output of allocation engine';

-- -----------------------------------------------------------------------------
-- pf_transactions
-- Every financial event (income, expense, transfer).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_transactions (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id       UUID REFERENCES public.pf_categories(id) ON DELETE SET NULL,
    monthly_budget_id UUID REFERENCES public.pf_monthly_budgets(id) ON DELETE SET NULL,
    type              TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
    amount            BIGINT NOT NULL CHECK (amount > 0),
    note              TEXT,
    transaction_date  DATE NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.pf_transactions IS 'PocketFlow: All financial transactions (income, expense, transfer)';

-- -----------------------------------------------------------------------------
-- pf_debts
-- Debt/loan tracking.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_debts (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id      UUID REFERENCES public.pf_categories(id) ON DELETE SET NULL,
    name             TEXT NOT NULL,
    initial_amount   BIGINT NOT NULL CHECK (initial_amount > 0),
    remaining_amount BIGINT NOT NULL CHECK (remaining_amount >= 0),
    minimum_payment  BIGINT NOT NULL DEFAULT 0 CHECK (minimum_payment >= 0),
    start_date       DATE,
    target_date      DATE,
    status           TEXT NOT NULL DEFAULT 'active'
                     CHECK (status IN ('active', 'paid', 'paused')),
    note             TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.pf_debts IS 'PocketFlow: Debt/loan tracking';

-- -----------------------------------------------------------------------------
-- pf_debt_payments
-- History of payments against a debt.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_debt_payments (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    debt_id      UUID NOT NULL REFERENCES public.pf_debts(id) ON DELETE CASCADE,
    amount       BIGINT NOT NULL CHECK (amount > 0),
    payment_date DATE NOT NULL,
    note         TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.pf_debt_payments IS 'PocketFlow: Debt payment history';

-- -----------------------------------------------------------------------------
-- pf_savings_goals
-- Savings and emergency fund tracking.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_savings_goals (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id    UUID REFERENCES public.pf_categories(id) ON DELETE SET NULL,
    name           TEXT NOT NULL,
    target_amount  BIGINT NOT NULL CHECK (target_amount > 0),
    current_amount BIGINT NOT NULL DEFAULT 0 CHECK (current_amount >= 0),
    goal_type      TEXT NOT NULL DEFAULT 'saving'
                   CHECK (goal_type IN ('emergency_fund', 'saving', 'purchase', 'other')),
    target_date    DATE,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    note           TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.pf_savings_goals IS 'PocketFlow: Savings and emergency fund goals';

-- -----------------------------------------------------------------------------
-- pf_savings_transactions
-- Deposits and withdrawals against a savings goal.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_savings_transactions (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    goal_id    UUID NOT NULL REFERENCES public.pf_savings_goals(id) ON DELETE CASCADE,
    type       TEXT NOT NULL CHECK (type IN ('deposit', 'withdrawal')),
    amount     BIGINT NOT NULL CHECK (amount > 0),
    note       TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.pf_savings_transactions IS 'PocketFlow: Savings deposit/withdrawal history';

-- -----------------------------------------------------------------------------
-- pf_category_templates
-- System-level onboarding templates. No user_id. Structure only, zero amounts.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pf_category_templates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_key    TEXT NOT NULL,
    template_name   TEXT NOT NULL,
    item_name       TEXT NOT NULL,
    item_icon       TEXT,
    item_color      TEXT,
    item_type       TEXT NOT NULL DEFAULT 'expense'
                    CHECK (item_type IN ('income', 'expense', 'saving', 'debt')),
    allocation_type TEXT NOT NULL DEFAULT 'fixed'
                    CHECK (allocation_type IN ('fixed', 'capped', 'percentage', 'remaining', 'proportional')),
    percentage_base TEXT NOT NULL DEFAULT 'remaining_income'
                    CHECK (percentage_base IN ('total_income', 'remaining_income', 'extra_income', 'custom_base')),
    priority        INT NOT NULL DEFAULT 10,
    is_required     BOOLEAN NOT NULL DEFAULT FALSE,
    is_spendable    BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order      INT NOT NULL DEFAULT 0,
    description     TEXT
);

COMMENT ON TABLE public.pf_category_templates IS 'PocketFlow: System onboarding templates. Structure only — zero amounts. Users fill actual values.';

-- -----------------------------------------------------------------------------
-- updated_at trigger function
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pf_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER pf_profiles_updated_at
    BEFORE UPDATE ON public.pf_profiles
    FOR EACH ROW EXECUTE FUNCTION public.pf_set_updated_at();

CREATE TRIGGER pf_user_finance_settings_updated_at
    BEFORE UPDATE ON public.pf_user_finance_settings
    FOR EACH ROW EXECUTE FUNCTION public.pf_set_updated_at();

CREATE TRIGGER pf_categories_updated_at
    BEFORE UPDATE ON public.pf_categories
    FOR EACH ROW EXECUTE FUNCTION public.pf_set_updated_at();

CREATE TRIGGER pf_allocation_rules_updated_at
    BEFORE UPDATE ON public.pf_allocation_rules
    FOR EACH ROW EXECUTE FUNCTION public.pf_set_updated_at();

CREATE TRIGGER pf_monthly_budgets_updated_at
    BEFORE UPDATE ON public.pf_monthly_budgets
    FOR EACH ROW EXECUTE FUNCTION public.pf_set_updated_at();

CREATE TRIGGER pf_transactions_updated_at
    BEFORE UPDATE ON public.pf_transactions
    FOR EACH ROW EXECUTE FUNCTION public.pf_set_updated_at();

CREATE TRIGGER pf_debts_updated_at
    BEFORE UPDATE ON public.pf_debts
    FOR EACH ROW EXECUTE FUNCTION public.pf_set_updated_at();

CREATE TRIGGER pf_savings_goals_updated_at
    BEFORE UPDATE ON public.pf_savings_goals
    FOR EACH ROW EXECUTE FUNCTION public.pf_set_updated_at();
