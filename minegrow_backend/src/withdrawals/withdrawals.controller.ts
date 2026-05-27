import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
  Res,
  HttpStatus,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { WithdrawalsService } from './withdrawals.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AuditService } from '../audit/audit.service';
import {
  CreateWithdrawalDto,
  RejectWithdrawalDto,
} from './dto/withdrawals.dto';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class WithdrawalsController {
  constructor(
    private readonly withdrawalsService: WithdrawalsService,
    private readonly auditService: AuditService,
  ) {}

  @Get('withdrawals/eligibility')
  @Roles('USER')
  async getEligibility(@CurrentUser() user: any) {
    return this.withdrawalsService.getEligibility(user.id);
  }

  @Post('withdrawals/roi')
  @Roles('USER')
  async requestRoiWithdrawal(
    @CurrentUser() user: any,
    @Body() dto: CreateWithdrawalDto,
  ) {
    return this.withdrawalsService.requestRoiWithdrawal(user.id, dto);
  }

  @Post('withdrawals/principal')
  @Roles('USER')
  async requestPrincipalWithdrawal(
    @CurrentUser() user: any,
    @Body() dto: CreateWithdrawalDto,
  ) {
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
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const userFilter = userId ? parseInt(userId, 10) : undefined;
    return this.withdrawalsService.getAllWithdrawals({
      status,
      type,
      userId: userFilter,
      page: page ? parseInt(page, 10) : undefined,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
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
    return this.withdrawalsService.approveWithdrawal(
      admin.id,
      parseInt(id, 10),
      ip,
    );
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
    return this.withdrawalsService.rejectWithdrawal(
      admin.id,
      parseInt(id, 10),
      dto,
      ip,
    );
  }

  @Post('admin/withdrawals/:id/complete')
  @Roles('ADMIN')
  async completeWithdrawal(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Req() req: any,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    return this.withdrawalsService.completeWithdrawal(
      admin.id,
      parseInt(id, 10),
      ip,
    );
  }

  @Get('admin/withdrawals/export')
  @Roles('ADMIN')
  async exportWithdrawals(
    @CurrentUser() admin: any,
    @Query('status') status: string,
    @Query('type') type: string,
    @Query('reason') reason: string,
    @Req() req: any,
    @Res() res: any,
  ) {
    const trimmedReason = (reason || '').trim();
    if (trimmedReason.length < 5) {
      return res.status(HttpStatus.BAD_REQUEST).json({
        success: false,
        error: {
          code: 'EXPORT_REASON_REQUIRED',
          message:
            'A reason of at least 5 characters is required to export payout PII for audit purposes.',
          statusCode: HttpStatus.BAD_REQUEST,
        },
      });
    }

    const data = await this.withdrawalsService.getAllWithdrawals({
      status,
      type,
      paginate: false,
    });

    // Build standard CSV
    let csv =
      'ID,User ID,Full Name,Mobile,Amount,Type,Status,Bank Name,Account Number,IFSC Code,UPI ID,Requested At\n';
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

    // Audit the bulk PII export — required for compliance
    const ip = req.ip || req.socket?.remoteAddress;
    await this.auditService.log(
      'admin',
      admin.id,
      'EXPORT_WITHDRAWALS_CSV',
      null,
      null,
      {
        filters: { status: status || null, type: type || null },
        rowCount: data.length,
        reason: trimmedReason,
      },
      ip,
    );

    const stamp = Date.now();
    res.header('Content-Type', 'text/csv');
    res.attachment(`withdrawals_export_admin${admin.id}_${stamp}.csv`);
    return res.status(HttpStatus.OK).send(csv);
  }
}
