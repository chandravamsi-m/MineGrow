import { IsNotEmpty, IsString, IsNumber, Min, Max, IsOptional } from 'class-validator';

export class UpdatePlanDto {
  @IsNotEmpty()
  @IsString()
  planName: string;

  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  minAmount: number;

  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  maxAmount: number;

  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  @Max(100)
  dailyRoiPct: number;

  @IsNotEmpty()
  @IsNumber()
  @Min(1)
  lockDays: number;

  @IsNotEmpty()
  @IsNumber()
  @Min(1)
  roiWithdrawDays: number;

  @IsOptional()
  @IsString()
  imageUrl?: string;
}

export class CreatePlanDto {
  @IsNotEmpty()
  @IsString()
  planName: string;

  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  minAmount: number;

  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  maxAmount: number;

  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  @Max(100)
  dailyRoiPct: number;

  @IsNotEmpty()
  @IsNumber()
  @Min(1)
  lockDays: number;

  @IsNotEmpty()
  @IsNumber()
  @Min(1)
  roiWithdrawDays: number;

  @IsOptional()
  @IsString()
  imageUrl?: string;
}
