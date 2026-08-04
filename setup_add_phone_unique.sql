-- Closes the duplicate-phone gap for good: the create-member Edge Function
-- now checks for an existing phone before creating a new profile, but that
-- check alone can't stop two near-simultaneous requests (e.g. two staff
-- handling the same walk-in) from both passing the check before either
-- commits. A real unique index is the only thing that can't be raced.
--
-- Verified against production data before writing this: zero existing
-- profiles share a phone number, so this is safe to add as-is. If that ever
-- changes before this is run, the migration will fail loudly rather than
-- silently succeeding with bad data - resolve the duplicate manually first.
--
-- Run this once in the Supabase SQL editor.

CREATE UNIQUE INDEX IF NOT EXISTS profiles_phone_unique_idx
  ON public.profiles (phone)
  WHERE phone IS NOT NULL;
