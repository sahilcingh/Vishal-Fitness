-- Adds a soft-delete marker for members. NULL means active; a timestamp
-- means the admin "deleted" (archived) this member - their login is revoked
-- and they're hidden from active member lists, but their profile,
-- subscriptions, and payment history are kept intact.
-- Run this once in the Supabase SQL editor.

alter table public.profiles
  add column if not exists archived_at timestamptz;
