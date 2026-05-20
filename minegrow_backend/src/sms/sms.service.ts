import {
  Injectable,
  InternalServerErrorException,
  Inject,
} from '@nestjs/common';
import { SmsProvider } from './sms.interface';

@Injectable()
export class SmsService {
  constructor(@Inject('SMS_PROVIDER_TOKEN') private readonly provider: any) {}

  async sendOtp(mobile: string, otp: string): Promise<void> {
    const result = await this.provider.sendOtp(mobile, otp);
    if (!result.success) {
      throw new InternalServerErrorException('Failed to dispatch SMS OTP');
    }
  }
}
