import {
  IsNotEmpty,
  IsNumber,
  IsString,
  IsOptional,
  Length,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateInvestmentDto {
  @IsNotEmpty()
  @Type(() => Number)
  @IsNumber()
  planId: number;

  @IsNotEmpty()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  amount: number;

  @IsOptional()
  @IsString()
  @Length(1, 50)
  utrNumber?: string;
}

export class RejectInvestmentDto {
  @IsNotEmpty()
  @IsString()
  @Length(1, 500)
  adminNote: string;
}
