import { Controller, Get, Post, Body, Param, Query, UseGuards, UseInterceptors, UploadedFile, Req, BadRequestException } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Request } from 'express';
import { InvestmentsService } from './investments.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateInvestmentDto, RejectInvestmentDto } from './dto/investments.dto';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class InvestmentsController {
  constructor(private readonly investmentsService: InvestmentsService) {}

  @Post('investments')
  @Roles('USER')
  @UseInterceptors(FileInterceptor('paymentProof'))
  async createInvestment(
    @CurrentUser() user: any,
    @Body() dto: CreateInvestmentDto,
    @UploadedFile() file: any,
  ) {
    if (!file) {
      throw new BadRequestException('Payment screenshot proof is required in multipart form data');
    }
    return this.investmentsService.createInvestment(user.id, dto, file);
  }

  @Get('investments')
  @Roles('USER')
  async getOwnInvestments(@CurrentUser() user: any) {
    return this.investmentsService.getOwnInvestments(user.id);
  }

  @Get('investments/:id')
  @Roles('USER')
  async getOwnInvestmentById(@CurrentUser() user: any, @Param('id') id: string) {
    return this.investmentsService.getOwnInvestmentById(user.id, parseInt(id, 10));
  }

  @Get('admin/investments')
  @Roles('ADMIN')
  async getAllInvestments(
    @Query('status') status?: string,
    @Query('userId') userId?: string,
    @Query('date') date?: string,
  ) {
    const userFilter = userId ? parseInt(userId, 10) : undefined;
    return this.investmentsService.getAllInvestments({ status, userId: userFilter, date });
  }

  @Get('admin/investments/pending')
  @Roles('ADMIN')
  async getPendingInvestments() {
    return this.investmentsService.getPendingInvestments();
  }

  @Post('admin/investments/:id/approve')
  @Roles('ADMIN')
  async approveInvestment(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Req() req: any,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    return this.investmentsService.approveInvestment(admin.id, parseInt(id, 10), ip);
  }

  @Post('admin/investments/:id/reject')
  @Roles('ADMIN')
  async rejectInvestment(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Body() dto: RejectInvestmentDto,
    @Req() req: any,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    return this.investmentsService.rejectInvestment(admin.id, parseInt(id, 10), dto, ip);
  }
}
