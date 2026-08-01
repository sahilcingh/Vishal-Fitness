-- ==========================================
-- MEMBER LEDGER: EVENT LOG TABLE
-- ==========================================
-- Subscriptions (renewals), payments, and check_ins are already insert-only
-- and preserve full history on their own. This table exists only to capture
-- the mutations that currently overwrite data in place with no history:
--   - subscription status changes (active/suspended/cancelled)
--   - subscription discount changes
--   - subscription pass/date edits made via "Edit Member"
--   - profile edits (name/phone/gender/time slot/photo) made via "Edit Member"
-- It only captures these going forward from whenever this script is run -
-- past overwrites can't be recovered since the old values were never stored.

CREATE TABLE IF NOT EXISTS public.member_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('status_change', 'discount_change', 'subscription_edit', 'profile_edit')),
    description TEXT NOT NULL,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS member_events_user_id_idx ON public.member_events (user_id, created_at DESC);

ALTER TABLE public.member_events ENABLE ROW LEVEL SECURITY;

-- Matches the "Admins can manage app config" policy shape in
-- setup_auto_update.sql - this table is admin-only tooling (no member-facing
-- reads), gated the same way via the existing public.is_admin() helper.
DROP POLICY IF EXISTS "Admins can manage member events" ON public.member_events;
CREATE POLICY "Admins can manage member events" ON public.member_events
    FOR ALL USING (public.is_admin());
