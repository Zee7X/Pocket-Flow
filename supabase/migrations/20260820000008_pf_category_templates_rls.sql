-- =============================================================================
-- PocketFlow Migration 008: Enable RLS on pf_category_templates (read-only)
-- =============================================================================
-- pf_category_templates contains system onboarding data.
-- Everyone (anon + authenticated) can READ, but NOBODY can write via client.
-- Writes only allowed via service_role (migrations/admin).
-- =============================================================================

ALTER TABLE public.pf_category_templates ENABLE ROW LEVEL SECURITY;

-- Allow anyone (anon + authenticated) to read templates
CREATE POLICY "pf_category_templates_select_public"
    ON public.pf_category_templates FOR SELECT
    USING (TRUE);

-- No INSERT / UPDATE / DELETE policies = blocked for all client roles
