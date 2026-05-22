INSERT INTO app_config (key, value) VALUES
  ('support_email', 'support@minegrow.app'),
  ('support_phone', '+91 90000 00000'),
  ('terms_url', 'https://minegrow.app/terms'),
  ('privacy_url', 'https://minegrow.app/privacy'),
  ('risk_disclosure', 'Mining investment returns depend on active plan terms, approved deposits, and wallet eligibility rules.')
ON CONFLICT (key) DO NOTHING;
