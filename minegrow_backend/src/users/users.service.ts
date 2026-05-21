import {
  Injectable,
  BadRequestException,
  NotFoundException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { SupabaseClientService } from '../config/supabase.client';
import { UploadsService } from '../uploads/uploads.service';
import * as bcrypt from 'bcryptjs';
import {
  UpdateProfileDto,
  AddBankAccountDto,
  RegisterDeviceTokenDto,
} from './dto/users.dto';
import { getISTDateTimeString } from '../common/utils/date.utils';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    private readonly supabaseService: SupabaseClientService,
    private readonly uploadsService: UploadsService,
  ) {}

  async getProfile(userId: number) {
    const supabase = this.supabaseService.getClient();
    const { data: user, error } = await supabase
      .from('users')
      .select(
        'id, full_name, mobile, email, status, kyc_verified, address, created_at',
      )
      .eq('id', userId)
      .single();

    if (error || !user) {
      throw new NotFoundException('User profile not found');
    }
    return user;
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
    const bankName = dto.bankName || dto.bank_name;
    const accountNumber = dto.accountNumber || dto.account_number;
    const ifscCode = dto.ifscCode || dto.ifsc_code;
    const accountHolder = dto.accountHolder || dto.account_holder;
    const upiId = dto.upiId || dto.upi_id;
    const isDefaultInput = dto.isDefault !== undefined ? dto.isDefault : dto.is_default;

    if (!accountType || !['bank', 'upi'].includes(accountType)) {
      throw new BadRequestException('Account type must be "bank" or "upi"');
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
}
