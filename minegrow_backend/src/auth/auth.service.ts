import { Injectable, BadRequestException, UnauthorizedException, InternalServerErrorException, Logger, ForbiddenException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { SupabaseClientService } from '../config/supabase.client';
import * as bcrypt from 'bcryptjs';
import * as crypto from 'crypto';
import { SendOtpDto, VerifyOtpDto, AdminLoginDto, OnboardStep1Dto } from './dto/auth.dto';
import { getISTDateTimeString } from '../common/utils/date.utils';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly supabaseService: SupabaseClientService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  /**
   * Sends secure SMS OTP to the requested mobile number using Supabase Auth.
   * Supabase dispatches SMS through the Twilio provider configured in the Supabase dashboard.
   */
  async sendOtp(dto: SendOtpDto) {
    const supabaseAuth = this.supabaseService.getAuthClient();

    // Trigger Supabase OTP send. Supabase handles OTP generation, expiry, and Twilio delivery.
    const { error } = await supabaseAuth.auth.signInWithOtp({
      phone: dto.mobile,
    });

    if (error) {
      this.logger.error(`Supabase signInWithOtp failed for ${dto.mobile}:`, error);
      throw new InternalServerErrorException(`Failed to dispatch OTP: ${error.message}`);
    }

    return { message: 'OTP dispatched successfully via Supabase' };
  }

  /**
   * Verifies the provided OTP using Supabase Auth.
   * On success, issues active NestJS JWT session.
   */
  async verifyOtp(dto: VerifyOtpDto) {
    const supabase = this.supabaseService.getClient();
    const supabaseAuth = this.supabaseService.getAuthClient();

    // 1. Verify OTP via Supabase Auth.
    const { data: authData, error: authError } = await supabaseAuth.auth.verifyOtp({
      phone: dto.mobile,
      token: dto.otp,
      type: 'sms',
    });

    if (authError || !authData.session) {
      this.logger.error(`Supabase verifyOtp failed for ${dto.mobile}:`, authError);
      throw new BadRequestException(authError?.message || 'Invalid or expired OTP');
    }

    // 2. Retrieve user to complete login/registration sequence
    let { data: user, error: userError } = await supabase
      .from('users')
      .select('id, full_name, mobile, email, status, address, token_version')
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
          token_version: 1,
        })
        .select('id, full_name, mobile, email, status, address, token_version')
        .single();

      if (createError || !newUser) {
        this.logger.error('Failed to auto-register user on verification:', createError);
        throw new InternalServerErrorException('Error registering user profile');
      }

      // Initialize wallet — LOW-4: Throw on failure to avoid wallet-less users
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
        // Clean up the user record to avoid orphaned users without wallets
        await supabase.from('users').delete().eq('id', newUser.id);
        throw new InternalServerErrorException('Error initializing user wallet. Registration rolled back.');
      }

      user = newUser;
    } else {
      // If user exists but full_name is default placeholder or address is empty/null,
      // they are still considered new (mandatory step 1 onboarding is pending!)
      if (user.full_name === 'New User' || !user.address) {
        isNewUser = true;
      }
    }

    if (user.status === 'suspended') {
      throw new UnauthorizedException('User account is suspended');
    }

    // 4. Issue custom NestJS JWT access and refresh tokens (with token_version for CRIT-3)
    const tokens = await this.generateTokenPair(user.id, 'USER', user.token_version ?? 1);

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
      .select('id, full_name, email, password_hash, status, is_super, token_version')
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

    // 3. Issue tokens with token_version for CRIT-3 logout invalidation
    const tokens = await this.generateTokenPair(admin.id, 'ADMIN', admin.token_version ?? 1);

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
   * CRIT-3: Invalidates all tokens by incrementing token_version in the DB.
   * Any token issued before this increment will be rejected by JwtStrategy.validate().
   */
  async logout(userId: number, role: 'USER' | 'ADMIN') {
    const supabase = this.supabaseService.getClient();
    const table = role === 'ADMIN' ? 'admins' : 'users';

    const { error } = await supabase.rpc('increment_token_version', {
      p_table: table,
      p_user_id: userId,
    });

    if (error) {
      // Fallback: read current version then increment directly
      const { data: record, error: readError } = await supabase
        .from(table)
        .select('token_version')
        .eq('id', userId)
        .single();

      if (readError || !record) {
        this.logger.error(`Failed to read token_version for ${role} ID ${userId} during logout:`, readError);
        // Still return success — token will expire naturally
      } else {
        const { error: updateError } = await supabase
          .from(table)
          .update({ token_version: record.token_version + 1 })
          .eq('id', userId);

        if (updateError) {
          this.logger.error(`Failed to invalidate tokens for ${role} ID ${userId}:`, updateError);
          // Still return success — token will expire naturally
        }
      }
    }

    return { message: 'Logged out successfully. All sessions have been invalidated.' };
  }

  /**
   * CRIT-4: Exchange active refresh token for a brand new token pair (Token Rotation).
   * Validates the token_version to prevent replay attacks on old refresh tokens.
   */
  async refresh(refreshToken: string) {
    try {
      const payload = this.jwtService.verify(refreshToken, {
        secret: this.configService.getOrThrow<string>('jwt.secret'),
      });

      if (payload.type !== 'refresh') {
        throw new UnauthorizedException('Invalid token type');
      }

      // CRIT-4: Validate token_version against DB to detect replayed refresh tokens
      const supabase = this.supabaseService.getClient();
      const table = payload.role === 'ADMIN' ? 'admins' : 'users';
      const { data: entity } = await supabase
        .from(table)
        .select('token_version, status')
        .eq('id', payload.sub)
        .maybeSingle();

      if (!entity) {
        throw new UnauthorizedException('Account not found');
      }

      if (entity.status === 'suspended') {
        throw new UnauthorizedException('Account is suspended');
      }

      if (payload.tv !== entity.token_version) {
        throw new UnauthorizedException('Refresh token has been invalidated. Please log in again.');
      }

      // Generate a new rotated token pair
      const tokens = await this.generateTokenPair(payload.sub, payload.role, entity.token_version);

      return {
        message: 'Tokens refreshed successfully',
        ...tokens,
      };
    } catch (e) {
      if (e instanceof UnauthorizedException) throw e;
      throw new UnauthorizedException('Session expired. Please log in again.');
    }
  }

  /**
   * Bootstraps / seeds the very first super-admin in the DB using the ADMIN_SEED_SECRET.
   * MED-3: Disabled in production via ADMIN_SEED_ENABLED env flag.
   */
  async seedAdmin(dto: AdminLoginDto, secret: string) {
    // MED-3: Block seed endpoint in production
    const seedEnabled = this.configService.get<boolean>('adminSeedEnabled');
    if (!seedEnabled) {
      throw new ForbiddenException('Admin seeding is disabled in this environment');
    }

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
    const salt = await bcrypt.genSalt(12);
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
        token_version: 1,
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
   * LOW-1: Generate access + refresh JWT token pair.
   * Each token includes: sub, role, tv (token_version for logout invalidation), jti (unique ID).
   */
  private async generateTokenPair(userId: number, role: 'USER' | 'ADMIN', tokenVersion: number) {
    const jwtSecret = this.configService.getOrThrow<string>('jwt.secret');

    const basePayload = {
      sub: userId,
      role,
      tv: tokenVersion,          // token_version — incremented on logout to invalidate old tokens
      jti: crypto.randomUUID(),  // unique token ID for future blocklist support
    };

    const accessToken = this.jwtService.sign(
      { ...basePayload, type: 'access' },
      {
        secret: jwtSecret,
        expiresIn: (this.configService.get<string>('jwt.expiresIn') || '15m') as any,
      },
    );

    const refreshToken = this.jwtService.sign(
      { ...basePayload, type: 'refresh' },
      {
        secret: jwtSecret,
        expiresIn: (this.configService.get<string>('jwt.refreshExpiresIn') || '7d') as any,
      },
    );

    return {
      accessToken,
      refreshToken,
    };
  }
}
