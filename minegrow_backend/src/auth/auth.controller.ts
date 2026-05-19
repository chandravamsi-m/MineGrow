import { Controller, Post, Body, Headers, HttpCode, HttpStatus, UseGuards, UnauthorizedException, BadRequestException, Request } from '@nestjs/common';
import { ApiBearerAuth } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { SendOtpDto, VerifyOtpDto, AdminLoginDto, OnboardStep1Dto } from './dto/auth.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('send-otp')
  @HttpCode(HttpStatus.OK)
  async sendOtp(@Body() dto: SendOtpDto) {
    return this.authService.sendOtp(dto);
  }

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

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body('refreshToken') refreshToken: string) {
    if (!refreshToken) {
      throw new BadRequestException('Refresh token is required in request body');
    }
    return this.authService.refresh(refreshToken);
  }

  @Post('logout')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async logout() {
    // In stateless JWT architectures, token invalidation occurs client side.
    // We return standard acknowledgement.
    return { message: 'Logged out successfully' };
  }

  @Post('admin/login')
  @HttpCode(HttpStatus.OK)
  async adminLogin(@Body() dto: AdminLoginDto) {
    return this.authService.adminLogin(dto);
  }

  @Post('admin/seed')
  @HttpCode(HttpStatus.CREATED)
  async seedAdmin(
    @Body() dto: AdminLoginDto,
    @Headers('x-seed-secret') secret: string,
  ) {
    if (!secret) {
      throw new UnauthorizedException('Administrative seeding secret key is missing in x-seed-secret header');
    }
    return this.authService.seedAdmin(dto, secret);
  }
}
