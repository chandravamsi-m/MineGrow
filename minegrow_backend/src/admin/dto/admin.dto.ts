import {
  IsNumber,
  IsNotEmpty,
  IsString,
  IsIn,
  Length,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class UpdateUserStatusDto {
  @IsNotEmpty()
  @IsString()
  @IsIn(['active', 'suspended', 'pending_kyc'])
  status: string;
}

export class KycReviewDto {
  @IsNotEmpty()
  @IsString()
  @Length(1, 500)
  reason: string;
}

export class AdjustWalletDto {
  @IsNotEmpty()
  @IsString()
  @IsIn(['roi', 'principal'])
  walletType: 'roi' | 'principal';

  @IsNotEmpty()
  @IsString()
  @IsIn(['credit', 'debit'])
  direction: 'credit' | 'debit';

  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  amount: number;

  @IsNotEmpty()
  @IsString()
  @Length(3, 500)
  reason: string;
}
