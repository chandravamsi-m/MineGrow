import { Controller, Get, Put, Patch, Body, UseGuards, Req, Param, ParseIntPipe } from '@nestjs/common';
import { Request } from 'express';
import { PlansService } from './plans.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UpdatePlanDto } from './dto/plans.dto';

@Controller()
export class PlansController {
  constructor(private readonly plansService: PlansService) {}

  @Get('plans')
  async getPublicPlans() {
    return this.plansService.getPlans(true);
  }

  @Get('admin/plans')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  async getAdminPlans() {
    return this.plansService.getPlans(false);
  }

  @Put('admin/plans/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  async updatePlan(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() admin: any,
    @Body() dto: UpdatePlanDto,
    @Req() req: any,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    return this.plansService.updatePlan(admin.id, id, dto, ip);
  }

  @Patch('admin/plans/:id/toggle')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  async togglePlan(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() admin: any,
    @Req() req: any,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    return this.plansService.togglePlan(admin.id, id, ip);
  }
}
