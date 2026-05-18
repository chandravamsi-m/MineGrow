import { IsNotEmpty, IsString, IsEmail, IsOptional, Length, IsIn, IsBoolean } from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @Length(2, 100)
  fullName?: string;

  @IsOptional()
  @IsEmail()
  email?: string;
}

export class ChangePasswordDto {
  @IsNotEmpty()
  @IsString()
  @Length(6, 40)
  currentPassword: string;

  @IsNotEmpty()
  @IsString()
  @Length(6, 40)
  newPassword: string;
}

export class AddBankAccountDto {
  @IsNotEmpty()
  @IsString()
  @IsIn(['bank', 'upi'])
  accountType: string;

  @IsOptional()
  @IsString()
  bankName?: string;

  @IsOptional()
  @IsString()
  accountNumber?: string;

  @IsOptional()
  @IsString()
  ifscCode?: string;

  @IsOptional()
  @IsString()
  accountHolder?: string;

  @IsOptional()
  @IsString()
  upiId?: string;

  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;
}

export class RegisterDeviceTokenDto {
  @IsNotEmpty()
  @IsString()
  fcmToken: string;

  @IsNotEmpty()
  @IsString()
  @IsIn(['android', 'ios'])
  platform: string;
}
