import {
  Controller,
  Post,
  Body,
  Headers,
  HttpCode,
  HttpStatus,
  UseGuards,
  UnauthorizedException,
  BadRequestException,
  Request,
} from '@nestjs/common';
import { ApiBearerAuth } from '@nestjs/swagger';
import { Throttle, SkipThrottle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import {
  SendOtpDto,
  VerifyOtpDto,
  AdminLoginDto,
  OnboardStep1Dto,
} from './dto/auth.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  /**
   * CRIT-2: Strict throttle — 5 OTP requests per minute per IP to prevent phone enumeration.
   */
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Post('send-otp')
  @HttpCode(HttpStatus.OK)
  async sendOtp(@Body() dto: SendOtpDto) {
    return this.authService.sendOtp(dto);
  }

  /**
   * CRIT-2: Strict throttle — 10 attempts per minute per IP to prevent OTP brute force.
   */
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Post('verify-otp')
  @HttpCode(HttpStatus.OK)
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto);
  }

  @Post('onboard/step1')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async onboardStep1(@Body() dto: OnboardStep1Dto, @Request() req: any) {
    return this.authService.onboardStep1(req.user.id, dto);
  }

  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body('refreshToken') refreshToken: string) {
    if (!refreshToken) {
      throw new BadRequestException(
        'Refresh token is required in request body',
      );
    }
    return this.authService.refresh(refreshToken);
  }

  /**
   * CRIT-3: Logout now performs server-side token invalidation via token_version increment.
   * All tokens issued before this call will be rejected on the next request.
   */
  @Post('logout')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async logout(@Request() req: any) {
    return this.authService.logout(req.user.id, req.user.role);
  }

  /**
   * HIGH-2: Admin login throttled to 5 attempts per minute to prevent brute force.
   */
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Post('admin/login')
  @HttpCode(HttpStatus.OK)
  async adminLogin(@Body() dto: AdminLoginDto) {
    return this.authService.adminLogin(dto);
  }

  /**
   * MED-3: Seed endpoint is guarded by ADMIN_SEED_ENABLED env flag.
   * Set ADMIN_SEED_ENABLED=false in production to fully disable this endpoint.
   */
  @Throttle({ default: { limit: 3, ttl: 3600000 } }) // 3 attempts per hour max
  @Post('admin/seed')
  @HttpCode(HttpStatus.CREATED)
  async seedAdmin(
    @Body() dto: AdminLoginDto,
    @Headers('x-seed-secret') secret: string,
  ) {
    if (!secret) {
      throw new UnauthorizedException(
        'Administrative seeding secret key is missing in x-seed-secret header',
      );
    }
    return this.authService.seedAdmin(dto, secret);
  }
}
