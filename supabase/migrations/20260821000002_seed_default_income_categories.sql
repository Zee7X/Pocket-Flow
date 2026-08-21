-- =============================================================================
-- PocketFlow Migration: Seed default income categories & update new user trigger
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

    -- Create default income categories
    INSERT INTO public.pf_categories (user_id, name, type, icon, color, is_active, is_spendable, sort_order)
    VALUES
        (NEW.id, 'Gaji Pokok', 'income', '💵', '#10B981', true, false, 1),
        (NEW.id, 'Bonus / THR', 'income', '🎁', '#F59E0B', true, false, 2),
        (NEW.id, 'Freelance / Side Job', 'income', '💻', '#3B82F6', true, false, 3),
        (NEW.id, 'Investasi / Pasif', 'income', '📈', '#8B5CF6', true, false, 4),
        (NEW.id, 'Pemasukan Lainnya', 'income', '💰', '#06B6D4', true, false, 5)
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$;

-- Insert default income categories for existing users
INSERT INTO public.pf_categories (user_id, name, type, icon, color, is_active, is_spendable, sort_order)
SELECT 
    u.id, 
    cat.name, 
    cat.type, 
    cat.icon, 
    cat.color, 
    true, 
    false, 
    cat.sort_order
FROM auth.users u
CROSS JOIN (
    VALUES 
        ('Gaji Pokok', 'income', '💵', '#10B981', 1),
        ('Bonus / THR', 'income', '🎁', '#F59E0B', 2),
        ('Freelance / Side Job', 'income', '💻', '#3B82F6', 3),
        ('Investasi / Pasif', 'income', '📈', '#8B5CF6', 4),
        ('Pemasukan Lainnya', 'income', '💰', '#06B6D4', 5)
) AS cat(name, type, icon, color, sort_order)
WHERE NOT EXISTS (
    SELECT 1 FROM public.pf_categories c 
    WHERE c.user_id = u.id AND c.name = cat.name AND c.type = cat.type
);
