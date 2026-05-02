-- ==========================================
-- CHECK IF EMAIL EXISTS RPC
-- ==========================================

-- This function allows checking if an email is already registered 
-- in the auth.users table from the client side.
-- SECURITY DEFINER is required to access the auth schema.

CREATE OR REPLACE FUNCTION public.check_email_exists(email_to_check TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE email = email_to_check
    );
END;
$$;

-- Grant access to both anonymous and authenticated users
GRANT EXECUTE ON FUNCTION public.check_email_exists(TEXT) TO anon, authenticated;
