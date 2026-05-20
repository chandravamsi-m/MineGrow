import { IsNotEmpty, IsString, IsEmail, IsOptional, Length, Matches, IsIn, IsNumberString } from 'class-validator';

export class SendOtpDto {
  @IsNotEmpty()
  @IsString()
  @Matches(/^\+?[1-9]\d{1,14}$/, { message: 'Invalid mobile number format' })
  mobile: string;

  @IsOptional()
  @IsString()
  @IsIn(['register', 'login', 'forgot_password'])
  purpose?: string;
}

export class VerifyOtpDto {
  @IsNotEmpty()
  @IsString()
  @Matches(/^\+?[1-9]\d{1,14}$/, { message: 'Invalid mobile number format' })
  mobile: string;

  @IsNotEmpty()
  @IsString()
  @Matches(/^\d{6}$/, { message: 'OTP must be exactly 6 numeric digits' })
  otp: string;

  @IsOptional()
  @IsString()
  @IsIn(['register', 'login', 'forgot_password'])
  purpose?: string;
}

export class AdminLoginDto {
  @IsNotEmpty()
  @IsEmail()
  email: string;

  @IsNotEmpty()
  @IsString()
  @Length(6, 40)
  password: string;
}

export class OnboardStep1Dto {
  @IsNotEmpty()
  @IsString()
  @Length(2, 100)
  fullName: string;

  @IsNotEmpty()
  @IsEmail()
  email: string;

  @IsNotEmpty()
  @IsString()
  @Length(2, 500)
  address: string;
}
