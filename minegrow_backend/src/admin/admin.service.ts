import { Injectable, NotFoundException, BadRequestException, InternalServerErrorException, Logger } from '@nestjs/common';
import { SupabaseClientService } from '../config/supabase.client';
import { AuditService } from '../audit/audit.service';
import { FcmService } from '../notifications/fcm.service';
import { UpdateUserStatusDto, KycReviewDto } from './dto/admin.dto';
import { getISTDateTimeString } from '../common/utils/date.utils';

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(
    private readonly supabaseService: SupabaseClientService,
    private readonly auditService: AuditService,
    private readonly fcmService: FcmService,
  ) {}

  async getUsers(search?: string, status?: string) {
    const supabase = this.supabaseService.getClient();
    let query = supabase.from('users').select('id, full_name, mobile, email, status, kyc_verified, created_at');

    if (status) {
      query = query.eq('status', status);
    }

    if (search) {
      // Basic mobile or name match
      query = query.or(`full_name.ilike.%${search}%,mobile.ilike.%${search}%`);
    }

    const { data: users, error } = await query.order('created_at', { ascending: false });

    if (error) {
      throw new InternalServerErrorException('Error loading users list');
    }

    return users;
  }

  async getUserDetail(userId: number) {
    const supabase = this.supabaseService.getClient();

    // 1. Profile
    const { data: profile } = await supabase.from('users').select('id, full_name, mobile, email, status, kyc_verified, created_at').eq('id', userId).single();
    if (!profile) {
      throw new NotFoundException('User profile not found');
    }

    // 2. Wallet
    const { data: wallet } = await supabase.from('wallets').select('*').eq('user_id', userId).maybeSingle();

    // 3. Investments
    const { data: investments } = await supabase.from('investments').select('*').eq('user_id', userId).order('created_at', { ascending: false });

    // 4. Withdrawals
    const { data: withdrawals } = await supabase.from('withdrawals').select('*').eq('user_id', userId).order('requested_at', { ascending: false });

    // 5. KYC Scans
    const { data: kycDocs } = await supabase.from('kyc_documents').select('*').eq('user_id', userId).order('uploaded_at', { ascending: false });

    // 6. Bank accounts
    const { data: bankAccounts } = await supabase.from('bank_accounts').select('*').eq('user_id', userId);

    return {
      profile,
      wallet,
      investments,
      withdrawals,
      kycDocs,
      bankAccounts,
    };
  }

  async updateUserStatus(adminId: number, userId: number, dto: UpdateUserStatusDto, ipAddress?: string) {
    const supabase = this.supabaseService.getClient();

    const { data: user, error: fetchError } = await supabase.from('users').select('status').eq('id', userId).single();
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
      .update({ kyc_verified: true, status: 'active', updated_at: getISTDateTimeString() })
      .eq('id', userId)
      .select('id, full_name, mobile')
      .single();

    if (userError || !updated) {
      throw new InternalServerErrorException('Error updating user KYC status flags');
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

  async rejectUserKyc(adminId: number, userId: number, dto: KycReviewDto, ipAddress?: string) {
    const supabase = this.supabaseService.getClient();

    // 1. Reject KYC documents
    const { error: kycError } = await supabase
      .from('kyc_documents')
      .update({ status: 'rejected', admin_notes: dto.reason, reviewed_at: getISTDateTimeString() })
      .eq('user_id', userId)
      .eq('status', 'pending');

    if (kycError) {
      throw new InternalServerErrorException('Error updating KYC documents rejection notes');
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

  /**
   * Generates aggregated statistics for the admin dashboard home.
   */
  async getDashboardStats() {
    const supabase = this.supabaseService.getClient();

    // 1. Get counts
    const { count: activeUsers } = await supabase.from('users').select('id', { count: 'exact', head: true }).eq('status', 'active');
    const { count: activeInvestments } = await supabase.from('investments').select('id', { count: 'exact', head: true }).eq('status', 'active');
    const { count: pendingInvestments } = await supabase.from('investments').select('id', { count: 'exact', head: true }).eq('status', 'pending');
    const { count: pendingWithdrawals } = await supabase.from('withdrawals').select('id', { count: 'exact', head: true }).eq('status', 'requested');

    // 2. Sums
    const { data: deposits } = await supabase.from('investments').select('amount').in('status', ['active', 'matured']);
    const totalDeposited = deposits ? deposits.reduce((acc, curr) => acc + Number(curr.amount), 0) : 0;

    const { data: withdrawals } = await supabase.from('withdrawals').select('amount').eq('status', 'completed');
    const totalWithdrawn = withdrawals ? withdrawals.reduce((acc, curr) => acc + Number(curr.amount), 0) : 0;

    const { data: activeLocks } = await supabase.from('investments').select('amount').eq('status', 'active');
    const activeLockSum = activeLocks ? activeLocks.reduce((acc, curr) => acc + Number(curr.amount), 0) : 0;

    const { data: roiEarned } = await supabase.from('roi_history').select('roi_amount');
    const totalRoiDistributed = roiEarned ? roiEarned.reduce((acc, curr) => acc + Number(curr.roi_amount), 0) : 0;

    return {
      totalActiveUsers: activeUsers || 0,
      totalActiveInvestments: activeInvestments || 0,
      totalFundsDeposited: totalDeposited,
      totalFundsWithdrawn: totalWithdrawn,
      pendingDepositApprovalsCount: pendingInvestments || 0,
      pendingWithdrawalRequestsCount: pendingWithdrawals || 0,
      activePrincipalLockSum: activeLockSum,
      totalDailyRoiDistributed: totalRoiDistributed,
    };
  }

  async getSystemLedger(page = 1, limit = 50) {
    const supabase = this.supabaseService.getClient();
    const from = (page - 1) * limit;
    const to = from + limit - 1;

    const { data: ledger, count, error } = await supabase
      .from('wallet_ledger')
      .select('*, users(full_name, mobile)', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(from, to);

    if (error) {
      throw new InternalServerErrorException('Error loading system financial ledger');
    }

    const total = count || 0;
    const totalPages = Math.ceil(total / limit);

    return {
      data: ledger,
      pagination: {
        page,
        limit,
        total,
        totalPages,
      },
    };
  }
}
