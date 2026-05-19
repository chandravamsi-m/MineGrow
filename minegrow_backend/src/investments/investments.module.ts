import { Module } from '@nestjs/common';
import { InvestmentsService } from './investments.service';
import { InvestmentsController } from './investments.controller';
import { UploadsModule } from '../uploads/uploads.module';
import { PlansModule } from '../plans/plans.module';

@Module({
  imports: [UploadsModule, PlansModule],
  controllers: [InvestmentsController],
  providers: [InvestmentsService],
  exports: [InvestmentsService],
})
export class InvestmentsModule {}
