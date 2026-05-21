import { Controller, Get } from '@nestjs/common';
import { AppConfigService } from './app-config.service';

@Controller('app')
export class AppConfigController {
  constructor(private readonly appConfigService: AppConfigService) {}

  @Get('config')
  async getAppConfig() {
    const paymentUpiId = await this.appConfigService.getVal('payment_upi_id', 'minegrow@upi');
    const otpResendDelay = await this.appConfigService.getVal('otp_resend_delay', '30');

    return {
      payment_upi_id: paymentUpiId,
      paymentUpiId: paymentUpiId,
      otp_resend_delay: Number(otpResendDelay),
      otpResendDelay: Number(otpResendDelay),
    };
  }
}
