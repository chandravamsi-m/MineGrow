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

  describe('getSystemLedger mapping', () => {
    it('correctly maps REJECT_DEPOSIT and REJECT_WITHDRAWAL events to their accurate types', async () => {
      const mockAuditLogs = [
        { id: 1, action: 'REJECT_DEPOSIT', metadata: { amount: 1000 }, created_at: '2026-06-03T10:00:00Z' },
        { id: 2, action: 'REJECT_WITHDRAWAL', metadata: { amount: 2000 }, created_at: '2026-06-03T11:00:00Z' },
      ];

      const rangeMock = jest.fn().mockResolvedValue({ data: mockAuditLogs, count: 2, error: null });
      const orderMock = jest.fn(() => ({ range: rangeMock }));
      const selectMock = jest.fn(() => ({ order: orderMock }));

      const mockSupabaseClient = {
        from: jest.fn(() => ({
          select: selectMock,
        })),
      };

      const auditService = { log: jest.fn() };
      const fcmService = { sendNotification: jest.fn() };
      const appConfigService = { updateVal: jest.fn() };
      const supabaseService = { getClient: jest.fn(() => mockSupabaseClient) };

      const service = new AdminService(
        supabaseService as any,
        auditService as any,
        fcmService as any,
        appConfigService as any,
      );

      const result = await service.getSystemLedger(1, 10);
      expect(result.data[0].transaction_type).toBe('rejected_deposit');
      expect(result.data[1].transaction_type).toBe('rejected_withdrawal');
      expect(result.data[0].description).toContain('Rejected deposit');
      expect(result.data[1].description).toContain('Rejected withdrawal');
    });
  });
});
