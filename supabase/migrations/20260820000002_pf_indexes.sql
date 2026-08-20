-- =============================================================================
-- PocketFlow Migration 002: Indexes
-- =============================================================================
-- Performance indexes for common query patterns.
-- All FKs already have implicit indexes via PRIMARY KEY, but user_id lookups
-- on all user-owned tables are the most critical.
-- =============================================================================

-- pf_user_finance_settings
CREATE INDEX IF NOT EXISTS idx_pf_user_finance_settings_user_id
    ON public.pf_user_finance_settings (user_id);

-- pf_categories
CREATE INDEX IF NOT EXISTS idx_pf_categories_user_id
    ON public.pf_categories (user_id);
CREATE INDEX IF NOT EXISTS idx_pf_categories_user_type
    ON public.pf_categories (user_id, type);
CREATE INDEX IF NOT EXISTS idx_pf_categories_user_active
    ON public.pf_categories (user_id, is_active);

-- pf_allocation_rules
CREATE INDEX IF NOT EXISTS idx_pf_allocation_rules_user_id
    ON public.pf_allocation_rules (user_id);
CREATE INDEX IF NOT EXISTS idx_pf_allocation_rules_user_active_priority
    ON public.pf_allocation_rules (user_id, is_active, priority ASC);
CREATE INDEX IF NOT EXISTS idx_pf_allocation_rules_category_id
    ON public.pf_allocation_rules (category_id);

-- pf_salary_entries
CREATE INDEX IF NOT EXISTS idx_pf_salary_entries_user_id
    ON public.pf_salary_entries (user_id);
CREATE INDEX IF NOT EXISTS idx_pf_salary_entries_user_period
    ON public.pf_salary_entries (user_id, period_year DESC, period_month DESC);

-- pf_monthly_budgets
CREATE INDEX IF NOT EXISTS idx_pf_monthly_budgets_user_id
    ON public.pf_monthly_budgets (user_id);
CREATE INDEX IF NOT EXISTS idx_pf_monthly_budgets_user_period
    ON public.pf_monthly_budgets (user_id, period_year DESC, period_month DESC);
CREATE INDEX IF NOT EXISTS idx_pf_monthly_budgets_category_id
    ON public.pf_monthly_budgets (category_id);
CREATE INDEX IF NOT EXISTS idx_pf_monthly_budgets_salary_entry_id
    ON public.pf_monthly_budgets (salary_entry_id);

-- pf_transactions
CREATE INDEX IF NOT EXISTS idx_pf_transactions_user_id
    ON public.pf_transactions (user_id);
CREATE INDEX IF NOT EXISTS idx_pf_transactions_user_date
    ON public.pf_transactions (user_id, transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_pf_transactions_category_id
    ON public.pf_transactions (category_id);
CREATE INDEX IF NOT EXISTS idx_pf_transactions_monthly_budget_id
    ON public.pf_transactions (monthly_budget_id);
CREATE INDEX IF NOT EXISTS idx_pf_transactions_user_type
    ON public.pf_transactions (user_id, type);

-- pf_debts
CREATE INDEX IF NOT EXISTS idx_pf_debts_user_id
    ON public.pf_debts (user_id);
CREATE INDEX IF NOT EXISTS idx_pf_debts_user_status
    ON public.pf_debts (user_id, status);

-- pf_debt_payments
CREATE INDEX IF NOT EXISTS idx_pf_debt_payments_user_id
    ON public.pf_debt_payments (user_id);
CREATE INDEX IF NOT EXISTS idx_pf_debt_payments_debt_id
    ON public.pf_debt_payments (debt_id);
CREATE INDEX IF NOT EXISTS idx_pf_debt_payments_debt_date
    ON public.pf_debt_payments (debt_id, payment_date DESC);

-- pf_savings_goals
CREATE INDEX IF NOT EXISTS idx_pf_savings_goals_user_id
    ON public.pf_savings_goals (user_id);
CREATE INDEX IF NOT EXISTS idx_pf_savings_goals_user_type
    ON public.pf_savings_goals (user_id, goal_type);

-- pf_savings_transactions
CREATE INDEX IF NOT EXISTS idx_pf_savings_transactions_user_id
    ON public.pf_savings_transactions (user_id);
CREATE INDEX IF NOT EXISTS idx_pf_savings_transactions_goal_id
    ON public.pf_savings_transactions (goal_id);

-- pf_category_templates
CREATE INDEX IF NOT EXISTS idx_pf_category_templates_key
    ON public.pf_category_templates (template_key);
