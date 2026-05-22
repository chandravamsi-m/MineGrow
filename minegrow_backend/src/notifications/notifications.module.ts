import { Global, Module } from '@nestjs/common';
import { FcmService } from './fcm.service';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';

@Global()
@Module({
  controllers: [NotificationsController],
  providers: [FcmService, NotificationsService],
  exports: [FcmService, NotificationsService],
})
export class NotificationsModule {}
