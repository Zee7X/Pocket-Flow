-- =============================================================================
-- PocketFlow Migration 007: Auto-create profile on user signup
-- =============================================================================
-- Trigger on auth.users INSERT to automatically create pf_profiles row.
-- This ensures a profile always exists for every authenticated user.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pf_handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Create profile
    INSERT INTO public.pf_profiles (id, name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'full_name', NULL)
    )
    ON CONFLICT (id) DO NOTHING;

    -- Create default finance settings
    INSERT INTO public.pf_user_finance_settings (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$;

-- Drop if exists to allow re-running idempotently
DROP TRIGGER IF EXISTS pf_on_auth_user_created ON auth.users;

CREATE TRIGGER pf_on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.pf_handle_new_user();

COMMENT ON FUNCTION public.pf_handle_new_user IS
'PocketFlow: Auto-creates pf_profiles and pf_user_finance_settings rows when a new auth user is created.';
