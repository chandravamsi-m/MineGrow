import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import configuration from './config/configuration';
import { envValidationSchema } from './config/env.validation';
import { SupabaseModule } from './config/supabase.module';
import { AuditModule } from './audit/audit.module';
import { SmsModule } from './sms/sms.module';
import { AuthModule } from './auth/auth.module';
import { UploadsModule } from './uploads/uploads.module';
import { UsersModule } from './users/users.module';
import { PlansModule } from './plans/plans.module';
import { InvestmentsModule } from './investments/investments.module';
import { WalletModule } from './wallet/wallet.module';
import { WithdrawalsModule } from './withdrawals/withdrawals.module';
import { NotificationsModule } from './notifications/notifications.module';
import { RoiCronModule } from './cron/roi-cron.module';
import { AdminModule } from './admin/admin.module';

@Module({
  imports: [
    // Global Config Module with schema verification
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      validationSchema: envValidationSchema,
    }),
    // Enable system-wide cron scheduling
    ScheduleModule.forRoot(),
    // Core infra modules
    SupabaseModule,
    AuditModule,
    NotificationsModule,
    SmsModule,
    // Business features
    AuthModule,
    UploadsModule,
    UsersModule,
    PlansModule,
    InvestmentsModule,
    WalletModule,
    WithdrawalsModule,
    RoiCronModule,
    AdminModule,
  ],
})
export class AppModule {}
