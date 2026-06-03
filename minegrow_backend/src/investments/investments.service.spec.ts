import { BadRequestException, NotFoundException } from '@nestjs/common';
import { InvestmentsService } from './investments.service';

describe('InvestmentsService approval & rejection concurrency', () => {
  const makeService = (mockSupabaseClient: any) => {
    const supabaseService = {
      getClient: jest.fn(() => mockSupabaseClient),
    };
    const uploadsService = { uploadFile: jest.fn() };
    const plansService = { getPlanById: jest.fn() };
    const auditService = { log: jest.fn() };

    return {
      service: new InvestmentsService(
        supabaseService as any,
        uploadsService as any,
        plansService as any,
        auditService as any,
      ),
      supabaseService,
      auditService,
    };
  };

  describe('approveInvestment', () => {
    it('approves a pending investment request successfully', async () => {
      const investment = { id: 5, status: 'pending', lock_days: 90, amount: 2000, user_id: 12 };
      const approved = { ...investment, status: 'active', start_date: '2026-06-03', maturity_date: '2026-09-01' };

      let callCount = 0;
      const mockSupabaseClient = {
        from: jest.fn(() => {
          callCount++;
          if (callCount === 1) {
            return {
              select: jest.fn(() => ({
                eq: jest.fn(() => ({
                  single: jest.fn().mockResolvedValue({ data: investment, error: null }),
                })),
              })),
            };
          } else {
            return {
              update: jest.fn(() => ({
                eq: jest.fn(() => ({
                  eq: jest.fn(() => ({
                    select: jest.fn(() => ({
                      maybeSingle: jest.fn().mockResolvedValue({ data: approved, error: null }),
                    })),
                  })),
                })),
              })),
            };
          }
        }),
      };

      const { service, auditService } = makeService(mockSupabaseClient);
      const result = await service.approveInvestment(1, 5, '127.0.0.1');

      expect(result).toEqual(approved);
      expect(auditService.log).toHaveBeenCalledWith(
        'admin',
        1,
        'APPROVE_DEPOSIT',
        approved.user_id,
        approved.id,
        expect.any(Object),
        '127.0.0.1',
      );
    });

    it('rejects approval if the investment status is not pending', async () => {
      const investment = { id: 5, status: 'active', lock_days: 90, amount: 2000, user_id: 12 };

      const mockSupabaseClient = {
        from: jest.fn(() => ({
          select: jest.fn(() => ({
            eq: jest.fn(() => ({
              single: jest.fn().mockResolvedValue({ data: investment, error: null }),
            })),
          })),
        })),
      };

      const { service } = makeService(mockSupabaseClient);
      await expect(service.approveInvestment(1, 5, '127.0.0.1')).rejects.toBeInstanceOf(BadRequestException);
    });

    it('throws BadRequestException if update matches 0 rows (concurrent update race)', async () => {
      const investment = { id: 5, status: 'pending', lock_days: 90, amount: 2000, user_id: 12 };

      let callCount = 0;
      const mockSupabaseClient = {
        from: jest.fn(() => {
          callCount++;
          if (callCount === 1) {
            return {
              select: jest.fn(() => ({
                eq: jest.fn(() => ({
                  single: jest.fn().mockResolvedValue({ data: investment, error: null }),
                })),
              })),
            };
          } else {
            return {
              update: jest.fn(() => ({
                eq: jest.fn(() => ({
                  eq: jest.fn(() => ({
                    select: jest.fn(() => ({
                      maybeSingle: jest.fn().mockResolvedValue({ data: null, error: null }),
                    })),
                  })),
                })),
              })),
            };
          }
        }),
      };

      const { service } = makeService(mockSupabaseClient);
      await expect(service.approveInvestment(1, 5, '127.0.0.1')).rejects.toThrow(
        new BadRequestException('Investment request has already been processed by another administrator'),
      );
    });
  });

  describe('rejectInvestment', () => {
    it('rejects a pending investment request successfully', async () => {
      const investment = { id: 6, status: 'pending', lock_days: 90, amount: 3000, user_id: 13 };
      const rejected = { ...investment, status: 'rejected', admin_note: 'Invalid transaction receipt' };

      let callCount = 0;
      const mockSupabaseClient = {
        from: jest.fn(() => {
          callCount++;
          if (callCount === 1) {
            return {
              select: jest.fn(() => ({
                eq: jest.fn(() => ({
                  single: jest.fn().mockResolvedValue({ data: investment, error: null }),
                })),
              })),
            };
          } else {
            return {
              update: jest.fn(() => ({
                eq: jest.fn(() => ({
                  eq: jest.fn(() => ({
                    select: jest.fn(() => ({
                      maybeSingle: jest.fn().mockResolvedValue({ data: rejected, error: null }),
                    })),
                  })),
                })),
              })),
            };
          }
        }),
      };

      const { service, auditService } = makeService(mockSupabaseClient);
      const result = await service.rejectInvestment(1, 6, { adminNote: 'Invalid transaction receipt' }, '127.0.0.1');

      expect(result).toEqual(rejected);
      expect(auditService.log).toHaveBeenCalledWith(
        'admin',
        1,
        'REJECT_DEPOSIT',
        rejected.user_id,
        rejected.id,
        expect.any(Object),
        '127.0.0.1',
      );
    });

    it('rejects rejection if the investment status is not pending', async () => {
      const investment = { id: 6, status: 'rejected', lock_days: 90, amount: 3000, user_id: 13 };

      const mockSupabaseClient = {
        from: jest.fn(() => ({
          select: jest.fn(() => ({
            eq: jest.fn(() => ({
              single: jest.fn().mockResolvedValue({ data: investment, error: null }),
            })),
          })),
        })),
      };

      const { service } = makeService(mockSupabaseClient);
      await expect(
        service.rejectInvestment(1, 6, { adminNote: 'Invalid transaction receipt' }, '127.0.0.1'),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('throws BadRequestException if update matches 0 rows (concurrent rejection race)', async () => {
      const investment = { id: 6, status: 'pending', lock_days: 90, amount: 3000, user_id: 13 };

      let callCount = 0;
      const mockSupabaseClient = {
        from: jest.fn(() => {
          callCount++;
          if (callCount === 1) {
            return {
              select: jest.fn(() => ({
                eq: jest.fn(() => ({
                  single: jest.fn().mockResolvedValue({ data: investment, error: null }),
                })),
              })),
            };
          } else {
            return {
              update: jest.fn(() => ({
                eq: jest.fn(() => ({
                  eq: jest.fn(() => ({
                    select: jest.fn(() => ({
                      maybeSingle: jest.fn().mockResolvedValue({ data: null, error: null }),
                    })),
                  })),
                })),
              })),
            };
          }
        }),
      };

      const { service } = makeService(mockSupabaseClient);
      await expect(
        service.rejectInvestment(1, 6, { adminNote: 'Invalid transaction receipt' }, '127.0.0.1'),
      ).rejects.toThrow(
        new BadRequestException('Investment request has already been processed by another administrator'),
      );
    });
  });
});
