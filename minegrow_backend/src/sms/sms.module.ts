import { Module } from '@nestjs/common';
import { SmsService } from './sms.service';
import { DevLogProvider } from './providers/dev-log.provider';

@Module({
  providers: [
    SmsService,
    {
      provide: 'SMS_PROVIDER_TOKEN',
      useClass: DevLogProvider,
    },
  ],
  exports: [SmsService],
})
export class SmsModule {}
