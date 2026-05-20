import {
  Injectable,
  BadRequestException,
  NotFoundException,
  InternalServerErrorException,
  Logger,
  ForbiddenException,
} from '@nestjs/common';
import { SupabaseClientService } from '../config/supabase.client';
import { AuditService } from '../audit/audit.service';
import {
  CreateWithdrawalDto,
  RejectWithdrawalDto,
} from './dto/withdrawals.dto';
import {
  getISTDateString,
  getISTDateTimeString,
} from '../common/utils/date.utils';

@Injectable()
export class WithdrawalsService {
  private readonly logger = new Logger(WithdrawalsService.name);

  constructor(
    private readonly supabaseService: SupabaseClientService,
    private readonly auditService: AuditService,
  ) {}

  /**
   * Evaluates if a user is currently eligible for ROI and Principal withdrawals.
   */
  async getEligibility(userId: number) {
    const supabase = this.supabaseService.getClient();

    // 1. Validate user status
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('status')
      .eq('id', userId)
      .single();

    if (userError || !user) {
      throw new NotFoundException('User profile not found');
    }

    if (user.status !== 'active') {
      return {
        roi: {
          eligible: false,
          message: 'Account is suspended or pending KYC',
          balance: 0,
        },
        principal: {
          eligible: false,
          message: 'Account is suspended or pending KYC',
          balance: 0,
        },
      };
    }

    // 2. Fetch wallets
    const { data: wallet, error: walletError } = await supabase
      .from('wallets')
      .select('roi_balance, principal_balance, last_roi_withdrawal_at')
      .eq('user_id', userId)
      .single();

    if (walletError || !wallet) {
      throw new InternalServerErrorException(
        'Error loading wallet configurations',
      );
    }

    // 3. Evaluate ROI eligibility (30-day lock check, balance >= 100)
    let roiEligible = true;
    let roiMessage = 'Eligible for withdrawal';

    if (Number(wallet.roi_balance) < 100) {
      roiEligible = false;
      roiMessage = 'Minimum withdrawal amount is ₹100';
    } else if (wallet.last_roi_withdrawal_at) {
      const lastWithdrawal = new Date(wallet.last_roi_withdrawal_at);
      const nextWithdrawalDate = new Date(
        lastWithdrawal.getTime() + 30 * 24 * 60 * 60 * 1000,
      );
      const now = new Date();
      if (now < nextWithdrawalDate) {
        roiEligible = false;
        roiMessage = `Withdrawals are locked. Next eligible date: ${getISTDateString(nextWithdrawalDate)}`;
      }
    }

    // 4. Evaluate Principal eligibility (balance > 0)
    let principalEligible = true;
    let principalMessage = 'Eligible for withdrawal';

    if (Number(wallet.principal_balance) <= 0) {
      principalEligible = false;
      principalMessage =
        'No matured principal balances available for withdrawal';
    }

    return {
      roi: {
        eligible: roiEligible,
        message: roiMessage,
        balance: Number(wallet.roi_balance),
      },
      principal: {
        eligible: principalEligible,
        message: principalMessage,
        balance: Number(wallet.principal_balance),
      },
    };
  }

  /**
   * Submit an ROI withdrawal request.
   */
  async requestRoiWithdrawal(userId: number, dto: CreateWithdrawalDto) {
    const supabase = this.supabaseService.getClient();

    // 1. Revalidate eligibility
    const eligibility = await this.getEligibility(userId);
    if (!eligibility.roi.eligible) {
      throw new BadRequestException(
        `Ineligible for ROI withdrawal: ${eligibility.roi.message}`,
      );
    }

    if (dto.amount > eligibility.roi.balance) {
      throw new BadRequestException('Requested amount exceeds ROI balance');
    }

    // 2. Validate bank account coordinates
    const bankDetails = await this.resolveBankDetails(userId, dto);

    // 3. Insert withdrawal request
    const { data: request, error: insertError } = await supabase
      .from('withdrawals')
      .insert({
        user_id: userId,
        withdrawal_type: 'roi',
        amount: dto.amount,
        bank_account_id: bankDetails.bankAccountId || null,
        bank_name: bankDetails.bankName || null,
        account_number: bankDetails.accountNumber || null,
        ifsc_code: bankDetails.ifscCode || null,
        upi_id: bankDetails.upiId || null,
        status: 'requested',
      })
      .select('*')
      .single();

    if (insertError || !request) {
      this.logger.error('Failed to submit ROI withdrawal:', insertError);
      throw new InternalServerErrorException(
        'Error submitting withdrawal request',
      );
    }

    return request;
  }

