import {
  Controller,
  Get,
  Put,
  Post,
  Delete,
  Patch,
  Body,
  Param,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import {
  UpdateProfileDto,
  AddBankAccountDto,
  RegisterDeviceTokenDto,
} from './dto/users.dto';

@Controller('users')
@ApiBearerAuth('JWT-auth')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('USER')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('profile')
  async getProfile(@CurrentUser() user: any) {
    return this.usersService.getProfile(user.id);
  }

  @Put('profile')
  async updateProfile(@CurrentUser() user: any, @Body() dto: UpdateProfileDto) {
    return this.usersService.updateProfile(user.id, dto);
  }

  @Post('kyc')
  @UseInterceptors(FileInterceptor('file'))
  async uploadKyc(
    @CurrentUser() user: any,
    @Body('docType')
    docType: 'aadhaar' | 'pan' | 'passport' | 'driving_license',
    @UploadedFile() file: any,
  ) {
    if (!file) {
      throw new BadRequestException('KYC document scan file is required');
    }
    const validTypes = ['aadhaar', 'pan', 'passport', 'driving_license'];
    if (!docType || !validTypes.includes(docType.toLowerCase())) {
      throw new BadRequestException(
        `Valid docType is required (${validTypes.join(', ')})`,
      );
    }
    return this.usersService.uploadKyc(user.id, file, docType);
  }

  @Get('kyc')
  async getKycStatus(@CurrentUser() user: any) {
    return this.usersService.getKycStatus(user.id);
  }

  @Get('bank-accounts')
  async getBankAccounts(@CurrentUser() user: any) {
    return this.usersService.getBankAccounts(user.id);
  }

  @Post('bank-accounts')
  async addBankAccount(
    @CurrentUser() user: any,
    @Body() dto: AddBankAccountDto,
  ) {
    return this.usersService.addBankAccount(user.id, dto);
  }

  @Delete('bank-accounts/:id')
  async deleteBankAccount(@CurrentUser() user: any, @Param('id') id: string) {
    return this.usersService.deleteBankAccount(user.id, parseInt(id, 10));
  }

  @Patch('bank-accounts/:id/default')
  async setDefaultBankAccount(
    @CurrentUser() user: any,
    @Param('id') id: string,
  ) {
    return this.usersService.setDefaultBankAccount(user.id, parseInt(id, 10));
  }

  @Post('device-token')
  async registerDeviceToken(
    @CurrentUser() user: any,
    @Body() dto: RegisterDeviceTokenDto,
  ) {
    return this.usersService.registerDeviceToken(user.id, dto);
  }
}
