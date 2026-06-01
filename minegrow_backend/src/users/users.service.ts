import {
  Injectable,
  BadRequestException,
  NotFoundException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { SupabaseClientService } from '../config/supabase.client';
import { UploadsService } from '../uploads/uploads.service';
import { AuditService } from '../audit/audit.service';
import {
  UpdateProfileDto,
  AddBankAccountDto,
  RegisterDeviceTokenDto,
  UpdateNotificationPreferencesDto,
} from './dto/users.dto';
import { getISTDateTimeString } from '../common/utils/date.utils';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    private readonly supabaseService: SupabaseClientService,
    private readonly uploadsService: UploadsService,
    private readonly auditService: AuditService,
  ) {}

  async getProfile(userId: number) {
    const supabase = this.supabaseService.getClient();
    const { data: user, error } = await supabase
      .from('users')
      .select(
        'id, full_name, mobile, email, status, kyc_verified, address, notification_preferences, created_at',
      )
      .eq('id', userId)
      .single();

    if (error || !user) {
      throw new NotFoundException('User profile not found');
    }

    // Default values fallback
    const defaultPrefs = { push: true, investments: true, wallet: true, promotions: false };
    user.notification_preferences = {
      ...defaultPrefs,
      ...(user.notification_preferences || {}),
    };

    return user;
  }

  async updateNotificationPreferences(userId: number, dto: UpdateNotificationPreferencesDto) {
    const supabase = this.supabaseService.getClient();

    // 1. Fetch current profile
    const profile = await this.getProfile(userId);
    const currentPrefs = profile.notification_preferences || {
      push: true,
      investments: true,
      wallet: true,
      promotions: false,
    };

    // 2. Merge changes
    const updatedPrefs = {
      ...currentPrefs,
      ...dto,
    };

    // 3. Save to database
    const { data, error } = await supabase
      .from('users')
      .update({
        notification_preferences: updatedPrefs,
        updated_at: getISTDateTimeString(),
      })
      .eq('id', userId)
      .select('id, notification_preferences')
      .single();

    if (error || !data) {
      this.logger.error('Failed to update notification preferences:', error);
      throw new InternalServerErrorException('Error saving notification preferences');
    }

    return data;
  }

  async updateProfile(userId: number, dto: UpdateProfileDto) {
    const supabase = this.supabaseService.getClient();
    const updateData: any = {};

    if (dto.fullName) updateData.full_name = dto.fullName;
    if (dto.email) updateData.email = dto.email;
    if (dto.address) updateData.address = dto.address;

    if (Object.keys(updateData).length === 0) {
      throw new BadRequestException('No fields to update');
    }

    updateData.updated_at = getISTDateTimeString();

    const { data: user, error } = await supabase
      .from('users')
      .update(updateData)
      .eq('id', userId)
      .select(
        'id, full_name, mobile, email, status, kyc_verified, address, updated_at',
      )
      .single();

    if (error || !user) {
      this.logger.error('Failed to update profile:', error);
      throw new InternalServerErrorException('Error updating user profile');
    }

    return user;
  }

  async uploadKyc(
    userId: number,
    file: any,
    docType: 'aadhaar' | 'pan' | 'passport' | 'driving_license',
  ) {
    // 1. Upload to storage
    const storagePath = await this.uploadsService.uploadFile(
      userId,
      'kyc-documents',
      file,
      docType,
    );

    const supabase = this.supabaseService.getClient();

    // 2. Insert record in kyc_documents table
    const { data: doc, error } = await supabase
      .from('kyc_documents')
      .insert({
        user_id: userId,
        doc_type: docType,
        doc_url: storagePath,
        status: 'pending',
      })
      .select('id, doc_type, status, uploaded_at')
      .single();

    if (error || !doc) {
      this.logger.error('Failed to save KYC record:', error);
      throw new InternalServerErrorException(
        'Error creating KYC transaction record',
      );
    }

    // 3. Optional: update user status to pending_kyc
    await supabase
      .from('users')
      .update({ status: 'pending_kyc' })
      .eq('id', userId)
      .eq('status', 'active'); // only toggle from active status

    return {
      message: 'KYC document uploaded successfully. Verification is pending.',
      document: doc,
    };
  }

  async getKycStatus(userId: number) {
    const supabase = this.supabaseService.getClient();
    const { data: docs, error } = await supabase
      .from('kyc_documents')
      .select('id, doc_type, status, uploaded_at, reviewed_at')
      .eq('user_id', userId)
      .order('uploaded_at', { ascending: false });

    if (error) {
      throw new InternalServerErrorException('Error retrieving KYC details');
    }

    return docs;
  }

  async getBankAccounts(userId: number) {
    const supabase = this.supabaseService.getClient();
    const { data: accounts, error } = await supabase
      .from('bank_accounts')
      .select('*')
      .eq('user_id', userId)
      .order('is_default', { ascending: false })
      .order('created_at', { ascending: false });

    if (error) {
      throw new InternalServerErrorException('Error retrieving bank accounts');
    }

    return accounts;
  }

  async addBankAccount(userId: number, dto: AddBankAccountDto) {
    const supabase = this.supabaseService.getClient();

    const accountType = dto.accountType || dto.account_type;
    const bankName = (dto.bankName || dto.bank_name)?.trim();
    const accountNumber = (dto.accountNumber || dto.account_number)?.trim();
    const ifscCode = (dto.ifscCode || dto.ifsc_code)?.trim().toUpperCase();
    const accountHolder = (dto.accountHolder || dto.account_holder)?.trim();
    const upiId = (dto.upiId || dto.upi_id)?.trim();
    const isDefaultInput = dto.isDefault !== undefined ? dto.isDefault : dto.is_default;

    if (!accountType || !['bank', 'upi'].includes(accountType)) {
      throw new BadRequestException('Account type must be "bank" or "upi"');
    }

    if (
      accountType === 'bank' &&
      (!bankName || !accountNumber || !ifscCode || !accountHolder)
    ) {
      throw new BadRequestException(
        'Bank accounts require bank name, account number, IFSC code, and account holder name',
      );
    }

    if (accountType === 'upi' && !upiId) {
      throw new BadRequestException('UPI accounts require a UPI ID');
    }

    // 1. If this is the first account, force it to be default
    const { data: existingAccounts } = await supabase
      .from('bank_accounts')
      .select('id')
      .eq('user_id', userId);

    const isFirstAccount = !existingAccounts || existingAccounts.length === 0;
    const makeDefault = isFirstAccount || isDefaultInput === true;

    // 2. If default, reset other accounts first
    if (makeDefault) {
      await supabase
        .from('bank_accounts')
        .update({ is_default: false })
        .eq('user_id', userId);
    }

    // 3. Insert new account
    const { data: newAccount, error } = await supabase
      .from('bank_accounts')
      .insert({
        user_id: userId,
        account_type: accountType,
        bank_name: bankName || null,
        account_number: accountNumber || null,
        ifsc_code: ifscCode || null,
        account_holder: accountHolder || null,
        upi_id: upiId || null,
        is_default: makeDefault,
      })
      .select('*')
      .single();

    if (error || !newAccount) {
      this.logger.error('Failed to add bank account:', error);
      throw new BadRequestException(
        'Error adding bank account. Validate fields.',
      );
    }

    return newAccount;
  }

  async deleteBankAccount(userId: number, accountId: number) {
    const supabase = this.supabaseService.getClient();

    // Verify ownership
    const { data: existing } = await supabase
      .from('bank_accounts')
      .select('is_default')
      .eq('id', accountId)
      .eq('user_id', userId)
      .maybeSingle();

    if (!existing) {
      throw new NotFoundException('Bank account not found or access denied');
    }

    // Delete account
    const { error } = await supabase
      .from('bank_accounts')
      .delete()
      .eq('id', accountId);

    if (error) {
      throw new InternalServerErrorException('Error deleting bank account');
    }

    // If we deleted the default account, set the most recent account as default
    if (existing.is_default) {
      const { data: nextAccount } = await supabase
        .from('bank_accounts')
        .select('id')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (nextAccount) {
        await supabase
          .from('bank_accounts')
          .update({ is_default: true })
          .eq('id', nextAccount.id);
      }
    }

    return { message: 'Bank account deleted successfully' };
  }

  async setDefaultBankAccount(userId: number, accountId: number) {
    const supabase = this.supabaseService.getClient();

    // Verify ownership
    const { data: existing } = await supabase
      .from('bank_accounts')
      .select('id')
      .eq('id', accountId)
      .eq('user_id', userId)
      .maybeSingle();

    if (!existing) {
      throw new NotFoundException('Bank account not found or access denied');
    }

    // Reset default status on all other accounts
    await supabase
      .from('bank_accounts')
      .update({ is_default: false })
      .eq('user_id', userId);

    // Set default on this account
    const { data: updated, error } = await supabase
      .from('bank_accounts')
      .update({ is_default: true })
      .eq('id', accountId)
      .select('*')
      .single();

    if (error) {
      throw new InternalServerErrorException('Error setting default account');
    }

    return updated;
  }

  async registerDeviceToken(userId: number, dto: RegisterDeviceTokenDto) {
    const supabase = this.supabaseService.getClient();

    // Upsert token in device_tokens table
    const { data: existing } = await supabase
      .from('device_tokens')
      .select('id')
      .eq('user_id', userId)
      .eq('fcm_token', dto.fcmToken)
      .maybeSingle();

    if (existing) {
      // Just update timestamp
      await supabase
        .from('device_tokens')
        .update({ updated_at: getISTDateTimeString() })
        .eq('id', existing.id);
      return { message: 'Device token refreshed successfully' };
    }

    // Insert new
    const { error } = await supabase.from('device_tokens').insert({
      user_id: userId,
      fcm_token: dto.fcmToken,
      platform: dto.platform,
    });

    if (error) {
      this.logger.error('Failed to save device token:', error);
      throw new InternalServerErrorException('Error registering device token');
    }

    return { message: 'Device token registered successfully' };
  }

  /**
   * Permanently closes a user's account (App Store / Google Play requirement).
   *
   * Implemented as a soft delete so financial records (investments,
   * withdrawals, wallet ledger, ROI history, audit logs) are retained for
   * compliance, while the account is rendered unusable and personal data is
   * scrubbed. Blocked while the user still has funds or in-flight activity to
   * avoid orphaning money.
   */
  async deleteAccount(userId: number) {
    const supabase = this.supabaseService.getClient();

    // 1. Load the account and ensure it isn't already deleted.
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('id, status, token_version')
      .eq('id', userId)
      .maybeSingle();

    if (userError || !user || user.status === 'deleted') {
      throw new NotFoundException('User account not found');
    }

    // 2. Block deletion while funds remain in the wallet.
    const { data: wallet } = await supabase
      .from('wallets')
      .select('roi_balance, principal_balance')
      .eq('user_id', userId)
      .maybeSingle();

    const balance =
      Number(wallet?.roi_balance ?? 0) + Number(wallet?.principal_balance ?? 0);
    if (balance > 0) {
      throw new BadRequestException(
        'Withdraw your remaining wallet balance before deleting your account.',
      );
    }

    // 3. Block deletion while investments are pending or active.
    const { count: openInvestments } = await supabase
      .from('investments')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .in('status', ['pending', 'approved', 'active']);

    if ((openInvestments ?? 0) > 0) {
      throw new BadRequestException(
        'You have active or pending investments. They must complete or be resolved before your account can be deleted.',
      );
    }

    // 4. Block deletion while a withdrawal is in flight.
    const { count: openWithdrawals } = await supabase
      .from('withdrawals')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .in('status', ['requested', 'approved']);

    if ((openWithdrawals ?? 0) > 0) {
      throw new BadRequestException(
        'You have a withdrawal in progress. Wait for it to complete before deleting your account.',
      );
    }

    // 5. Anonymize the profile, revoke all sessions (token_version bump), and
    //    free the mobile/email so the user can register again later.
    const { error: updateError } = await supabase
      .from('users')
      .update({
        status: 'deleted',
        full_name: 'Deleted User',
        email: null,
        address: null,
        mobile: `deleted_${userId}`,
        token_version: (user.token_version ?? 1) + 1,
        deleted_at: getISTDateTimeString(),
        updated_at: getISTDateTimeString(),
      })
      .eq('id', userId);

    if (updateError) {
      this.logger.error('Failed to soft-delete user account:', updateError);
      throw new InternalServerErrorException('Error deleting account');
    }

    // 6. Remove auxiliary records holding PII / push targets (best effort).
    await supabase.from('device_tokens').delete().eq('user_id', userId);
    await supabase.from('bank_accounts').delete().eq('user_id', userId);

    // 7. Compliance audit trail (append-only).
    await this.auditService.log(
      'user',
      userId,
      'account_deleted',
      userId,
      null,
      { soft_delete: true },
    );

    return { message: 'Your account has been deleted.' };
  }
}
