const { createClient } = require('@supabase/supabase-js');
const url = 'https://lrixucumgltudgzmgskj.supabase.co';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxyaXh1Y3VtZ2x0dWRnem1nc2tqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTA4ODA1MCwiZXhwIjoyMDk0NjY0MDUwfQ.31nCIyozo0vl2UeOyVgRysRtix0lAjDbWofaODYr4z8';

const supabase = createClient(url, key);

async function runTest() {
  console.log('Starting daily ROI rerun validation...');

  const testMobile = '9999988888';
  const testEmail = 'test_roi_maturity@example.com';
  const todayDate = new Date().toISOString().split('T')[0];

  let testUserId = null;
  let testInvestmentId = null;

  try {
    // 1. Clean up any previous test remnants if they exist
    const { data: existingUser } = await supabase.from('users').select('id').eq('mobile', testMobile).maybeSingle();
    if (existingUser) {
      await supabase.from('roi_history').delete().eq('user_id', existingUser.id);
      await supabase.from('wallet_ledger').delete().eq('user_id', existingUser.id);
      await supabase.from('wallets').delete().eq('user_id', existingUser.id);
      await supabase.from('investments').delete().eq('user_id', existingUser.id);
      await supabase.from('users').delete().eq('id', existingUser.id);
      console.log('Cleaned up previous test leftovers.');
    }

    // 2. Insert test user
    const { data: newUser, error: userError } = await supabase.from('users').insert({
      full_name: 'Test ROI Maturity User',
      mobile: testMobile,
      email: testEmail,
      status: 'active',
      kyc_verified: true
    }).select().single();

    if (userError) throw userError;
    testUserId = newUser.id;
    console.log(`Inserted test user with ID: ${testUserId}`);

    // 3. Create wallet for user
    const { error: walletError } = await supabase.from('wallets').insert({
      user_id: testUserId,
      roi_balance: 0.00,
      principal_balance: 0.00,
      total_roi_earned: 0.00
    });
    if (walletError) throw walletError;
    console.log('Inserted test wallet.');

    // 4. Create active investment that has matured today
    const { data: newInvestment, error: invError } = await supabase.from('investments').insert({
      user_id: testUserId,
      plan_id: 1, // Starter Plan
      amount: 1000.00,
      daily_roi_pct: 1.00,
      lock_days: 90,
      status: 'active',
      start_date: '2026-03-05',
      maturity_date: todayDate // Matures today!
    }).select().single();

    if (invError) throw invError;
    testInvestmentId = newInvestment.id;
    console.log(`Inserted matured test investment with ID: ${testInvestmentId}`);

    // 5. Test Step 1: Run credit_daily_roi first time
    console.log('\n--- Running credit_daily_roi for the first time ---');
    const { data: result1, error: rpcError1 } = await supabase.rpc('credit_daily_roi', {
      p_credited_date: todayDate
    });
    if (rpcError1) throw rpcError1;
    console.log('RPC result 1:', result1);

    // Verify investment matured and ROI history created
    const { data: inv1 } = await supabase.from('investments').select('status').eq('id', testInvestmentId).single();
    const { data: wallet1 } = await supabase.from('wallets').select('*').eq('user_id', testUserId).single();
    const { data: history1 } = await supabase.from('roi_history').select('*').eq('investment_id', testInvestmentId);

    console.log('Verification 1:');
    console.log('- Investment status (expected: matured):', inv1.status);
    console.log('- Wallet ROI balance (expected: 10.00):', wallet1.roi_balance);
    console.log('- Wallet Principal balance (expected: 1000.00):', wallet1.principal_balance);
    console.log('- ROI history entries (expected: 1):', history1.length);

    // 6. Test Step 2: Reset investment to active and reset principal to test rerun / retry skip path
    console.log('\n--- Resetting investment & wallet balances to simulate rerun environment ---');
    await supabase.from('investments').update({ status: 'active' }).eq('id', testInvestmentId);
    await supabase.from('wallets').update({ principal_balance: 0.00, roi_balance: 0.00 }).eq('user_id', testUserId);
    console.log('Reset complete. ROI history entry is intentionally kept.');

    // Run credit_daily_roi second time (rerun)
    console.log('\n--- Running credit_daily_roi for the second time (rerun) ---');
    const { data: result2, error: rpcError2 } = await supabase.rpc('credit_daily_roi', {
      p_credited_date: todayDate
    });
    if (rpcError2) throw rpcError2;
    console.log('RPC result 2:', result2);

    // Verify results
    const { data: inv2 } = await supabase.from('investments').select('status').eq('id', testInvestmentId).single();
    const { data: wallet2 } = await supabase.from('wallets').select('*').eq('user_id', testUserId).single();
    const { data: history2 } = await supabase.from('roi_history').select('*').eq('investment_id', testInvestmentId);

    console.log('Verification 2:');
    console.log('- Investment status (expected: matured):', inv2.status);
    console.log('- Wallet ROI balance (expected: 0.00 - not double-credited):', wallet2.roi_balance);
    console.log('- Wallet Principal balance (expected: 1000.00 - matured successfully):', wallet2.principal_balance);
    console.log('- ROI history entries (expected: 1 - no duplicate history row):', history2.length);

    if (inv2.status === 'matured' && Number(wallet2.roi_balance) === 0 && Number(wallet2.principal_balance) === 1000 && history2.length === 1) {
      console.log('\n✅ SUCCESS: Maturity checks successfully ran and matured the investment during rerun without double-crediting daily ROI!');
    } else {
      console.log('\n❌ FAILURE: Rerun verification failed.');
    }

  } catch (error) {
    console.error('Error during validation execution:', error);
  } finally {
    // 7. Cleanup
    if (testUserId) {
      console.log('\n--- Cleaning up test records from database ---');
      await supabase.from('roi_history').delete().eq('user_id', testUserId);
      await supabase.from('wallet_ledger').delete().eq('user_id', testUserId);
      await supabase.from('wallets').delete().eq('user_id', testUserId);
      await supabase.from('investments').delete().eq('user_id', testUserId);
      await supabase.from('users').delete().eq('id', testUserId);
      console.log('Cleanup completed successfully.');
    }
  }
}

runTest();
