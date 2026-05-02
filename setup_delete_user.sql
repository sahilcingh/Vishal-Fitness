-- ==========================================
-- USER ACCOUNT DELETION SETUP
-- ==========================================

-- This function allows a user to delete their own account from the client side.
-- It must be created in the 'public' schema with 'security definer' 
-- so it has bypass RLS to delete from the auth.users table.

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- 1. Optional: Delete from other tables first if they don't have ON DELETE CASCADE
    -- DELETE FROM public.workout_logs WHERE user_id = auth.uid();
    -- DELETE FROM public.subscriptions WHERE user_id = auth.uid();
    
    -- 2. Delete from public.profiles (if exists)
    DELETE FROM public.profiles WHERE id = auth.uid();
    
    -- 3. Delete the user from auth.users
    -- This will also sign the user out automatically
    DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

-- Grant access to the function to authenticated users
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
