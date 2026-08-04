-- Fixes delete_user_account() (originally defined in setup_delete_user.sql):
-- the previous version hard-deleted `profiles` and `auth.users`, with the
-- cleanup of subscriptions/payments/workout_logs commented out as "optional
-- ... if they don't have ON DELETE CASCADE" - left unresolved. Depending on
-- actual FK config that either failed for every member with any history, or
-- let a member unilaterally wipe their own payment/revenue history with none
-- of the safeguards the admin-side delete has.
--
-- This replaces it with the same soft-delete convention as the admin delete
-- flow (see setup_add_archived_at.sql, supabase/functions/delete-member):
-- archive the profile, ban the auth user so they can't log back in, and
-- leave every historical record untouched.
--
-- Run this once in the Supabase SQL editor.

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.profiles SET archived_at = now() WHERE id = auth.uid();

    -- Same mechanism Supabase's own Admin API uses for `ban_duration` -
    -- GoTrue refuses to issue a session while banned_until is in the future.
    UPDATE auth.users SET banned_until = now() + interval '100 years' WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
