-- Track which admin last updated runtime app configuration rows.

ALTER TABLE app_config
  ADD COLUMN IF NOT EXISTS updated_by_admin INTEGER REFERENCES admins(id) ON DELETE SET NULL;
