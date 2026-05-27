ALTER TABLE users
  ADD COLUMN IF NOT EXISTS token_version INTEGER DEFAULT 1 NOT NULL;

ALTER TABLE admins
  ADD COLUMN IF NOT EXISTS token_version INTEGER DEFAULT 1 NOT NULL;

CREATE OR REPLACE FUNCTION increment_token_version(
  p_table TEXT,
  p_user_id INTEGER
) RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_next_version INTEGER;
BEGIN
  IF p_table = 'users' THEN
    UPDATE users
    SET token_version = token_version + 1,
        updated_at = NOW()
    WHERE id = p_user_id
    RETURNING token_version INTO v_next_version;
  ELSIF p_table = 'admins' THEN
    UPDATE admins
    SET token_version = token_version + 1
    WHERE id = p_user_id
    RETURNING token_version INTO v_next_version;
  ELSE
    RAISE EXCEPTION 'Invalid token version table';
  END IF;

  IF v_next_version IS NULL THEN
    RAISE EXCEPTION 'Account not found';
  END IF;

  RETURN v_next_version;
END;
$$;
