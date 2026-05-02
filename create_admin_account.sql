-- =========================================================
-- CREATE ADMIN ACCOUNT SCRIPT
-- =========================================================
-- Run this in your Supabase SQL Editor.
-- This script creates the user 'sahilcingh@gmail.com' with password 'admin@'
-- and assigns the 'admin' role to their profile.

-- 1. Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  new_user_id UUID := gen_random_uuid();
  user_email TEXT := 'sahilcingh@gmail.com';
  user_password TEXT := 'admin@';
BEGIN
  -- 2. Create the user in auth.users if they don't exist
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = user_email) THEN
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      email_change,
      email_change_token_new,
      recovery_token
    )
    VALUES (
      new_user_id,
      '00000000-0000-0000-0000-000000000000',
      user_email,
      crypt(user_password, gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}',
      '{"full_name":"Sahil Singh"}',
      now(),
      now(),
      '',
      '',
      '',
      ''
    );

    -- 3. Create the identity for the user
    INSERT INTO auth.identities (
      id,
      user_id,
      identity_data,
      provider,
      last_sign_in_at,
      created_at,
      updated_at
    )
    VALUES (
      new_user_id,
      new_user_id,
      format('{"sub":"%s","email":"%s"}', new_user_id, user_email)::jsonb,
      'email',
      now(),
      now(),
      now()
    );
  ELSE
    SELECT id INTO new_user_id FROM auth.users WHERE email = user_email;
  END IF;

  -- 4. Create or Update the profile with admin role
  INSERT INTO public.profiles (id, full_name, role, updated_at)
  VALUES (new_user_id, 'Sahil Singh', 'admin', now())
  ON CONFLICT (id) DO UPDATE 
  SET role = 'admin', full_name = 'Sahil Singh', updated_at = now();

END $$;

-- 5. Ensure the is_admin helper function exists (used by RLS)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
