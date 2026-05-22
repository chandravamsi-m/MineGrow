import { WithdrawalsService } from './withdrawals.service';

type QueryResult<T> = {
  data: T;
  error: null | Error;
};

function makeQuery<T>(result: QueryResult<T>) {
  const query = {
    select: jest.fn(() => query),
    eq: jest.fn(() => query),
    not: jest.fn(() => query),
    order: jest.fn(() => query),
    limit: jest.fn(() => query),
    single: jest.fn(async () => result),
    maybeSingle: jest.fn(async () => result),
  };

  return query;
}

describe('WithdrawalsService', () => {
  const auditService = { log: jest.fn() };

  beforeEach(() => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-05-22T00:00:00.000Z'));
    jest.clearAllMocks();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  function createService(options: {
    wallet: {
      roi_balance: number;
      principal_balance: number;
      last_roi_withdrawal_at: string | null;
    };
    earliestInvestment: { start_date: string } | null;
  }) {
    const queries = {
      users: makeQuery({ data: { status: 'active' }, error: null }),
      wallets: makeQuery({ data: options.wallet, error: null }),
      investments: makeQuery({
        data: options.earliestInvestment,
        error: null,
      }),
    };
    const from = jest.fn((table: keyof typeof queries) => queries[table]);
    const supabaseService = { getClient: jest.fn(() => ({ from })) };
    const service = new WithdrawalsService(
      supabaseService as never,
      auditService as never,
    );

    return { service, from, queries };
  }

  it('blocks the first ROI withdrawal until 30 days after earliest active investment start date', async () => {
    const { service, queries } = createService({
      wallet: {
        roi_balance: 500,
        principal_balance: 0,
        last_roi_withdrawal_at: null,
      },
      earliestInvestment: { start_date: '2026-05-01' },
    });

    const eligibility = await service.getEligibility(42);

    expect(eligibility.roi).toEqual({
      eligible: false,
      message: 'Withdrawals are locked. Next eligible date: 2026-05-31',
      balance: 500,
    });
    expect(queries.investments.eq).toHaveBeenCalledWith('user_id', 42);
    expect(queries.investments.eq).toHaveBeenCalledWith('status', 'active');
    expect(queries.investments.order).toHaveBeenCalledWith('start_date', {
      ascending: true,
    });
    expect(queries.investments.limit).toHaveBeenCalledWith(1);
  });

  it('allows the first ROI withdrawal after the investment start-date lock has elapsed', async () => {
    const { service } = createService({
      wallet: {
        roi_balance: 500,
        principal_balance: 0,
        last_roi_withdrawal_at: null,
      },
      earliestInvestment: { start_date: '2026-04-22' },
    });

    const eligibility = await service.getEligibility(42);

    expect(eligibility.roi).toEqual({
      eligible: true,
      message: 'Eligible for withdrawal',
      balance: 500,
    });
  });

  it('uses last ROI withdrawal date for subsequent ROI withdrawal locks', async () => {
    const { service, from } = createService({
      wallet: {
        roi_balance: 500,
        principal_balance: 0,
        last_roi_withdrawal_at: '2026-05-01T00:00:00.000Z',
      },
      earliestInvestment: { start_date: '2026-04-01' },
    });

    const eligibility = await service.getEligibility(42);

    expect(eligibility.roi).toEqual({
      eligible: false,
      message: 'Withdrawals are locked. Next eligible date: 2026-05-31',
      balance: 500,
    });
    expect(from).not.toHaveBeenCalledWith('investments');
  });
});
