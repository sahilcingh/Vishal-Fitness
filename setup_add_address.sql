-- Adds an optional postal address field to member profiles.
-- Run this once in the Supabase SQL editor.

alter table public.profiles
  add column if not exists address text;
