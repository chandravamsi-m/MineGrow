import { Controller, Get, Post, Body, Param, Query, UseGuards, Req, Res, HttpStatus } from '@nestjs/common';
import { Request, Response } from 'express';
import { WithdrawalsService } from './withdrawals.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateWithdrawalDto, RejectWithdrawalDto } from './dto/withdrawals.dto';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class WithdrawalsController {
  constructor(private readonly withdrawalsService: WithdrawalsService) {}

  @Get('withdrawals/eligibility')
  @Roles('USER')
  async getEligibility(@CurrentUser() user: any) {
    return this.withdrawalsService.getEligibility(user.id);
  }

  @Post('withdrawals/roi')
  @Roles('USER')
  async requestRoiWithdrawal(@CurrentUser() user: any, @Body() dto: CreateWithdrawalDto) {
    return this.withdrawalsService.requestRoiWithdrawal(user.id, dto);
  }

  @Post('withdrawals/principal')
  @Roles('USER')
  async requestPrincipalWithdrawal(@CurrentUser() user: any, @Body() dto: CreateWithdrawalDto) {
    return this.withdrawalsService.requestPrincipalWithdrawal(user.id, dto);
  }

  @Get('withdrawals')
  @Roles('USER')
  async getOwnWithdrawals(@CurrentUser() user: any) {
    return this.withdrawalsService.getOwnWithdrawals(user.id);
  }

  @Get('admin/withdrawals')
  @Roles('ADMIN')
  async getAllWithdrawals(
    @Query('status') status?: string,
    @Query('type') type?: string,
    @Query('userId') userId?: string,
  ) {
    const userFilter = userId ? parseInt(userId, 10) : undefined;
    return this.withdrawalsService.getAllWithdrawals({ status, type, userId: userFilter });
  }

  @Get('admin/withdrawals/pending')
  @Roles('ADMIN')
  async getPendingWithdrawals() {
    return this.withdrawalsService.getPendingWithdrawals();
  }

  @Post('admin/withdrawals/:id/approve')
  @Roles('ADMIN')
  async approveWithdrawal(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Req() req: any,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    return this.withdrawalsService.approveWithdrawal(admin.id, parseInt(id, 10), ip);
  }

  @Post('admin/withdrawals/:id/reject')
  @Roles('ADMIN')
  async rejectWithdrawal(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Body() dto: RejectWithdrawalDto,
    @Req() req: any,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    return this.withdrawalsService.rejectWithdrawal(admin.id, parseInt(id, 10), dto, ip);
  }

  @Post('admin/withdrawals/:id/complete')
  @Roles('ADMIN')
  async completeWithdrawal(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Req() req: any,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    return this.withdrawalsService.completeWithdrawal(admin.id, parseInt(id, 10), ip);
  }

  @Get('admin/withdrawals/export')
  @Roles('ADMIN')
  async exportWithdrawals(
    @Query('status') status: string,
    @Query('type') type: string,
    @Res() res: any,
  ) {
    const data = await this.withdrawalsService.getAllWithdrawals({ status, type });

    // Build standard CSV
    let csv = 'ID,User ID,Full Name,Mobile,Amount,Type,Status,Bank Name,Account Number,IFSC Code,UPI ID,Requested At\n';
    for (const row of data) {
      const u = row.users || {};
      const escName = (u.full_name || '').replace(/"/g, '""');
      const escMobile = (u.mobile || '').replace(/"/g, '""');
      const escBank = (row.bank_name || '').replace(/"/g, '""');
      const escAcc = (row.account_number || '').replace(/"/g, '""');
      const escIfsc = (row.ifsc_code || '').replace(/"/g, '""');
      const escUpi = (row.upi_id || '').replace(/"/g, '""');

      csv += `${row.id},${row.user_id},"${escName}","${escMobile}",${row.amount},${row.withdrawal_type},${row.status},"${escBank}","${escAcc}","${escIfsc}","${escUpi}",${row.requested_at}\n`;
    }

    res.header('Content-Type', 'text/csv');
    res.attachment(`withdrawals_export_${Date.now()}.csv`);
    return res.status(HttpStatus.OK).send(csv);
  }
}
