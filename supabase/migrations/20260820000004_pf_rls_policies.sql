-- =============================================================================
-- PocketFlow Migration 004: RLS Policies
-- =============================================================================
-- Users can only access their own data.
-- Pattern: user_id = auth.uid()
-- Each table gets SELECT, INSERT, UPDATE, DELETE policies.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- pf_profiles
-- id = auth.uid() (profiles.id IS the auth user id)
-- -----------------------------------------------------------------------------
CREATE POLICY "pf_profiles_select_own"
    ON public.pf_profiles FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "pf_profiles_insert_own"
    ON public.pf_profiles FOR INSERT
    WITH CHECK (id = auth.uid());

CREATE POLICY "pf_profiles_update_own"
    ON public.pf_profiles FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

CREATE POLICY "pf_profiles_delete_own"
    ON public.pf_profiles FOR DELETE
    USING (id = auth.uid());

-- -----------------------------------------------------------------------------
-- pf_user_finance_settings
-- -----------------------------------------------------------------------------
CREATE POLICY "pf_user_finance_settings_select_own"
    ON public.pf_user_finance_settings FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "pf_user_finance_settings_insert_own"
    ON public.pf_user_finance_settings FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_user_finance_settings_update_own"
    ON public.pf_user_finance_settings FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_user_finance_settings_delete_own"
    ON public.pf_user_finance_settings FOR DELETE
    USING (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- pf_categories
-- -----------------------------------------------------------------------------
CREATE POLICY "pf_categories_select_own"
    ON public.pf_categories FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "pf_categories_insert_own"
    ON public.pf_categories FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_categories_update_own"
    ON public.pf_categories FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_categories_delete_own"
    ON public.pf_categories FOR DELETE
    USING (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- pf_allocation_rules
-- -----------------------------------------------------------------------------
CREATE POLICY "pf_allocation_rules_select_own"
    ON public.pf_allocation_rules FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "pf_allocation_rules_insert_own"
    ON public.pf_allocation_rules FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_allocation_rules_update_own"
    ON public.pf_allocation_rules FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_allocation_rules_delete_own"
    ON public.pf_allocation_rules FOR DELETE
    USING (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- pf_salary_entries
-- -----------------------------------------------------------------------------
CREATE POLICY "pf_salary_entries_select_own"
    ON public.pf_salary_entries FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "pf_salary_entries_insert_own"
    ON public.pf_salary_entries FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_salary_entries_update_own"
    ON public.pf_salary_entries FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_salary_entries_delete_own"
    ON public.pf_salary_entries FOR DELETE
    USING (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- pf_monthly_budgets
-- -----------------------------------------------------------------------------
CREATE POLICY "pf_monthly_budgets_select_own"
    ON public.pf_monthly_budgets FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "pf_monthly_budgets_insert_own"
    ON public.pf_monthly_budgets FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_monthly_budgets_update_own"
    ON public.pf_monthly_budgets FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_monthly_budgets_delete_own"
    ON public.pf_monthly_budgets FOR DELETE
    USING (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- pf_transactions
-- -----------------------------------------------------------------------------
CREATE POLICY "pf_transactions_select_own"
    ON public.pf_transactions FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "pf_transactions_insert_own"
    ON public.pf_transactions FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_transactions_update_own"
    ON public.pf_transactions FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_transactions_delete_own"
    ON public.pf_transactions FOR DELETE
    USING (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- pf_debts
-- -----------------------------------------------------------------------------
CREATE POLICY "pf_debts_select_own"
    ON public.pf_debts FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "pf_debts_insert_own"
    ON public.pf_debts FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_debts_update_own"
    ON public.pf_debts FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_debts_delete_own"
    ON public.pf_debts FOR DELETE
    USING (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- pf_debt_payments
-- -----------------------------------------------------------------------------
CREATE POLICY "pf_debt_payments_select_own"
    ON public.pf_debt_payments FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "pf_debt_payments_insert_own"
    ON public.pf_debt_payments FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- Debt payments are immutable (no UPDATE). Delete allowed.
CREATE POLICY "pf_debt_payments_delete_own"
    ON public.pf_debt_payments FOR DELETE
    USING (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- pf_savings_goals
-- -----------------------------------------------------------------------------
CREATE POLICY "pf_savings_goals_select_own"
    ON public.pf_savings_goals FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "pf_savings_goals_insert_own"
    ON public.pf_savings_goals FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_savings_goals_update_own"
    ON public.pf_savings_goals FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "pf_savings_goals_delete_own"
    ON public.pf_savings_goals FOR DELETE
    USING (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- pf_savings_transactions
-- -----------------------------------------------------------------------------
CREATE POLICY "pf_savings_transactions_select_own"
    ON public.pf_savings_transactions FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "pf_savings_transactions_insert_own"
    ON public.pf_savings_transactions FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- Savings transactions are immutable (no UPDATE). Delete allowed.
CREATE POLICY "pf_savings_transactions_delete_own"
    ON public.pf_savings_transactions FOR DELETE
    USING (user_id = auth.uid());