  /**
   * Submit a Principal withdrawal request.
   */
  async requestPrincipalWithdrawal(userId: number, dto: CreateWithdrawalDto) {
    const supabase = this.supabaseService.getClient();

    // 1. Revalidate eligibility
    const eligibility = await this.getEligibility(userId);
    if (!eligibility.principal.eligible) {
      throw new BadRequestException(
        `Ineligible for principal withdrawal: ${eligibility.principal.message}`,
      );
    }

    if (dto.amount > eligibility.principal.balance) {
      throw new BadRequestException(
        'Requested amount exceeds matured principal balance',
      );
    }

    // 2. Validate bank account coordinates
    const bankDetails = await this.resolveBankDetails(userId, dto);

    // 3. Insert withdrawal request
    const { data: request, error: insertError } = await supabase
      .from('withdrawals')
      .insert({
        user_id: userId,
        withdrawal_type: 'principal',
        amount: dto.amount,
        bank_account_id: bankDetails.bankAccountId || null,
        bank_name: bankDetails.bankName || null,
        account_number: bankDetails.accountNumber || null,
        ifsc_code: bankDetails.ifscCode || null,
        upi_id: bankDetails.upiId || null,
        status: 'requested',
      })
      .select('*')
      .single();

    if (insertError || !request) {
      this.logger.error('Failed to submit principal withdrawal:', insertError);
      throw new InternalServerErrorException(
        'Error submitting withdrawal request',
      );
    }

    return request;
  }

  async getOwnWithdrawals(userId: number) {
    const supabase = this.supabaseService.getClient();
    const { data: withdrawals, error } = await supabase
      .from('withdrawals')
      .select('*')
      .eq('user_id', userId)
      .order('requested_at', { ascending: false });

    if (error) {
      throw new InternalServerErrorException(
        'Error retrieving withdrawal requests',
      );
    }

    return withdrawals;
  }

  async getAllWithdrawals(filters: {
    status?: string;
    type?: string;
    userId?: number;
  }) {
    const supabase = this.supabaseService.getClient();
    let query = supabase
      .from('withdrawals')
      .select('*, users(full_name, mobile)');

    if (filters.status) {
      query = query.eq('status', filters.status);
    }
    if (filters.type) {
      query = query.eq('withdrawal_type', filters.type);
    }
    if (filters.userId) {
      query = query.eq('user_id', filters.userId);
    }

    const { data: withdrawals, error } = await query.order('requested_at', {
      ascending: false,
    });

    if (error) {
      this.logger.error('Error fetching admin withdrawals:', error);
      throw new InternalServerErrorException(
        'Error loading withdrawals database',
      );
    }

    return withdrawals;
  }

  async getPendingWithdrawals() {
    const supabase = this.supabaseService.getClient();
    const { data: withdrawals, error } = await supabase
      .from('withdrawals')
      .select('*, users(full_name, mobile)')
      .eq('status', 'requested')
      .order('requested_at', { ascending: false });

    if (error) {
      throw new InternalServerErrorException('Error loading pending queue');
    }

    return withdrawals;
  }

  /**
   * Approves a withdrawal request.
   * Executes atomic PG RPC function to lock rows, verify balances, deduct wallet, and write ledgers.
   */
  async approveWithdrawal(adminId: number, id: number, ipAddress?: string) {
    const supabase = this.supabaseService.getClient();

    // Execute atomic Supabase RPC function (approve_withdrawal)
    const { error } = await supabase.rpc('approve_withdrawal', {
      p_withdrawal_id: id,
      p_admin_id: adminId,
    });

    if (error) {
      this.logger.error(`Failed to approve withdrawal ID ${id}:`, error);
      throw new BadRequestException(
        error.message || 'Error processing atomic withdrawal approval',
      );
    }

    // Fetch the updated withdrawal details for returning
    const { data: updated } = await supabase
      .from('withdrawals')
      .select('*')
      .eq('id', id)
      .single();

    return updated;
  }

