import { Injectable, BadRequestException, UnauthorizedException, InternalServerErrorException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { SupabaseClientService } from '../config/supabase.client';
import { SmsService } from '../sms/sms.service';
import * as bcrypt from 'bcryptjs';
import { RegisterDto, LoginDto, SendOtpDto, VerifyOtpDto, ResetPasswordDto, AdminLoginDto } from './dto/auth.dto';
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
   * Register a new user account.
   * Inserts the user with password hash and automatically creates a wallet row.
   */
  async register(dto: RegisterDto) {
    const supabase = this.supabaseService.getClient();

    // 1. Check if user already exists
    const { data: existingUser } = await supabase
      .from('users')
      .select('id')
      .eq('mobile', dto.mobile)
      .maybeSingle();

    if (existingUser) {
      throw new BadRequestException('Mobile number is already registered');
    }

    // 2. Hash password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(dto.password, salt);

    // 3. Insert user (initially active for standard login, but marked pending_kyc if preferred)
    const { data: newUser, error: createError } = await supabase
      .from('users')
      .insert({
        full_name: dto.fullName,
        mobile: dto.mobile,
        email: dto.email || null,
        password_hash: passwordHash,
        status: 'active', // default active status
        kyc_verified: false,
      })
      .select('id, full_name, mobile, email')
      .single();

    if (createError || !newUser) {
      this.logger.error('Failed to create user:', createError);
      throw new InternalServerErrorException('Error registering user');
    }

    // 4. Automatically create wallet for user
    const { error: walletError } = await supabase
      .from('wallets')
      .insert({
        user_id: newUser.id,
        roi_balance: 0.00,
        principal_balance: 0.00,
        total_roi_earned: 0.00,
      });

    if (walletError) {
      this.logger.error(`Wallet creation failed for user ID ${newUser.id}:`, walletError);
      // Clean up user to avoid orphans
      await supabase.from('users').delete().eq('id', newUser.id);
      throw new InternalServerErrorException('Error initializing user wallet');
    }

    // 5. Generate and dispatch registration OTP
    await this.sendOtp({ mobile: dto.mobile, purpose: 'register' });

    return {
      message: 'Registration initiated successfully. OTP sent for verification.',
      mobile: newUser.mobile,
    };
  }

  /**
   * Sends secure 6-digit numeric OTP to the requested mobile number.
   * Enforces 3 OTP requests per 10 minutes rate limit.
   */
  async sendOtp(dto: SendOtpDto) {
    const supabase = this.supabaseService.getClient();
    const tenMinutesAgo = getISTDateTimeString(new Date(Date.now() - 10 * 60 * 1000));

    // 1. Enforce rate limit (max 3 OTP requests per 10 minutes)
    const { data: recentOtps, error: countError } = await supabase
      .from('otps')
      .select('id')
      .eq('mobile', dto.mobile)
      .eq('used', false)
      .gte('created_at', tenMinutesAgo);

    if (countError) {
      this.logger.error('Error fetching OTP rate counts:', countError);
    }

    if (recentOtps && recentOtps.length >= 3) {
      throw new BadRequestException('Too many OTP requests. Please wait a few minutes before trying again.');
    }

    // 2. Generate 6-digit numeric OTP
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();

    // 3. Hash OTP using bcryptjs
    const salt = await bcrypt.genSalt(10);
    const otpHash = await bcrypt.hash(otpCode, salt);

    // 4. Save hashed OTP to db
    const expiryMinutes = this.configService.get<number>('otpExpiryMinutes') || 5;
    const expiresAt = getISTDateTimeString(new Date(Date.now() + expiryMinutes * 60 * 1000));

    const { error: insertError } = await supabase
      .from('otps')
      .insert({
        mobile: dto.mobile,
        otp_hash: otpHash,
        purpose: dto.purpose,
        expires_at: expiresAt,
        used: false,
      });

    if (insertError) {
      this.logger.error('Failed to save OTP:', insertError);
      throw new InternalServerErrorException('Error processing OTP generation');
    }

    // 5. Send OTP via SMS
    await this.smsService.sendOtp(dto.mobile, otpCode);

    return {
      message: 'OTP dispatched successfully',
      mobile: dto.mobile,
    };
  }

  /**
   * Verifies the provided OTP.
   * If correct, updates used status and issues active JWT session.
   */
  async verifyOtp(dto: VerifyOtpDto) {
    const supabase = this.supabaseService.getClient();

    // 1. Fetch valid, unexpired, unused OTPs for the mobile
    const { data: activeOtps, error: otpError } = await supabase
      .from('otps')
      .select('id, otp_hash, expires_at')
      .eq('mobile', dto.mobile)
      .eq('purpose', dto.purpose)
      .eq('used', false)
      .gt('expires_at', getISTDateTimeString())
      .order('created_at', { ascending: false });

    if (otpError || !activeOtps || activeOtps.length === 0) {
      throw new BadRequestException('Invalid or expired OTP');
    }

    // 2. Validate OTP code
    let matchedOtp = null;
    for (const otpEntry of activeOtps) {
      const isMatch = await bcrypt.compare(dto.otp, otpEntry.otp_hash);
      if (isMatch) {
        matchedOtp = otpEntry;
        break;
      }
    }

    if (!matchedOtp) {
      throw new BadRequestException('Invalid OTP code provided');
    }

    // 3. Mark OTP as used immediately
    await supabase
      .from('otps')
      .update({ used: true })
      .eq('id', matchedOtp.id);

    // 4. Retrieve user to complete login/registration sequence
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('id, full_name, mobile, email, status')
      .eq('mobile', dto.mobile)
      .single();

    if (userError || !user) {
      throw new BadRequestException('User registration record not found');
    }

    if (user.status === 'suspended') {
      throw new UnauthorizedException('User account is suspended');
    }

    // 5. Issue JWT access and refresh tokens
    const tokens = await this.generateTokenPair(user.id, 'USER');

    return {
      message: 'OTP verified successfully',
      user: {
        id: user.id,
        fullName: user.full_name,
        mobile: user.mobile,
        email: user.email,
        status: user.status,
      },
      ...tokens,
    };
  }

  /**
   * Handles user credential validation and triggers a 2FA SMS verification.
   */
  async login(dto: LoginDto) {
    const supabase = this.supabaseService.getClient();

    // 1. Find user
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('id, password_hash, status')
      .eq('mobile', dto.mobile)
      .maybeSingle();

    if (userError || !user) {
      throw new UnauthorizedException('Invalid mobile number or password');
    }

    if (user.status === 'suspended') {
      throw new UnauthorizedException('User account is suspended');
    }

    // 2. Check password
    const isPasswordValid = await bcrypt.compare(dto.password, user.password_hash);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid mobile number or password');
    }

    // 3. Trigger 2FA OTP Send
    await this.sendOtp({ mobile: dto.mobile, purpose: 'login' });

    return {
      message: 'Credentials verified successfully. OTP sent for 2FA verification.',
      mobile: dto.mobile,
    };
  }

  /**
   * Reset user password after verified OTP.
   */
  async resetPassword(dto: ResetPasswordDto) {
    const supabase = this.supabaseService.getClient();

    // 1. Verify OTP first
    await this.verifyOtp({
      mobile: dto.mobile,
      otp: dto.otp,
      purpose: 'forgot_password',
    });

    // 2. Hash new password
    const salt = await bcrypt.genSalt(10);
    const newPasswordHash = await bcrypt.hash(dto.password, salt);

    // 3. Update user password
    const { error: updateError } = await supabase
      .from('users')
      .update({ password_hash: newPasswordHash, updated_at: getISTDateTimeString() })
      .eq('mobile', dto.mobile);

    if (updateError) {
      this.logger.error('Failed to update password:', updateError);
      throw new InternalServerErrorException('Error resetting user password');
    }

    return {
      message: 'Password reset successfully. You can now log in.',
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
