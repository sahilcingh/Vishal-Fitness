-- Allows member_events to log payment edits/deletes (added alongside the
-- new PaymentsModal edit/delete capability). Run this once in the Supabase
-- SQL editor.

alter table public.member_events
  drop constraint if exists member_events_event_type_check;

alter table public.member_events
  add constraint member_events_event_type_check
  check (event_type in ('status_change', 'discount_change', 'subscription_edit', 'profile_edit', 'payment_edit', 'payment_delete'));