  /**
   * Rejects a withdrawal request. No wallet balance is deducted.
   */
  async rejectWithdrawal(
    adminId: number,
    id: number,
    dto: RejectWithdrawalDto,
    ipAddress?: string,
  ) {
    const supabase = this.supabaseService.getClient();

    // 1. Fetch withdrawal
    const { data: withdrawal, error } = await supabase
      .from('withdrawals')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !withdrawal) {
      throw new NotFoundException('Withdrawal request not found');
    }

    if (withdrawal.status !== 'requested') {
      throw new BadRequestException(
        `Withdrawal is already processed (Status: ${withdrawal.status})`,
      );
    }

    // 2. Reject request
    const { data: rejected, error: updateError } = await supabase
      .from('withdrawals')
      .update({
        status: 'rejected',
        admin_note: dto.adminNote,
        processed_by: adminId,
        processed_at: getISTDateTimeString(),
      })
      .eq('id', id)
      .select('*')
      .single();

    if (updateError || !rejected) {
      this.logger.error('Failed to reject withdrawal:', updateError);
      throw new InternalServerErrorException(
        'Error rejecting withdrawal request',
      );
    }

    // 3. Write audit log
    await this.auditService.log(
      'admin',
      adminId,
      'REJECT_WITHDRAWAL',
      rejected.user_id,
      rejected.id,
      {
        amount: rejected.amount,
        type: rejected.withdrawal_type,
        reason: dto.adminNote,
      },
      ipAddress,
    );

    return rejected;
  }

  /**
   * Marks withdrawal payout as completed/physically sent.
   */
  async completeWithdrawal(adminId: number, id: number, ipAddress?: string) {
    const supabase = this.supabaseService.getClient();

    // 1. Fetch withdrawal
    const { data: withdrawal, error } = await supabase
      .from('withdrawals')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !withdrawal) {
      throw new NotFoundException('Withdrawal record not found');
    }

    if (withdrawal.status !== 'approved') {
      throw new BadRequestException(
        `Payout can only be marked complete after approval (Status: ${withdrawal.status})`,
      );
    }

    // 2. Set to completed
    const { data: completed, error: updateError } = await supabase
      .from('withdrawals')
      .update({
        status: 'completed',
        completed_at: getISTDateTimeString(),
      })
      .eq('id', id)
      .select('*')
      .single();

    if (updateError || !completed) {
      this.logger.error('Failed to mark withdrawal complete:', updateError);
      throw new InternalServerErrorException('Error completing payout record');
    }

    // 3. Write audit log
    await this.auditService.log(
      'admin',
      adminId,
      'COMPLETE_WITHDRAWAL',
      completed.user_id,
      completed.id,
      { amount: completed.amount, type: completed.withdrawal_type },
      ipAddress,
    );

    return completed;
  }

  /**
   * Resolves whether user is using a saved bank account or entered inline details.
   */
  private async resolveBankDetails(userId: number, dto: CreateWithdrawalDto) {
    const supabase = this.supabaseService.getClient();

    if (dto.bankAccountId) {
      const { data: account, error } = await supabase
        .from('bank_accounts')
        .select('*')
        .eq('id', dto.bankAccountId)
        .eq('user_id', userId)
        .maybeSingle();

      if (error || !account) {
        throw new BadRequestException(
          'Selected bank account is invalid or not owned by user',
        );
      }

      return {
        bankAccountId: account.id,
        bankName: account.bank_name,
        accountNumber: account.account_number,
        ifscCode: account.ifsc_code,
        upiId: account.upi_id,
      };
    }

    // Validate inline coordinates
    const hasBank = dto.bankName && dto.accountNumber && dto.ifscCode;
    const hasUpi = dto.upiId;

    if (!hasBank && !hasUpi) {
      throw new BadRequestException(
        'Please select a saved account or enter bank/UPI details inline',
      );
    }

    return {
      bankAccountId: null,
      bankName: dto.bankName || null,
      accountNumber: dto.accountNumber || null,
      ifscCode: dto.ifscCode || null,
      upiId: dto.upiId || null,
    };
  }
}
