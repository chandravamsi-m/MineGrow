import { PlansService } from './plans.service';

describe('PlansService', () => {
  beforeEach(() => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-05-22T00:00:00.000Z'));
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('creates plans with schema-backed timestamp columns', async () => {
    const insertedPlan = {
      id: 10,
      plan_name: 'Growth Plan',
      min_amount: 1000,
      max_amount: 5000,
      daily_roi_pct: 1,
      lock_days: 90,
      roi_withdraw_days: 30,
      image_url: null,
      is_active: true,
    };
    const single = jest.fn(async () => ({ data: insertedPlan, error: null }));
    const select = jest.fn(() => ({ single }));
    const insert = jest.fn(() => ({ select }));
    const supabaseService = {
      getClient: jest.fn(() => ({
        from: jest.fn(() => ({ insert })),
      })),
    };
    const auditService = { log: jest.fn() };
    const service = new PlansService(
      supabaseService as never,
      auditService as never,
    );

    await service.createPlan(
      7,
      {
        planName: 'Growth Plan',
        minAmount: 1000,
        maxAmount: 5000,
        dailyRoiPct: 1,
        lockDays: 90,
        roiWithdrawDays: 30,
      },
      '127.0.0.1',
    );

    expect(insert).toHaveBeenCalledWith(
      expect.objectContaining({
        plan_name: 'Growth Plan',
        min_amount: 1000,
        max_amount: 5000,
        daily_roi_pct: 1,
        lock_days: 90,
        roi_withdraw_days: 30,
        image_url: null,
        is_active: true,
        created_at: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T/),
        updated_at: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T/),
      }),
    );
    expect(auditService.log).toHaveBeenCalledWith(
      'admin',
      7,
      'CREATE_INVESTMENT_PLAN',
      null,
      10,
      { after: insertedPlan },
      '127.0.0.1',
    );
  });
});
