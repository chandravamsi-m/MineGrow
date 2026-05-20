import {
  IsNotEmpty,
  IsString,
  IsIn,
  IsOptional,
  Length,
} from 'class-validator';

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
