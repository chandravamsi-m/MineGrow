import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
  Res,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UpdateUserStatusDto, KycReviewDto } from './dto/admin.dto';
import { UploadsService } from '../uploads/uploads.service';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminController {
  constructor(
    private readonly adminService: AdminService,
    private readonly uploadsService: UploadsService,
  ) {}

  @Get('files/view')
  async viewFile(
    @Query('path') path: string,
    @Query('json') json: string,
    @Res() res: Response,
  ) {
    const signedUrl = await this.uploadsService.getSignedUrl(path);
    if (json === 'true') {
      return res.json({ signedUrl });
    }
    return res.redirect(302, signedUrl);
  }

  @Get('users')
  async getUsers(
    @Query('search') search?: string,
    @Query('status') status?: string,
  ) {
    return this.adminService.getUsers(search, status);
  }

  @Get('users/:id')
  async getUserDetail(@Param('id') id: string) {
    return this.adminService.getUserDetail(parseInt(id, 10));
  }

  @Patch('users/:id/status')
  async updateUserStatus(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Body() dto: UpdateUserStatusDto,
    @Req() req: any,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    return this.adminService.updateUserStatus(
      admin.id,
      parseInt(id, 10),
      dto,
      ip,
    );
  }

  @Post('users/:id/kyc/verify')
  @HttpCode(HttpStatus.OK)
  async verifyUserKyc(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Req() req: any,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    return this.adminService.verifyUserKyc(admin.id, parseInt(id, 10), ip);
  }

  @Post('users/:id/kyc/reject')
  @HttpCode(HttpStatus.OK)
  async rejectUserKyc(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Body() dto: KycReviewDto,
    @Req() req: any,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    return this.adminService.rejectUserKyc(admin.id, parseInt(id, 10), dto, ip);
  }

  @Get('reports/dashboard')
  async getDashboardStats() {
    return this.adminService.getDashboardStats();
  }

  @Get('reports/ledger')
  async getSystemLedger(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const pageNum = page ? parseInt(page, 10) : 1;
    const limitNum = limit ? parseInt(limit, 10) : 50;
    return this.adminService.getSystemLedger(pageNum, limitNum);
  }
}
