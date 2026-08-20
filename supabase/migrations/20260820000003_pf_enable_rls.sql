-- =============================================================================
-- PocketFlow Migration 003: Enable Row Level Security
-- =============================================================================
-- Enables RLS on every user-owned table.
-- pf_category_templates is system data (read-only, no RLS needed).
-- =============================================================================

ALTER TABLE public.pf_profiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pf_user_finance_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pf_categories            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pf_allocation_rules      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pf_salary_entries        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pf_monthly_budgets       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pf_transactions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pf_debts                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pf_debt_payments         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pf_savings_goals         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pf_savings_transactions  ENABLE ROW LEVEL SECURITY;

-- pf_category_templates: public read (no RLS), only service role can write.
-- No RLS needed since it has no user_id and contains only system template data.
