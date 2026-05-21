-- ============================================================
-- Migration: Add app_config table and notification_preferences column to users
-- Target Platform: Supabase (PostgreSQL)
-- ============================================================

-- 1. Create 'app_config' table
CREATE TABLE IF NOT EXISTS app_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_by INTEGER REFERENCES users(id) ON DELETE SET NULL
);

-- Seed default configs
INSERT INTO app_config (key, value)
VALUES 
  ('payment_upi_id', 'minegrow@upi'),
  ('otp_resend_delay', '30')
ON CONFLICT (key) DO NOTHING;

-- 2. Add 'notification_preferences' column to 'users' table
ALTER TABLE users 
  ADD COLUMN IF NOT EXISTS notification_preferences JSONB 
  DEFAULT '{"push": true, "investments": true, "wallet": true, "promotions": false}'::jsonb;
