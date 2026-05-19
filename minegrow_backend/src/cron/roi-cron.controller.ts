import { Controller, Post, UseGuards, Req, HttpCode, HttpStatus } from '@nestjs/common';
import { Request } from 'express';
import { RoiCronService } from './roi-cron.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@Controller('admin/roi')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class RoiCronController {
  constructor(private readonly roiCronService: RoiCronService) {}

  @Post('trigger')
  @HttpCode(HttpStatus.OK)
  async triggerManualRoi(
    @CurrentUser() admin: any,
    @Req() req: any,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    return this.roiCronService.executeRoiRoutine(admin.id, ip);
  }
}
