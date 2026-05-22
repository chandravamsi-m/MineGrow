-- Atomic admin wallet adjustment with ledger and audit records.

CREATE OR REPLACE FUNCTION adjust_user_wallet(
  p_admin_id INTEGER,
  p_user_id INTEGER,
  p_wallet_type VARCHAR(20),
  p_direction VARCHAR(10),
  p_amount DECIMAL,
  p_reason TEXT,
  p_ip_address TEXT DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_wallet wallets%ROWTYPE;
  v_current_balance DECIMAL;
  v_next_balance DECIMAL;
  v_ledger_id INTEGER;
BEGIN
  IF p_wallet_type NOT IN ('roi', 'principal') THEN
    RAISE EXCEPTION 'Invalid wallet type';
  END IF;

  IF p_direction NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Invalid wallet adjustment direction';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Wallet adjustment amount must be positive';
  END IF;

  SELECT * INTO v_wallet
  FROM wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wallet not found for user';
  END IF;

  v_current_balance := CASE
    WHEN p_wallet_type = 'roi' THEN v_wallet.roi_balance
    ELSE v_wallet.principal_balance
  END;

  v_next_balance := CASE
    WHEN p_direction = 'credit' THEN v_current_balance + p_amount
    ELSE v_current_balance - p_amount
  END;

  IF v_next_balance < 0 THEN
    RAISE EXCEPTION 'Insufficient wallet balance for debit adjustment';
  END IF;

  UPDATE wallets
  SET roi_balance = CASE
        WHEN p_wallet_type = 'roi' THEN v_next_balance
        ELSE roi_balance
      END,
      principal_balance = CASE
        WHEN p_wallet_type = 'principal' THEN v_next_balance
        ELSE principal_balance
      END,
      updated_at = NOW()
  WHERE user_id = p_user_id
  RETURNING * INTO v_wallet;

  INSERT INTO wallet_ledger (
    user_id,
    wallet_type,
    txn_type,
    amount,
    direction,
    reference_type,
    note,
    balance_after
  )
  VALUES (
    p_user_id,
    p_wallet_type,
    'admin_adjustment',
    p_amount,
    p_direction,
    'admin',
    p_reason,
    v_next_balance
  )
  RETURNING id INTO v_ledger_id;

  INSERT INTO audit_logs (
    actor_type,
    actor_id,
    target_user_id,
    action,
    reference_id,
    metadata,
    ip_address,
    created_at
  )
  VALUES (
    'admin',
    p_admin_id,
    p_user_id,
    'ADJUST_USER_WALLET',
    v_ledger_id,
    json_build_object(
      'walletType', p_wallet_type,
      'direction', p_direction,
      'amount', p_amount,
      'reason', p_reason,
      'balanceBefore', v_current_balance,
      'balanceAfter', v_next_balance
    ),
    p_ip_address,
    NOW()
  );

  RETURN jsonb_build_object(
    'wallet', to_jsonb(v_wallet),
    'ledgerId', v_ledger_id
  );
END;
$$;
