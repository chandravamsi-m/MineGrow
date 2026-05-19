import { Injectable, BadRequestException, UnauthorizedException, InternalServerErrorException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { SupabaseClientService } from '../config/supabase.client';
import { SmsService } from '../sms/sms.service';
import * as bcrypt from 'bcryptjs';
import { SendOtpDto, VerifyOtpDto, AdminLoginDto, OnboardStep1Dto } from './dto/auth.dto';
import { getISTDateTimeString } from '../common/utils/date.utils';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly supabaseService: SupabaseClientService,
    private readonly smsService: SmsService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  /**
   * Sends secure SMS OTP to the requested mobile number using Supabase Auth.
   * Supabase automatically routes it through the Twilio gateway.
   */
  async sendOtp(dto: SendOtpDto) {
    const supabase = this.supabaseService.getClient();

    // Check if user exists in the custom users table
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('mobile', dto.mobile)
      .maybeSingle();

    const isExistingUser = !!user;

    // Trigger Supabase OTP send
    const { error } = await supabase.auth.signInWithOtp({
      phone: dto.mobile,
    });

    if (error) {
      this.logger.error(`Supabase signInWithOtp failed for ${dto.mobile}:`, error);
      throw new InternalServerErrorException(`Failed to dispatch OTP: ${error.message}`);
    }

    return {
      message: 'OTP dispatched successfully via Supabase',
      mobile: dto.mobile,
      isExistingUser,
    };
  }

  /**
   * Verifies the provided OTP using Supabase Auth.
   * On success, issues active NestJS JWT session.
   */
  async verifyOtp(dto: VerifyOtpDto) {
    const supabase = this.supabaseService.getClient();

    // 1. Verify OTP via Supabase
    const { data: authData, error: authError } = await supabase.auth.verifyOtp({
      phone: dto.mobile,
      token: dto.otp,
      type: 'sms',
    });

    if (authError || !authData) {
      this.logger.error(`Supabase verifyOtp failed for ${dto.mobile}:`, authError);
      throw new BadRequestException(authError?.message || 'Invalid or expired OTP');
    }

    // 2. Retrieve user to complete login/registration sequence
    let { data: user, error: userError } = await supabase
      .from('users')
      .select('id, full_name, mobile, email, status, address')
      .eq('mobile', dto.mobile)
      .maybeSingle();

    let isNewUser = false;

    // 3. Fallback Auto-Registration if user authenticated via Supabase but profile missing
    if (!user) {
      isNewUser = true;
      const { data: newUser, error: createError } = await supabase
        .from('users')
        .insert({
          full_name: 'New User',
          mobile: dto.mobile,
          status: 'active',
          kyc_verified: false,
        })
        .select('id, full_name, mobile, email, status, address')
        .single();

      if (createError || !newUser) {
        this.logger.error('Failed to auto-register user on verification:', createError);
        throw new InternalServerErrorException('Error registering user profile');
      }

      // Initialize wallet
      const { error: walletError } = await supabase
        .from('wallets')
        .insert({
          user_id: newUser.id,
          roi_balance: 0.00,
          principal_balance: 0.00,
          total_roi_earned: 0.00,
        });

      if (walletError) {
        this.logger.error(`Auto-wallet creation failed for user ID ${newUser.id}:`, walletError);
      }

      user = newUser;
    } else {
      // If user exists but full_name is default placeholder or address is empty/null, they are still considered new (mandatory step 1 onboarding is pending!)
      if (user.full_name === 'New User' || !user.address) {
        isNewUser = true;
      }
    }

    if (user.status === 'suspended') {
      throw new UnauthorizedException('User account is suspended');
    }

    // 4. Issue custom NestJS JWT access and refresh tokens
    const tokens = await this.generateTokenPair(user.id, 'USER');

    return {
      message: 'OTP verified successfully',
      isNewUser,
      user: {
        id: user.id,
        fullName: user.full_name,
        mobile: user.mobile,
        email: user.email,
        address: user.address,
        status: user.status,
      },
      ...tokens,
    };
  }

  /**
   * Completes mandatory Step 1 onboarding profile details.
   */
  async onboardStep1(userId: number, dto: OnboardStep1Dto) {
    const supabase = this.supabaseService.getClient();

    const { data: user, error } = await supabase
      .from('users')
      .update({
        full_name: dto.fullName,
        email: dto.email,
        address: dto.address,
        updated_at: getISTDateTimeString(),
      })
      .eq('id', userId)
      .select('id, full_name, mobile, email, address, status, kyc_verified')
      .single();

    if (error || !user) {
      this.logger.error(`Failed to update onboarding step 1 for user ID ${userId}:`, error);
      throw new InternalServerErrorException('Error completing profile onboarding details');
    }

    return {
      message: 'Mandatory profile onboarding Step 1 completed successfully',
      user,
    };
  }

  /**
   * Handles admin email/password login. Returns token immediately with roleclaim.
   */
  async adminLogin(dto: AdminLoginDto) {
    const supabase = this.supabaseService.getClient();

    // 1. Find admin account
    const { data: admin, error: adminError } = await supabase
      .from('admins')
      .select('id, full_name, email, password_hash, status, is_super')
      .eq('email', dto.email)
      .maybeSingle();

    if (adminError || !admin) {
      throw new UnauthorizedException('Invalid admin credentials');
    }

    if (admin.status !== 'active') {
      throw new UnauthorizedException('Admin account is suspended or inactive');
    }

    // 2. Verify password
    const isPasswordValid = await bcrypt.compare(dto.password, admin.password_hash);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid admin credentials');
    }

    // 3. Issue tokens directly for admin (no 2FA OTP needed based on spec)
    const tokens = await this.generateTokenPair(admin.id, 'ADMIN');

    return {
      message: 'Admin login successful',
      admin: {
        id: admin.id,
        fullName: admin.full_name,
        email: admin.email,
        isSuper: admin.is_super,
      },
      ...tokens,
    };
  }

  /**
   * Exchange active refresh token for a brand new token pair (Token Rotation).
   */
  async refresh(refreshToken: string) {
    try {
      const payload = this.jwtService.verify(refreshToken);
      if (payload.type !== 'refresh') {
        throw new UnauthorizedException('Invalid token type');
      }

      // Generate a new rotated token pair
      const tokens = await this.generateTokenPair(payload.sub, payload.role);
      
      return {
        message: 'Tokens refreshed successfully',
        ...tokens,
      };
    } catch (e) {
      throw new UnauthorizedException('Session expired. Please log in again.');
    }
  }

  /**
   * Bootstraps / seeds the very first super-admin in the DB using the ADMIN_SEED_SECRET.
   */
  async seedAdmin(dto: AdminLoginDto, secret: string) {
    const bootstrapSecret = this.configService.get<string>('adminSeedSecret');
    if (secret !== bootstrapSecret) {
      throw new UnauthorizedException('Invalid administrative seeding secret key');
    }

    const supabase = this.supabaseService.getClient();

    // Check if any admin exists
    const { data: existingAdmin } = await supabase
      .from('admins')
      .select('id')
      .eq('email', dto.email)
      .maybeSingle();

    if (existingAdmin) {
      throw new BadRequestException('Admin account with this email already exists');
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(dto.password, salt);

    // Create super admin
    const { data: newAdmin, error } = await supabase
      .from('admins')
      .insert({
        full_name: 'System Super Admin',
        email: dto.email,
        password_hash: passwordHash,
        is_super: true,
        status: 'active',
      })
      .select('id, full_name, email')
      .single();

    if (error || !newAdmin) {
      this.logger.error('Failed to seed super admin:', error);
      throw new InternalServerErrorException('Error seeding super admin account');
    }

    return {
      message: 'Super Admin seeded successfully',
      admin: newAdmin,
    };
  }

  /**
   * Helper function to generate an access and refresh JWT token pair.
   */
  private async generateTokenPair(userId: number, role: 'USER' | 'ADMIN') {
    const jwtSecret = this.configService.get<string>('jwt.secret');

    const accessPayload = { sub: userId, role };
    const refreshPayload = { sub: userId, role, type: 'refresh' };

    const accessToken = this.jwtService.sign(accessPayload, {
      secret: jwtSecret,
      expiresIn: (this.configService.get<string>('jwt.expiresIn') || '15m') as any,
    });

    const refreshToken = this.jwtService.sign(refreshPayload, {
      secret: jwtSecret,
      expiresIn: (this.configService.get<string>('jwt.refreshExpiresIn') || '7d') as any,
    });

    return {
      accessToken,
      refreshToken,
    };
  }
}
