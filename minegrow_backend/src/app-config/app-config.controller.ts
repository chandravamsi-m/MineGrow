import { Controller, Get } from '@nestjs/common';
import { AppConfigService } from './app-config.service';

@Controller('app')
export class AppConfigController {
  constructor(private readonly appConfigService: AppConfigService) {}

  @Get('config')
  async getAppConfig() {
    const paymentUpiId = await this.appConfigService.getVal('payment_upi_id', 'minegrow@upi');
    const otpResendDelay = await this.appConfigService.getVal('otp_resend_delay', '30');
    const supportEmail = await this.appConfigService.getVal('support_email', 'support@minegrow.app');
    const supportPhone = await this.appConfigService.getVal('support_phone', '+91 90000 00000');
    const termsUrl = await this.appConfigService.getVal('terms_url', 'https://minegrow.app/terms');
    const privacyUrl = await this.appConfigService.getVal('privacy_url', 'https://minegrow.app/privacy');
    const riskDisclosure = await this.appConfigService.getVal(
      'risk_disclosure',
      'Mining investment returns depend on active plan terms, approved deposits, and wallet eligibility rules.',
    );

    return {
      payment_upi_id: paymentUpiId,
      paymentUpiId: paymentUpiId,
      otp_resend_delay: Number(otpResendDelay),
      otpResendDelay: Number(otpResendDelay),
      support_email: supportEmail,
      supportEmail,
      support_phone: supportPhone,
      supportPhone,
      terms_url: termsUrl,
      termsUrl,
      privacy_url: privacyUrl,
      privacyUrl,
      risk_disclosure: riskDisclosure,
      riskDisclosure,
    };
  }
}
