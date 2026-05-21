-- Database Setup Schema for Mining Investment App
-- Target Platform: Supabase (PostgreSQL)

-- Enable UUID extension if needed
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Create 'users' table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    mobile VARCHAR(15) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE,
    password_hash TEXT,
    status VARCHAR(20) DEFAULT 'active' NOT NULL CHECK (status IN ('active', 'suspended', 'pending_kyc')),
    kyc_verified BOOLEAN DEFAULT false NOT NULL,
    notification_preferences JSONB DEFAULT '{"push": true, "investments": true, "wallet": true, "promotions": false}'::jsonb NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 1b. Create 'app_config' table
CREATE TABLE IF NOT EXISTS app_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_by INTEGER REFERENCES users(id) ON DELETE SET NULL
);

INSERT INTO app_config (key, value) VALUES 
  ('payment_upi_id', 'minegrow@upi'),
  ('otp_resend_delay', '30')
ON CONFLICT (key) DO NOTHING;

-- 2. Create 'admins' table
CREATE TABLE IF NOT EXISTS admins (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    is_super BOOLEAN DEFAULT false NOT NULL,
    created_by INTEGER REFERENCES admins(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'active' NOT NULL CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Create 'investment_plan' table (Single row plan metadata)
CREATE TABLE IF NOT EXISTS investment_plan (
    id SERIAL PRIMARY KEY,
    plan_name VARCHAR(50) NOT NULL,
    min_amount DECIMAL(12,2) NOT NULL DEFAULT 1000.00,
    max_amount DECIMAL(12,2) NOT NULL DEFAULT 500000.00,
    daily_roi_pct DECIMAL(5,2) NOT NULL DEFAULT 1.00,
    lock_days INTEGER NOT NULL DEFAULT 90,
    roi_withdraw_days INTEGER NOT NULL DEFAULT 30,
    is_active BOOLEAN DEFAULT true NOT NULL,
    image_url TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Seed plan metadata (Starter, Silver, Gold Plans)
INSERT INTO investment_plan (id, plan_name, min_amount, max_amount, daily_roi_pct, lock_days, roi_withdraw_days, is_active, image_url)
VALUES 
(1, 'Starter Plan', 1000.00, 10000.00, 1.00, 90, 30, true, 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA0MDAgMjUwIiB3aWR0aD0iMTAwJSI+PGRlZnM+PGxpbmVhckdyYWRpZW50IGlkPSJnMSIgeDE9IjAlIiB5MT0iMCUiIHgyPSIxMDAlIiB5Mj0iMTAwJSI+PHN0b3Agb2Zmc2V0PSIwJSIgc3RvcC1jb2xvcj0iIzA2NGU0MCIvPjxzdG9wIG9mZnNldD0iMTAwJSIgc3RvcC1jb2xvcj0iIzExMTgxMCIvPjwvbGluZWFyR3JhZGllbnQ+PC9kZWZzPjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMjUwIiByeD0iMTYiIGZpbGw9InVybCgjZzIpIi8+PGNpcmNsZSBjeD0iMzUwIiBjeT0iNTAiIHI9IjgwIiBmaWxsPSIjMTBkOTgxIiBmaWxsLW9wYWNpdHk9IjAuMDUiIGZpbHRlcj0iYmx1cigyMHB4KSIvPjxwYXRoIGQ9Ik0wIDE1MCBRIDEwMCAxMTAgMjAwIDE1MCBUIDQwMCAxNzAiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzEwZDk4MSIgc3Ryb2tlLW9wYWNpdHk9IjAuMTUiIHN0cm9rZS13aWR0aD0iMiIvPjxwYXRoIGQ9Ik0wIDE3MCBRIDEwMCAxMzAgMjAwIDE3MCBUIDQwMCAxOTAiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzEwZDk4MSIgc3Ryb2tlLW9wYWNpdHk9IjAuMDgiIHN0cm9rZS13aWR0aD0iMS41Ii8+PC9zdmc+'),
(2, 'Silver Plan', 10001.00, 50000.00, 1.20, 90, 30, true, 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA0MDAgMjUwIiB3aWR0aD0iMTAwJSI+PGRlZnM+PGxpbmVhckdyYWRpZW50IGlkPSJnMiIgeDE9IjAlIiB5MT0iMCUiIHgyPSIxMDAlIiB5Mj0iMTAwJSI+PHN0b3Agb2Zmc2V0PSIwJSIgc3RvcC1jb2xvcj0iIzFmMjkzNyIvPjxzdG9wIG9mZnNldD0iMTAwJSIgc3RvcC1jb2xvcj0iIzExMTgxMCIvPjwvbGluZWFyR3JhZGllbnQ+PC9kZWZzPjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMjUwIiByeD0iMTYiIGZpbGw9InVybCgjZzIpIi8+PGNpcmNsZSBjeD0iMzUwIiBjeT0iNTAiIHI9IjgwIiBmaWxsPSIjMzg4MmY2IiBmaWxsLW9wYWNpdHk9IjAuMDUiIGZpbHRlcj0iYmx1cigyMHB4KSIvPjxwYXRoIGQ9Ik0tNTAgMTAwIEw0NTAgMjAwIE0tNTAgMTIwIEw0NTAgMjIwIiBmaWxsPSJub25lIiBzdHJva2U9IiMzOGIyZjYiIHN0cm9rZS1vcGFjaXR5PSIwLjE1IiBzdHJva2Utd2lkdGg9IjIiLz48L3N2Zz4='),
(3, 'Gold Plan', 50001.00, 500000.00, 1.50, 90, 30, true, 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA0MDAgMjUwIiB3aWR0aD0iMTAwJSI+PGRlZnM+PGxpbmVhckdyYWRpZW50IGlkPSJnMyIgeDE9IjAlIiB5MT0iMCUiIHgyPSIxMDAlIiB5Mj0iMTAwJSI+PHN0b3Agb2Zmc2V0PSIwJSIgc3RvcC1jb2xvcj0iIzc4M2UwOCIvPjxzdG9wIG9mZnNldD0iMTAwJSIgc3RvcC1jb2xvcj0iIzExMTgxMCIvPjwvbGluZWFyR3JhZGllbnQ+PC9kZWZzPjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMjUwIiByeD0iMTYiIGZpbGw9InVybCgjZzMpIi8+PGNpcmNsZSBjeD0iMzUwIiBjeT0iNTAiIHI9IjgwIiBmaWxsPSIjZjViMDVjIiBmaWxsLW9wYWNpdHk9IjAuMDgiIGZpbHRlcj0iYmx1cigyMHB4KSIvPjxwYXRoIGQ9Ik0yMDAgMCBMMjAwIDI1MCBNMTAwIDEyNSBMMzAwIDEyNSIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjZjViMDVjIiBzdHJva2Utb3BhY2l0eT0iMC4xIiBzdHJva2Utd2lkdGg9IjEuNSIvPjxwYXRoIGQ9Ik0wIDUwIEw0MDAgMjAwIiBmaWxsPSJub25lIiBzdHJva2U9IiNmNWIwNWMiIHN0cm9rZS1vcGFjaXR5PSIwLjEzIiBzdHJva2Utd2lkdGg9IjIiLz48L3N2Zz4=')
ON CONFLICT (id) DO UPDATE SET
  plan_name = EXCLUDED.plan_name,
  min_amount = EXCLUDED.min_amount,
  max_amount = EXCLUDED.max_amount,
  daily_roi_pct = EXCLUDED.daily_roi_pct,
  lock_days = EXCLUDED.lock_days,
  roi_withdraw_days = EXCLUDED.roi_withdraw_days,
  is_active = EXCLUDED.is_active,
  image_url = EXCLUDED.image_url;

-- 4. Create 'investments' table
CREATE TABLE IF NOT EXISTS investments (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    plan_id INTEGER REFERENCES investment_plan(id) ON DELETE SET NULL,
    amount DECIMAL(12,2) NOT NULL,
    daily_roi_pct DECIMAL(5,2) NOT NULL,
    lock_days INTEGER NOT NULL,
    payment_proof_url TEXT,
    utr_number VARCHAR(50),
    status VARCHAR(20) DEFAULT 'pending' NOT NULL CHECK (status IN ('pending', 'approved', 'active', 'matured', 'rejected')),
    start_date DATE,
    maturity_date DATE,
    admin_note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('Asia/Kolkata'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('Asia/Kolkata'::text, now()) NOT NULL
);

-- 5. Create 'wallets' table
CREATE TABLE IF NOT EXISTS wallets (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    roi_balance DECIMAL(12,2) DEFAULT 0.00 NOT NULL,
    principal_balance DECIMAL(12,2) DEFAULT 0.00 NOT NULL,
    total_roi_earned DECIMAL(12,2) DEFAULT 0.00 NOT NULL,
    last_roi_withdrawal_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. Create 'wallet_ledger' table
CREATE TABLE IF NOT EXISTS wallet_ledger (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    wallet_type VARCHAR(20) NOT NULL CHECK (wallet_type IN ('roi', 'principal')),
    txn_type VARCHAR(30) NOT NULL CHECK (txn_type IN ('roi_credit', 'withdrawal_debit', 'principal_credit', 'admin_adjustment')),
    amount DECIMAL(12,2) NOT NULL,
    direction VARCHAR(10) NOT NULL CHECK (direction IN ('credit', 'debit')),
    reference_id INTEGER,
    reference_type VARCHAR(30) CHECK (reference_type IN ('investment', 'withdrawal', 'roi', 'admin')),
    note TEXT,
    balance_after DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. Create 'roi_history' table
CREATE TABLE IF NOT EXISTS roi_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    investment_id INTEGER REFERENCES investments(id) ON DELETE CASCADE NOT NULL,
    roi_amount DECIMAL(12,2) NOT NULL,
    credited_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT unique_investment_date UNIQUE (investment_id, credited_date)
);

-- 8. Create 'withdrawals' table (Temporary stub, FK added later)
CREATE TABLE IF NOT EXISTS withdrawals (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    withdrawal_type VARCHAR(20) NOT NULL CHECK (withdrawal_type IN ('roi', 'principal')),
    amount DECIMAL(12,2) NOT NULL,
    bank_account_id INTEGER,
    bank_name VARCHAR(100),
    account_number VARCHAR(30),
    ifsc_code VARCHAR(20),
    upi_id VARCHAR(100),
    status VARCHAR(20) DEFAULT 'requested' NOT NULL CHECK (status IN ('requested', 'approved', 'completed', 'rejected')),
    admin_note TEXT,
    processed_by INTEGER REFERENCES admins(id) ON DELETE SET NULL,
    processed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 9. Create 'bank_accounts' table
CREATE TABLE IF NOT EXISTS bank_accounts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    account_type VARCHAR(10) NOT NULL CHECK (account_type IN ('bank', 'upi')),
    bank_name VARCHAR(100),
    account_number VARCHAR(30),
    ifsc_code VARCHAR(20),
    account_holder VARCHAR(100),
    upi_id VARCHAR(100),
    is_default BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Add bank account foreign key to withdrawals
ALTER TABLE withdrawals ADD CONSTRAINT fk_withdrawals_bank_account FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(id) ON DELETE SET NULL;

-- 10. Create 'kyc_documents' table
CREATE TABLE IF NOT EXISTS kyc_documents (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    doc_type VARCHAR(30) NOT NULL CHECK (doc_type IN ('aadhaar', 'pan', 'passport', 'driving_license')),
    doc_url TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by INTEGER REFERENCES admins(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    admin_notes TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 11. Create 'otps' table
CREATE TABLE IF NOT EXISTS otps (
    id SERIAL PRIMARY KEY,
    mobile VARCHAR(15) NOT NULL,
    otp_hash TEXT NOT NULL,
    purpose VARCHAR(20) NOT NULL CHECK (purpose IN ('register', 'login', 'forgot_password')),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 12. Create 'device_tokens' table
CREATE TABLE IF NOT EXISTS device_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    fcm_token TEXT NOT NULL,
    platform VARCHAR(10) NOT NULL CHECK (platform IN ('android', 'ios')),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 13. Create 'audit_logs' table
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    actor_type VARCHAR(10) NOT NULL CHECK (actor_type IN ('admin', 'system', 'user')),
    actor_id INTEGER,
    target_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(60) NOT NULL,
    reference_id INTEGER,
    metadata JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 14. Create 'notifications' table
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    title VARCHAR(100) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(30) NOT NULL CHECK (type IN ('roi_credit', 'deposit_approved', 'deposit_rejected', 'withdrawal_approved', 'withdrawal_completed', 'withdrawal_rejected', 'investment_matured', 'general')),
    is_read BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 15. Create indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_users_mobile ON users(mobile);
CREATE INDEX IF NOT EXISTS idx_investments_status ON investments(status);
CREATE INDEX IF NOT EXISTS idx_roi_history_credited_date ON roi_history(credited_date);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON withdrawals(status);
CREATE INDEX IF NOT EXISTS idx_otps_mobile_expires_at ON otps(mobile, expires_at);

-- 16. Define PostgREST-compatible RPC functions

-- RPC 1: credit_daily_roi (Processes all active investments and handles daily accruals + maturity)
DROP FUNCTION IF EXISTS credit_daily_roi(INTEGER, INTEGER, DECIMAL, DATE);
CREATE OR REPLACE FUNCTION credit_daily_roi(
  p_credited_date DATE
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  r RECORD;
  v_roi_amount DECIMAL(12,2);
  v_new_roi_bal DECIMAL(12,2);
  v_new_pri_bal DECIMAL(12,2);
  v_success_count INTEGER := 0;
  v_matured_count INTEGER := 0;
  v_ledger_note TEXT;
BEGIN
  -- Iterate through all active investments
  FOR r IN 
    SELECT id, user_id, amount, daily_roi_pct, lock_days, start_date, maturity_date 
    FROM investments 
    WHERE status = 'active'
  LOOP
    -- 1. Calculate daily ROI amount
    v_roi_amount := ROUND((r.amount * r.daily_roi_pct) / 100.0, 2);

    -- 2. Try to credit the daily ROI (using a sub-block to handle double-credit prevention)
    BEGIN
      -- Insert into history (fails if duplicate for this investment on this date)
      INSERT INTO roi_history (investment_id, user_id, roi_amount, credited_date)
      VALUES (r.id, r.user_id, v_roi_amount, p_credited_date);

      -- Update wallet ROI balance
      UPDATE wallets
      SET roi_balance = roi_balance + v_roi_amount,
          total_roi_earned = total_roi_earned + v_roi_amount,
          updated_at = NOW()
      WHERE user_id = r.user_id
      RETURNING roi_balance INTO v_new_roi_bal;

      -- Write to ledger
      v_ledger_note := 'Daily ROI Credit: ' || r.daily_roi_pct || '% of ₹' || r.amount;
      INSERT INTO wallet_ledger (user_id, wallet_type, txn_type, amount, direction, reference_id, reference_type, note, balance_after)
      VALUES (r.user_id, 'roi', 'roi_credit', v_roi_amount, 'credit', r.id, 'investment', v_ledger_note, v_new_roi_bal);

      v_success_count := v_success_count + 1;
    EXCEPTION WHEN unique_violation THEN
      -- Already credited for this investment today, skip it
      CONTINUE;
    END;

    -- 3. Check for maturity condition
    IF p_credited_date >= r.maturity_date THEN
      -- Transition status to matured
      UPDATE investments
      SET status = 'matured',
          updated_at = NOW()
      WHERE id = r.id;

      -- Return original principal amount back to user's principal wallet balance
      UPDATE wallets
      SET principal_balance = principal_balance + r.amount,
          updated_at = NOW()
      WHERE user_id = r.user_id
      RETURNING principal_balance INTO v_new_pri_bal;

      -- Write maturity payout to ledger
      INSERT INTO wallet_ledger (user_id, wallet_type, txn_type, amount, direction, reference_id, reference_type, note, balance_after)
      VALUES (r.user_id, 'principal', 'principal_credit', r.amount, 'credit', r.id, 'investment', 'Principal unlocked upon investment maturity', v_new_pri_bal);

      v_matured_count := v_matured_count + 1;
    END IF;

  END LOOP;

  RETURN jsonb_build_object(
    'processed_date', p_credited_date,
    'roi_credits_issued', v_success_count,
    'investments_matured', v_matured_count
  );
END;
$$;

-- RPC 2: approve_withdrawal
CREATE OR REPLACE FUNCTION approve_withdrawal(
  p_withdrawal_id INTEGER,
  p_admin_id INTEGER
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id INTEGER;
  v_amount DECIMAL;
  v_type VARCHAR(20);
  v_wallet_type VARCHAR(20);
  v_balance DECIMAL;
BEGIN
  -- Get withdrawal details and lock the row
  SELECT user_id, amount, withdrawal_type INTO v_user_id, v_amount, v_type
  FROM withdrawals
  WHERE id = p_withdrawal_id AND status = 'requested'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Withdrawal request not found or already processed';
  END IF;

  -- Re-validate wallet balance and deduct
  IF v_type = 'roi' THEN
    -- Check balance
    SELECT roi_balance INTO v_balance FROM wallets WHERE user_id = v_user_id FOR UPDATE;
    IF v_balance < v_amount THEN
      RAISE EXCEPTION 'Insufficient ROI balance';
    END IF;

    -- Update wallet
    UPDATE wallets
    SET roi_balance = roi_balance - v_amount,
        last_roi_withdrawal_at = NOW(),
        updated_at = NOW()
    WHERE user_id = v_user_id
    RETURNING roi_balance INTO v_balance;

    v_wallet_type := 'roi';
  ELSIF v_type = 'principal' THEN
    -- Check balance
    SELECT principal_balance INTO v_balance FROM wallets WHERE user_id = v_user_id FOR UPDATE;
    IF v_balance < v_amount THEN
      RAISE EXCEPTION 'Insufficient principal balance';
    END IF;

    -- Update wallet
    UPDATE wallets
    SET principal_balance = principal_balance - v_amount,
        updated_at = NOW()
    WHERE user_id = v_user_id
    RETURNING principal_balance INTO v_balance;

    v_wallet_type := 'principal';
  ELSE
    RAISE EXCEPTION 'Invalid withdrawal type';
  END IF;

  -- Update withdrawal status
  UPDATE withdrawals
  SET status = 'approved',
      processed_by = p_admin_id,
      processed_at = NOW()
  WHERE id = p_withdrawal_id;

  -- Insert ledger entry
  INSERT INTO wallet_ledger (user_id, wallet_type, txn_type, amount, direction, reference_id, reference_type, balance_after)
  VALUES (v_user_id, v_wallet_type, 'withdrawal_debit', v_amount, 'debit', p_withdrawal_id, 'withdrawal', v_balance);

  -- Insert audit log
  INSERT INTO audit_logs (actor_type, actor_id, target_user_id, action, reference_id, metadata, created_at)
  VALUES ('admin', p_admin_id, v_user_id, 'APPROVE_WITHDRAWAL', p_withdrawal_id, json_build_object('amount', v_amount, 'type', v_type), NOW());
END;
$$;
