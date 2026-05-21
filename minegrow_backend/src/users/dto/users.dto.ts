import {
  IsNotEmpty,
  IsString,
  IsEmail,
  IsOptional,
  Length,
  IsIn,
  IsBoolean,
} from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @Length(2, 100)
  fullName?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  address?: string;
}

export class AddBankAccountDto {
  @IsOptional()
  @IsString()
  @IsIn(['bank', 'upi'])
  accountType?: string;

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

  // Map snake_case fallbacks if mobile app sends them
  @IsOptional()
  @IsString()
  @IsIn(['bank', 'upi'])
  account_type?: string;

  @IsOptional()
  @IsString()
  bank_name?: string;

  @IsOptional()
  @IsString()
  account_number?: string;

  @IsOptional()
  @IsString()
  ifsc_code?: string;

  @IsOptional()
  @IsString()
  account_holder?: string;

  @IsOptional()
  @IsString()
  upi_id?: string;

  @IsOptional()
  @IsBoolean()
  is_default?: boolean;
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
