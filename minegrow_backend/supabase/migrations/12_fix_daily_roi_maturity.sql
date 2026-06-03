-- 12. Fix credit_daily_roi to run maturity checks even if ROI was already credited.

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
      -- Already credited for this investment today, skip crediting but proceed to maturity checks
      NULL;
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
