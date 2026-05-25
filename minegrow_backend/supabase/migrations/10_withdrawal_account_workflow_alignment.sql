ALTER TABLE withdrawals
  ADD COLUMN IF NOT EXISTS bank_account_id INTEGER,
  ADD COLUMN IF NOT EXISTS bank_name VARCHAR(100),
  ADD COLUMN IF NOT EXISTS account_number VARCHAR(30),
  ADD COLUMN IF NOT EXISTS ifsc_code VARCHAR(20),
  ADD COLUMN IF NOT EXISTS upi_id VARCHAR(100),
  ADD COLUMN IF NOT EXISTS admin_note TEXT,
  ADD COLUMN IF NOT EXISTS processed_by INTEGER REFERENCES admins(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS processed_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE bank_accounts
  ADD COLUMN IF NOT EXISTS account_type VARCHAR(10) DEFAULT 'bank' NOT NULL,
  ADD COLUMN IF NOT EXISTS account_holder VARCHAR(100),
  ADD COLUMN IF NOT EXISTS upi_id VARCHAR(100),
  ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT false NOT NULL;

ALTER TABLE withdrawals
  DROP CONSTRAINT IF EXISTS withdrawals_status_check;

ALTER TABLE withdrawals
  ADD CONSTRAINT withdrawals_status_check
  CHECK (status IN ('requested', 'approved', 'completed', 'rejected'));

ALTER TABLE wallet_ledger
  DROP CONSTRAINT IF EXISTS wallet_ledger_txn_type_check;

ALTER TABLE wallet_ledger
  ADD CONSTRAINT wallet_ledger_txn_type_check
  CHECK (txn_type IN ('roi_credit', 'withdrawal_debit', 'principal_credit', 'admin_adjustment'));

ALTER TABLE wallet_ledger
  DROP CONSTRAINT IF EXISTS wallet_ledger_reference_type_check;

ALTER TABLE wallet_ledger
  ADD CONSTRAINT wallet_ledger_reference_type_check
  CHECK (reference_type IN ('investment', 'withdrawal', 'roi', 'admin'));

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_withdrawals_bank_account'
  ) THEN
    ALTER TABLE withdrawals
      ADD CONSTRAINT fk_withdrawals_bank_account
      FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(id) ON DELETE SET NULL;
  END IF;
END $$;

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
  SELECT user_id, amount, withdrawal_type INTO v_user_id, v_amount, v_type
  FROM withdrawals
  WHERE id = p_withdrawal_id AND status = 'requested'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Withdrawal request not found or already processed';
  END IF;

  IF v_type = 'roi' THEN
    SELECT roi_balance INTO v_balance FROM wallets WHERE user_id = v_user_id FOR UPDATE;
    IF v_balance < v_amount THEN
      RAISE EXCEPTION 'Insufficient ROI balance';
    END IF;

    UPDATE wallets
    SET roi_balance = roi_balance - v_amount,
        last_roi_withdrawal_at = NOW(),
        updated_at = NOW()
    WHERE user_id = v_user_id
    RETURNING roi_balance INTO v_balance;

    v_wallet_type := 'roi';
  ELSIF v_type = 'principal' THEN
    SELECT principal_balance INTO v_balance FROM wallets WHERE user_id = v_user_id FOR UPDATE;
    IF v_balance < v_amount THEN
      RAISE EXCEPTION 'Insufficient principal balance';
    END IF;

    UPDATE wallets
    SET principal_balance = principal_balance - v_amount,
        updated_at = NOW()
    WHERE user_id = v_user_id
    RETURNING principal_balance INTO v_balance;

    v_wallet_type := 'principal';
  ELSE
    RAISE EXCEPTION 'Invalid withdrawal type';
  END IF;

  UPDATE withdrawals
  SET status = 'approved',
      processed_by = p_admin_id,
      processed_at = NOW()
  WHERE id = p_withdrawal_id;

  INSERT INTO wallet_ledger (
    user_id,
    wallet_type,
    txn_type,
    amount,
    direction,
    reference_id,
    reference_type,
    balance_after
  )
  VALUES (
    v_user_id,
    v_wallet_type,
    'withdrawal_debit',
    v_amount,
    'debit',
    p_withdrawal_id,
    'withdrawal',
    v_balance
  );

  INSERT INTO audit_logs (
    actor_type,
    actor_id,
    target_user_id,
    action,
    reference_id,
    metadata,
    created_at
  )
  VALUES (
    'admin',
    p_admin_id,
    v_user_id,
    'APPROVE_WITHDRAWAL',
    p_withdrawal_id,
    json_build_object('amount', v_amount, 'type', v_type),
    NOW()
  );
END;
$$;
