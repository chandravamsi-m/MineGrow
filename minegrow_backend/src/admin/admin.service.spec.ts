import { BadRequestException, NotFoundException } from '@nestjs/common';
import { AdminService } from './admin.service';

describe('AdminService wallet adjustment', () => {
  const makeService = (rpc: jest.Mock) => {
    const supabaseService = {
      getClient: jest.fn(() => ({ rpc })),
    };
    const auditService = { log: jest.fn() };
    const fcmService = { sendNotification: jest.fn() };
    const appConfigService = { updateVal: jest.fn() };

    return {
      service: new AdminService(
        supabaseService as any,
        auditService as any,
        fcmService as any,
        appConfigService as any,
      ),
      supabaseService,
    };
  };

  it('calls the atomic wallet adjustment RPC with audited parameters', async () => {
    const wallet = {
      user_id: 42,
      roi_balance: 1200,
      principal_balance: 5000,
    };
    const rpc = jest.fn().mockResolvedValue({
      data: { wallet, ledgerId: 99 },
      error: null,
    });
    const { service } = makeService(rpc);

    await expect(
      service.adjustUserWallet(
        7,
        42,
        {
          walletType: 'roi',
          direction: 'credit',
          amount: 250,
          reason: 'Correct approved ROI credit',
        },
        '127.0.0.1',
      ),
    ).resolves.toEqual({ wallet, ledgerId: 99 });

    expect(rpc).toHaveBeenCalledWith('adjust_user_wallet', {
      p_admin_id: 7,
      p_user_id: 42,
      p_wallet_type: 'roi',
      p_direction: 'credit',
      p_amount: 250,
      p_reason: 'Correct approved ROI credit',
      p_ip_address: '127.0.0.1',
    });
  });

  it('rejects non-positive adjustments before touching the database', async () => {
    const rpc = jest.fn();
    const { service } = makeService(rpc);

    await expect(
      service.adjustUserWallet(7, 42, {
        walletType: 'principal',
        direction: 'debit',
        amount: 0,
        reason: 'Invalid amount',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(rpc).not.toHaveBeenCalled();
  });

  it('maps missing-wallet RPC failures to not found', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: null,
      error: { message: 'Wallet not found for user' },
    });
    const { service } = makeService(rpc);

    await expect(
      service.adjustUserWallet(7, 42, {
        walletType: 'roi',
        direction: 'debit',
        amount: 100,
        reason: 'Correction',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
