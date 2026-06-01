-- 11. Account deletion (App Store / Google Play compliance) + remote app gates.

-- 1. Allow soft-deleting a user account.
--    We soft-delete (not hard delete) so financial records — investments,
--    withdrawals, wallet ledger, ROI history, audit logs — remain intact for
--    compliance, while the account becomes unusable and PII is scrubbed.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_status_check;
ALTER TABLE users
  ADD CONSTRAINT users_status_check
  CHECK (status IN ('active', 'suspended', 'pending_kyc', 'deleted'));

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- 2. Remote config keys driving the mobile maintenance + force-update gates.
--    Empty min_supported_version / update_url means "no gate". maintenance_mode
--    'false' keeps the app open by default.
INSERT INTO app_config (key, value) VALUES
  ('maintenance_mode', 'false'),
  ('maintenance_message', 'MineGrow is briefly down for maintenance. Please check back shortly.'),
  ('min_supported_version', ''),
  ('update_url', '')
ON CONFLICT (key) DO NOTHING;
