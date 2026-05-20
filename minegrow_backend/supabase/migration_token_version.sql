-- ============================================================
-- Migration: Add token_version for server-side JWT invalidation
-- Fixes: CRIT-3 (logout invalidation) and CRIT-4 (refresh token rotation)
-- 
-- How it works:
--   - Each user/admin has a token_version integer (default 1)
--   - All issued JWTs carry the current token_version in the `tv` claim
--   - On logout, token_version is incremented for that user
--   - JwtStrategy.validate() rejects any token where payload.tv !== db.token_version
--   - This instantly invalidates ALL tokens (access + refresh) issued before logout
-- ============================================================

-- Add token_version to users table
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 1;

-- Add token_version to admins table  
ALTER TABLE admins
  ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 1;

-- ============================================================
-- RPC function to safely increment token_version (atomic)
-- Called by AuthService.logout()
-- ============================================================
CREATE OR REPLACE FUNCTION increment_token_version(p_table TEXT, p_user_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_table = 'users' THEN
    UPDATE users SET token_version = token_version + 1 WHERE id = p_user_id;
  ELSIF p_table = 'admins' THEN
    UPDATE admins SET token_version = token_version + 1 WHERE id = p_user_id;
  ELSE
    RAISE EXCEPTION 'Invalid table: %', p_table;
  END IF;
END;
$$;

-- Grant execute permission to service role
GRANT EXECUTE ON FUNCTION increment_token_version(TEXT, BIGINT) TO service_role;
