import { Module } from '@nestjs/common';
import { RoiCronService } from './roi-cron.service';
import { RoiCronController } from './roi-cron.controller';

@Module({
  controllers: [RoiCronController],
  providers: [RoiCronService],
  exports: [RoiCronService],
})
export class RoiCronModule {}
