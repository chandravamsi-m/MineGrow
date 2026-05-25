import {
  Injectable,
  NotFoundException,
  BadRequestException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { SupabaseClientService } from '../config/supabase.client';
import { AuditService } from '../audit/audit.service';
import { FcmService } from '../notifications/fcm.service';
import { AppConfigService } from '../app-config/app-config.service';
import {
  UpdateUserStatusDto,
  KycReviewDto,
  AdjustWalletDto,
} from './dto/admin.dto';
import { getISTDateTimeString } from '../common/utils/date.utils';
import {
  buildPaginationMeta,
  getPaginationWindow,
} from '../common/utils/pagination.utils';

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);
  private readonly aggregatePageSize = 1000;

  constructor(
    private readonly supabaseService: SupabaseClientService,
    private readonly auditService: AuditService,
    private readonly fcmService: FcmService,
    private readonly appConfigService: AppConfigService,
  ) {}

  async getUsers(search?: string, status?: string, page?: number, limit?: number) {
    const pagination = getPaginationWindow(page, limit, 50, 100);
    const supabase = this.supabaseService.getClient();
    let query = supabase
      .from('users')
      .select('id, full_name, mobile, email, status, kyc_verified, created_at', {
        count: 'exact',
      });

    if (status) {
      query = query.eq('status', status);
    }

    if (search) {
      // Basic mobile or name match
      query = query.or(`full_name.ilike.%${search}%,mobile.ilike.%${search}%`);
    }

    const {
      data: users,
      count,
      error,
    } = await query
      .order('created_at', { ascending: false })
      .range(pagination.from, pagination.to);

    if (error) {
      throw new InternalServerErrorException('Error loading users list');
    }

    return {
      data: users || [],
      pagination: buildPaginationMeta(
        pagination.page,
        pagination.limit,
        count || 0,
      ),
    };
  }

  async getUserDetail(userId: number) {
    const supabase = this.supabaseService.getClient();

    // 1. Profile
    const { data: profile } = await supabase
      .from('users')
      .select('id, full_name, mobile, email, status, kyc_verified, address, notification_preferences, created_at')
      .eq('id', userId)
      .single();
    if (!profile) {
      throw new NotFoundException('User profile not found');
    }

    // 2. Wallet
    const { data: wallet } = await supabase
      .from('wallets')
      .select('*')
      .eq('user_id', userId)
      .maybeSingle();

    // 3. Investments
    const { data: investments } = await supabase
      .from('investments')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    // 4. Withdrawals
    const { data: withdrawals } = await supabase
      .from('withdrawals')
      .select('*')
      .eq('user_id', userId)
      .order('requested_at', { ascending: false });

    // 5. KYC Scans
    const { data: kycDocs } = await supabase
      .from('kyc_documents')
      .select('*')
      .eq('user_id', userId)
      .order('uploaded_at', { ascending: false });

    // 6. Bank accounts
    const { data: bankAccounts } = await supabase
      .from('bank_accounts')
      .select('*')
      .eq('user_id', userId);

    return {
      profile,
      wallet,
      investments,
      withdrawals,
      kycDocs,
      bankAccounts,
    };
  }

  async updateUserStatus(
    adminId: number,
    userId: number,
    dto: UpdateUserStatusDto,
    ipAddress?: string,
  ) {
    const supabase = this.supabaseService.getClient();

    const { data: user, error: fetchError } = await supabase
      .from('users')
      .select('status')
      .eq('id', userId)
      .single();
    if (fetchError || !user) {
      throw new NotFoundException('User not found');
    }

    const { data: updated, error } = await supabase
      .from('users')
      .update({ status: dto.status, updated_at: getISTDateTimeString() })
      .eq('id', userId)
      .select('id, full_name, status')
      .single();

    if (error || !updated) {
      throw new InternalServerErrorException('Error updating user status');
    }

    // Audit log
    await this.auditService.log(
      'admin',
      adminId,
      'UPDATE_USER_STATUS',
      userId,
      null,
      { fromStatus: user.status, toStatus: dto.status },
      ipAddress,
    );

    return updated;
  }

  async verifyUserKyc(adminId: number, userId: number, ipAddress?: string) {
    const supabase = this.supabaseService.getClient();

    // Check if there are any pending KYC documents
    const { data: pendingDocs, error: checkError } = await supabase
      .from('kyc_documents')
      .select('id')
      .eq('user_id', userId)
      .eq('status', 'pending');

    if (checkError) {
      throw new InternalServerErrorException('Error checking KYC documents status');
    }

    if (!pendingDocs || pendingDocs.length === 0) {
      throw new BadRequestException('No pending KYC document submissions found for this user');
    }

    // 1. Approve all pending KYC scanned documents
    const { error: kycError } = await supabase
      .from('kyc_documents')
      .update({ status: 'approved', reviewed_at: getISTDateTimeString() })
      .eq('user_id', userId)
      .eq('status', 'pending');

    if (kycError) {
      this.logger.error('Failed to verify KYC documents:', kycError);
      throw new InternalServerErrorException('Error updating KYC documents');
    }

    // 2. Set user as kyc_verified
    const { data: updated, error: userError } = await supabase
      .from('users')
      .update({
        kyc_verified: true,
        status: 'active',
        updated_at: getISTDateTimeString(),
      })
      .eq('id', userId)
      .select('id, full_name, mobile')
      .single();

    if (userError || !updated) {
      throw new InternalServerErrorException(
        'Error updating user KYC status flags',
      );
    }

    // 3. Dispatch Push Notification
    await this.fcmService.sendNotification(
      userId,
      'KYC Verified Successfully ✅',
      'Congratulations! Your KYC documentation has been approved. Your account is fully verified.',
      { type: 'kyc_verified' },
    );

    // 4. Audit log
    await this.auditService.log(
      'admin',
      adminId,
      'APPROVE_KYC_VERIFICATION',
      userId,
      null,
      {},
      ipAddress,
    );

    return { message: 'KYC verified and approved successfully', user: updated };
  }

  async rejectUserKyc(
    adminId: number,
    userId: number,
    dto: KycReviewDto,
    ipAddress?: string,
  ) {
    const supabase = this.supabaseService.getClient();

    // Check if there are any pending KYC documents
    const { data: pendingDocs, error: checkError } = await supabase
      .from('kyc_documents')
      .select('id')
      .eq('user_id', userId)
      .eq('status', 'pending');

    if (checkError) {
      throw new InternalServerErrorException('Error checking KYC documents status');
    }

    if (!pendingDocs || pendingDocs.length === 0) {
      throw new BadRequestException('No pending KYC document submissions found for this user');
    }

    // 1. Reject KYC documents
    const { error: kycError } = await supabase
      .from('kyc_documents')
      .update({
        status: 'rejected',
        admin_notes: dto.reason,
        reviewed_at: getISTDateTimeString(),
      })
      .eq('user_id', userId)
      .eq('status', 'pending');

    if (kycError) {
      throw new InternalServerErrorException(
        'Error updating KYC documents rejection notes',
      );
    }

    // 2. Revert user status to active
    await supabase
      .from('users')
      .update({ status: 'active', updated_at: getISTDateTimeString() })
      .eq('id', userId)
      .eq('status', 'pending_kyc');

    // 3. Dispatch Push Notification
    await this.fcmService.sendNotification(
      userId,
      'KYC Verification Failed ❌',
      `Your KYC submission was rejected. Reason: ${dto.reason}. Please re-upload.`,
      { type: 'kyc_rejected', reason: dto.reason },
    );

    // 4. Audit log
    await this.auditService.log(
      'admin',
      adminId,
      'REJECT_KYC_VERIFICATION',
      userId,
      null,
      { reason: dto.reason },
      ipAddress,
    );

    return { message: 'KYC submission rejected successfully' };
  }

  async adjustUserWallet(
    adminId: number,
    userId: number,
    dto: AdjustWalletDto,
    ipAddress?: string,
  ) {
    const amount = Number(dto.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('Wallet adjustment amount must be positive');
    }

    const supabase = this.supabaseService.getClient();
    const { data, error } = await supabase.rpc('adjust_user_wallet', {
      p_admin_id: adminId,
      p_user_id: userId,
      p_wallet_type: dto.walletType,
      p_direction: dto.direction,
      p_amount: amount,
      p_reason: dto.reason,
      p_ip_address: ipAddress || null,
    });

    if (error) {
      const message = error.message || 'Error adjusting wallet balance';
      this.logger.error('Failed to adjust wallet balance:', error);

      if (message.toLowerCase().includes('wallet not found')) {
        throw new NotFoundException('User wallet not found');
      }

      if (
        message.toLowerCase().includes('insufficient') ||
        message.toLowerCase().includes('invalid') ||
        message.toLowerCase().includes('positive')
      ) {
        throw new BadRequestException(message);
      }

      throw new InternalServerErrorException('Error adjusting wallet balance');
    }

    return data;
  }

  /**
   * Generates aggregated statistics for the admin dashboard home.
   */
  async getDashboardStats() {
    const supabase = this.supabaseService.getClient();

    // 1. Get counts
    const { count: activeUsers } = await supabase
      .from('users')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'active');
    const { count: activeInvestments } = await supabase
      .from('investments')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'active');
    const { count: pendingInvestments } = await supabase
      .from('investments')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'pending');
    const { count: pendingWithdrawals } = await supabase
      .from('withdrawals')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'requested');

    // 2. Sums. Keep each response bounded so dashboard requests do not load
    // entire financial tables into memory.
    const totalDeposited = await this.sumNumericColumn(
      'investments',
      'amount',
      (query) => query.in('status', ['active', 'matured']),
    );
    const totalWithdrawn = await this.sumNumericColumn(
      'withdrawals',
      'amount',
      (query) => query.eq('status', 'completed'),
    );
    const activeLockSum = await this.sumNumericColumn(
      'investments',
      'amount',
      (query) => query.eq('status', 'active'),
    );
    const totalRoiDistributed = await this.sumNumericColumn(
      'roi_history',
      'roi_amount',
    );

    // Surface the most-recent ROI cron run so the admin dashboard can show
    // a last-run timestamp next to the manual trigger.
    const { data: lastRoiAudit } = await supabase
      .from('audit_logs')
      .select('id, action, actor_type, metadata, created_at')
      .in('action', [
        'EXECUTE_DAILY_ROI_ROUTINE',
        'EXECUTE_DAILY_ROI_ROUTINE_FAILED',
      ])
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    const lastRoiRun = lastRoiAudit
      ? {
          ranAt: lastRoiAudit.created_at,
          status:
            lastRoiAudit.action === 'EXECUTE_DAILY_ROI_ROUTINE'
              ? 'success'
              : 'failed',
          source: lastRoiAudit.actor_type === 'admin' ? 'manual' : 'cron',
          creditedDate: lastRoiAudit.metadata?.creditedDate || null,
          creditsIssued:
            lastRoiAudit.metadata?.result?.roi_credits_issued ?? null,
          auditId: lastRoiAudit.id,
        }
      : null;

    return {
      totalActiveUsers: activeUsers || 0,
      totalActiveInvestments: activeInvestments || 0,
      totalFundsDeposited: totalDeposited,
      totalFundsWithdrawn: totalWithdrawn,
      pendingDepositApprovalsCount: pendingInvestments || 0,
      pendingWithdrawalRequestsCount: pendingWithdrawals || 0,
      activePrincipalLockSum: activeLockSum,
      totalDailyRoiDistributed: totalRoiDistributed,
      lastRoiRun,
    };
  }

  private async sumNumericColumn(
    table: string,
    column: string,
    applyFilters?: (query: any) => any,
  ): Promise<number> {
    const supabase = this.supabaseService.getClient();
    let total = 0;
    let from = 0;

    while (true) {
      let query = supabase
        .from(table)
        .select(column)
        .range(from, from + this.aggregatePageSize - 1);

      if (applyFilters) {
        query = applyFilters(query);
      }

      const { data, error } = await query;

      if (error) {
        this.logger.error(`Error summing ${table}.${column}:`, error);
        throw new InternalServerErrorException('Error loading dashboard totals');
      }

      const rows = data || [];
      for (const row of rows) {
        total += Number((row as unknown as Record<string, unknown>)[column]) || 0;
      }

      if (rows.length < this.aggregatePageSize) {
        break;
      }

      from += this.aggregatePageSize;
    }

    return total;
  }

  async getSystemLedger(page = 1, limit = 50) {
    const supabase = this.supabaseService.getClient();
    const from = (page - 1) * limit;
    const to = from + limit - 1;

    const {
      data: ledger,
      count,
      error,
    } = await supabase
      .from('audit_logs')
      .select('*, users!target_user_id(full_name, mobile)', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(from, to);

    if (error) {
      this.logger.error('Error fetching system audit ledger logs:', error);
      throw new InternalServerErrorException(
        'Error loading system financial ledger',
      );
    }

    const total = count || 0;
    const totalPages = Math.ceil(total / limit);

    const ledgerItems = ledger || [];

    // 1. Gather all unique dates of daily ROI calculation routines in the current page
    const roiDates = Array.from(
      new Set(
        ledgerItems
          .filter(
            (entry: any) =>
              entry.action === 'EXECUTE_DAILY_ROI_ROUTINE' &&
              entry.metadata?.creditedDate,
          )
          .map((entry: any) => entry.metadata.creditedDate),
      ),
    );

    // 2. Fetch total ROI sums grouped by credited_date in a single round-trip
    const dailySums: Record<string, number> = {};
    if (roiDates.length > 0) {
      const { data: roiHistory, error: historyError } = await supabase
        .from('roi_history')
        .select('roi_amount, credited_date')
        .in('credited_date', roiDates);

      if (!historyError && roiHistory) {
        for (const row of roiHistory) {
          const d = row.credited_date;
          const amt = Number(row.roi_amount) || 0;
          dailySums[d] = (dailySums[d] || 0) + amt;
        }
      }
    }

    const mappedLedger = ledgerItems.map((entry: any) => {
      let transactionType:
        | 'deposit'
        | 'roi'
        | 'withdrawal'
        | 'principal_return' = 'deposit';
      let description = '';

      const action = entry.action;
      const metadata = entry.metadata || {};
      let amount = Number(metadata.amount) || 0;

      if (action === 'APPROVE_DEPOSIT') {
        transactionType = 'deposit';
        description = `Approved deposit request of ₹${amount.toLocaleString()}`;
      } else if (action === 'REJECT_DEPOSIT') {
        transactionType = 'withdrawal';
        description = `Rejected deposit request of ₹${amount.toLocaleString()}`;
      } else if (action === 'APPROVE_WITHDRAWAL') {
        transactionType = 'withdrawal';
        description = `Approved withdrawal of ₹${amount.toLocaleString()}`;
      } else if (action === 'REJECT_WITHDRAWAL') {
        transactionType = 'deposit';
        description = `Rejected withdrawal of ₹${amount.toLocaleString()}`;
      } else if (action === 'COMPLETE_WITHDRAWAL') {
        transactionType = 'withdrawal';
        description = `Settled withdrawal payout of ₹${amount.toLocaleString()}`;
      } else if (action === 'APPROVE_KYC_VERIFICATION') {
        transactionType = 'deposit';
        description = `Approved client KYC onboarding`;
      } else if (action === 'REJECT_KYC_VERIFICATION') {
        transactionType = 'withdrawal';
        description = `Rejected client KYC onboarding`;
      } else if (action === 'UPDATE_USER_STATUS') {
        transactionType = 'deposit';
        description = `Updated client account status`;
      } else if (action === 'EXECUTE_DAILY_ROI_ROUTINE') {
        transactionType = 'roi';
        const creditedDate = metadata.creditedDate || '';
        amount = dailySums[creditedDate] || 0;
        const numCredits = metadata.result?.roi_credits_issued || 0;
        description = `Daily ROI routine (${numCredits} credits)`;
      } else {
        transactionType = 'deposit';
        description = `${action.replace(/_/g, ' ')}`;
      }

      return {
        id: entry.id,
        user_id: entry.target_user_id || entry.actor_id || 0,
        amount: amount,
        transaction_type: transactionType,
        description: description,
        reference_id: entry.reference_id,
        created_at: entry.created_at,
        users: entry.users,
      };
    });

    return {
      data: mappedLedger,
      pagination: {
        page,
        limit,
        total,
        totalPages,
      },
    };
  }

  async getAppConfigs() {
    const supabase = this.supabaseService.getClient();
    const { data, error } = await supabase
      .from('app_config')
      .select('key, value, updated_at')
      .order('key');

    if (error) {
      if (error.code === 'PGRST205') {
        this.logger.warn("Table 'app_config' not found in database. Serving default system settings. Please execute migration SQL.");
        return [
          { key: 'payment_upi_id', value: 'minegrow@upi', updated_at: new Date().toISOString() },
          { key: 'otp_resend_delay', value: '30', updated_at: new Date().toISOString() }
        ];
      }
      this.logger.error('Failed to fetch app configs:', error);
      throw new InternalServerErrorException('Error loading system configs');
    }
    return data;
  }

  async updateAppConfig(
    adminId: number,
    key: string,
    value: string,
    ipAddress?: string,
  ) {
    // 1. Update DB & invalidate cache via AppConfigService
    await this.appConfigService.updateVal(key, value, adminId);

    // 2. Audit log
    await this.auditService.log(
      'admin',
      adminId,
      'UPDATE_CONFIG',
      null,
      null,
      { key, value },
      ipAddress,
    );

    return { success: true };
  }
}
