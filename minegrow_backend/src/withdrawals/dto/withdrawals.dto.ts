import {
  IsNotEmpty,
  IsNumber,
  IsString,
  IsOptional,
  Length,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateWithdrawalDto {
  @IsNotEmpty()
  @Type(() => Number)
  @IsNumber()
  @Min(100, { message: 'Minimum withdrawal amount is ₹100' })
  amount: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  bankAccountId?: number;

  @IsOptional()
  @IsString()
  @Length(1, 100)
  bankName?: string;

  @IsOptional()
  @IsString()
  @Length(1, 30)
  accountNumber?: string;

  @IsOptional()
  @IsString()
  @Length(1, 20)
  ifscCode?: string;

  @IsOptional()
  @IsString()
  @Length(1, 100)
  upiId?: string;
}

export class RejectWithdrawalDto {
  @IsNotEmpty()
  @IsString()
  @Length(1, 500)
  adminNote: string;
}
