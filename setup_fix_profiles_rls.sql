-- Fixes a confirmed-live data exposure: as of this audit, `profiles` had no
-- working RLS restricting SELECT, so ANY request with just the public anon
-- key (no login at all) could read every member's full_name, phone, address,
-- age, weight, height, fitness_goal, photo_url, etc. `admin_analytics` (an
-- aggregate business-metrics view, unused by this Next.js app - grep found
-- zero references to it in src/) was exposed the same way.
--
-- IMPORTANT: after running this, go to Database -> Policies -> profiles in
-- the Supabase dashboard and check for any OTHER pre-existing policy that
-- allows public/anon SELECT (e.g. a default "Enable read access for all
-- users" policy created via the dashboard UI) - this script can only add
-- correct policies and can't discover/remove an unknown pre-existing one by
-- name. Postgres OR's every matching policy together, so a single leftover
-- permissive one would silently keep the table exposed even after this runs.
--
-- Run this once in the Supabase SQL editor.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own profile, admins can view all" ON public.profiles;
CREATE POLICY "Users can view their own profile, admins can view all" ON public.profiles
    FOR SELECT USING (id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "Users can update their own profile, admins can update all" ON public.profiles;
CREATE POLICY "Users can update their own profile, admins can update all" ON public.profiles
    FOR UPDATE USING (id = auth.uid() OR public.is_admin())
    WITH CHECK (id = auth.uid() OR public.is_admin());

-- Row-level policies alone can't stop a member from writing a disallowed
-- COLUMN on a row they're otherwise allowed to touch (their own) - the
-- WITH CHECK above only verifies whose row it is, not which fields changed.
-- role/archived_at/needs_password_reset are only ever written by this app's
-- Edge Functions using the service-role key (confirmed: no client code
-- writes them directly), which bypasses grants entirely - so it's safe to
-- not grant these to authenticated sessions at all, closing the
-- self-privilege-escalation path (e.g. a member PATCHing their own row with
-- role: 'admin') completely rather than relying on the UI never doing it.
REVOKE UPDATE ON public.profiles FROM authenticated;
GRANT UPDATE (
    full_name, phone, gender, age, weight, height, fitness_goal, activity_level,
    photo_url, avatar_url, time_slot, address, updated_at,
    streak_count, week_volume_kg, sessions_last_7d
) ON public.profiles TO authenticated;

-- admin_analytics: not read by this app anywhere - lock it down entirely
-- rather than trying to gate it, since nothing depends on client access.
REVOKE ALL ON public.admin_analytics FROM anon, authenticated;
