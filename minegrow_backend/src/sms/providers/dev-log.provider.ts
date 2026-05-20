import { Injectable, Logger } from '@nestjs/common';
import { SmsProvider } from '../sms.interface';

@Injectable()
export class DevLogProvider implements SmsProvider {
  private readonly logger = new Logger('DevLogProvider');

  async sendOtp(
    mobile: string,
    otp: string,
  ): Promise<{ success: boolean; messageId: string }> {
    this.logger.log(`[SMS OTP SIMULATION] Mobile: ${mobile} | OTP: ${otp}`);
    return { success: true, messageId: `mock-msg-id-${Date.now()}` };
  }
}
