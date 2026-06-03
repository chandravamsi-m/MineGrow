import {
  Injectable,
  BadRequestException,
  NotFoundException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { SupabaseClientService } from '../config/supabase.client';
import { UploadsService } from '../uploads/uploads.service';
import { PlansService } from '../plans/plans.service';
import { AuditService } from '../audit/audit.service';
import {
  CreateInvestmentDto,
  RejectInvestmentDto,
} from './dto/investments.dto';
import {
  getISTDate,
  getISTDateString,
  getISTDateTimeString,
} from '../common/utils/date.utils';
import {
  buildPaginationMeta,
  getPaginationWindow,
} from '../common/utils/pagination.utils';

@Injectable()
export class InvestmentsService {
  private readonly logger = new Logger(InvestmentsService.name);

  constructor(
    private readonly supabaseService: SupabaseClientService,
    private readonly uploadsService: UploadsService,
    private readonly plansService: PlansService,
    private readonly auditService: AuditService,
  ) {}

  /**
   * Submit an investment request.
   * Enforces min/max plan bounds and snapshots plan daily ROI and lock parameters.
   */
  async createInvestment(userId: number, dto: CreateInvestmentDto, file: any) {
    const supabase = this.supabaseService.getClient();

    // 1. Fetch user to verify active status
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('status')
      .eq('id', userId)
      .single();

    if (userError || !user) {
      throw new NotFoundException('User profile not found');
    }

    if (user.status !== 'active') {
      throw new BadRequestException(
        'Your account must be active to initiate investments',
      );
    }

    // 2. Fetch the selected active investment plan
    const plan = await this.plansService.getPlanById(dto.planId, true);

    // 3. Validate investment amount limits for the selected plan
    const amountVal = Number(dto.amount);
    if (
      amountVal < Number(plan.min_amount) ||
      amountVal > Number(plan.max_amount)
    ) {
      throw new BadRequestException(
        `Investment amount must be between ₹${Number(plan.min_amount).toLocaleString()} and ₹${Number(plan.max_amount).toLocaleString()} for the ${plan.plan_name}.`,
      );
    }

    const utrNumber = dto.utrNumber?.trim().toUpperCase() || null;
    if (utrNumber) {
      const { data: duplicate, error: duplicateError } = await supabase
        .from('investments')
        .select('id')
        .eq('utr_number', utrNumber)
        .maybeSingle();

      if (duplicateError) {
        this.logger.error('Failed to check duplicate UTR:', duplicateError);
        throw new InternalServerErrorException(
          'Error validating transaction reference',
        );
      }

      if (duplicate) {
        throw new BadRequestException(
          'This UTR number has already been submitted for review',
        );
      }
    }

    // 4. Upload payment screenshot proof
    const storagePath = await this.uploadsService.uploadFile(
      userId,
      'payment-proofs',
      file,
      'investment',
    );

    // 5. Insert investment record with snapshotted plan values
    const { data: investment, error: insertError } = await supabase
      .from('investments')
      .insert({
        user_id: userId,
        plan_id: dto.planId,
        amount: amountVal,
        daily_roi_pct: plan.daily_roi_pct,
        lock_days: plan.lock_days,
        payment_proof_url: storagePath,
        utr_number: utrNumber,
        status: 'pending',
      })
      .select('*')
      .single();

    if (insertError || !investment) {
      if (insertError?.code === '23505') {
        throw new BadRequestException(
          'This UTR number has already been submitted for review',
        );
      }

      this.logger.error('Failed to create investment record:', insertError);
      throw new InternalServerErrorException(
        'Error submitting investment request',
      );
    }

    return investment;
  }

  async getOwnInvestments(userId: number) {
    const supabase = this.supabaseService.getClient();
    const { data: investments, error } = await supabase
      .from('investments')
      .select('*, investment_plan(plan_name)')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (error) {
      throw new InternalServerErrorException(
        'Error retrieving investments list',
      );
    }

    return investments?.map((inv: any) => {
      let planName = 'Starter Plan';
      if (inv.investment_plan) {
        planName = Array.isArray(inv.investment_plan)
          ? inv.investment_plan[0]?.plan_name || 'Starter Plan'
          : inv.investment_plan.plan_name || 'Starter Plan';
      }
      return {
        ...inv,
        plan_name: planName,
        planName: planName,
      };
    }) || [];
  }

  async getOwnInvestmentById(userId: number, id: number) {
    const supabase = this.supabaseService.getClient();
    const { data: investment, error } = await supabase
      .from('investments')
      .select('*, investment_plan(plan_name)')
      .eq('id', id)
      .eq('user_id', userId)
      .maybeSingle();

    if (error || !investment) {
      throw new NotFoundException(
        'Investment record not found or access denied',
      );
    }

    let planName = 'Starter Plan';
    const inv: any = investment;
    if (inv.investment_plan) {
      planName = Array.isArray(inv.investment_plan)
        ? inv.investment_plan[0]?.plan_name || 'Starter Plan'
        : inv.investment_plan.plan_name || 'Starter Plan';
    }

    return {
      ...investment,
      plan_name: planName,
      planName: planName,
    };
  }

  async getAllInvestments(filters: {
    status?: string;
    userId?: number;
    date?: string;
    page?: number;
    limit?: number;
  }) {
    const pagination = getPaginationWindow(filters.page, filters.limit, 50, 100);
    const supabase = this.supabaseService.getClient();
    let query = supabase
      .from('investments')
      .select('*, users(full_name, mobile), investment_plan(plan_name)', {
        count: 'exact',
      });

    if (filters.status) {
      query = query.eq('status', filters.status);
    }
    if (filters.userId) {
      query = query.eq('user_id', filters.userId);
    }
    if (filters.date) {
      query = query
        .gte('created_at', `${filters.date}T00:00:00.000Z`)
        .lte('created_at', `${filters.date}T23:59:59.999Z`);
    }

    const {
      data: investments,
      count,
      error,
    } = await query
      .order('created_at', { ascending: false })
      .range(pagination.from, pagination.to);

    if (error) {
      this.logger.error('Error fetching admin investments:', error);
      throw new InternalServerErrorException(
        'Error loading investments database',
      );
    }

    const mappedInvestments = investments?.map((inv: any) => {
      let planName = 'Starter Plan';
      if (inv.investment_plan) {
        planName = Array.isArray(inv.investment_plan)
          ? inv.investment_plan[0]?.plan_name || 'Starter Plan'
          : inv.investment_plan.plan_name || 'Starter Plan';
      }
      return {
        ...inv,
        plan_name: planName,
        planName: planName,
        plans: {
          plan_name: planName,
        },
      };
    }) || [];

    return {
      data: mappedInvestments,
      pagination: buildPaginationMeta(
        pagination.page,
        pagination.limit,
        count || 0,
      ),
    };
  }

  async getPendingInvestments() {
    const supabase = this.supabaseService.getClient();
    const { data: investments, error } = await supabase
      .from('investments')
      .select('*, users(full_name, mobile), investment_plan(plan_name)')
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(50);

    if (error) {
      throw new InternalServerErrorException('Error loading pending deposits');
    }

    return investments?.map((inv: any) => {
      let planName = 'Starter Plan';
      if (inv.investment_plan) {
        planName = Array.isArray(inv.investment_plan)
          ? inv.investment_plan[0]?.plan_name || 'Starter Plan'
          : inv.investment_plan.plan_name || 'Starter Plan';
      }
      return {
        ...inv,
        plan_name: planName,
        planName: planName,
        plans: {
          plan_name: planName,
        },
      };
    }) || [];
  }

  /**
   * Approves a pending deposit.
   * Sets start_date = TODAY, maturity_date = start_date + lock_days, and status = active.
   */
  async approveInvestment(adminId: number, id: number, ipAddress?: string) {
    const supabase = this.supabaseService.getClient();

    // 1. Fetch investment
    const { data: investment, error } = await supabase
      .from('investments')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !investment) {
      throw new NotFoundException('Investment request not found');
    }

    if (investment.status !== 'pending') {
      throw new BadRequestException(
        `Investment request is already processed (Status: ${investment.status})`,
      );
    }

    // 2. Calculate dates in IST standard
    const startStr = getISTDateString();
    const startDate = getISTDate();
    const maturityDate = new Date(startDate);
    maturityDate.setDate(startDate.getDate() + investment.lock_days);
    const maturityStr = getISTDateString(maturityDate);

    // 3. Update status to active only if it is still pending
    const { data: approved, error: updateError } = await supabase
      .from('investments')
      .update({
        status: 'active',
        start_date: startStr,
        maturity_date: maturityStr,
        updated_at: getISTDateTimeString(),
      })
      .eq('id', id)
      .eq('status', 'pending')
      .select('*')
      .maybeSingle();

    if (updateError) {
      this.logger.error('Failed to approve investment:', updateError);
      throw new InternalServerErrorException(
        'Error completing deposit approval process',
      );
    }

    if (!approved) {
      throw new BadRequestException(
        'Investment request has already been processed by another administrator',
      );
    }

    // 4. Log admin audit event
    await this.auditService.log(
      'admin',
      adminId,
      'APPROVE_DEPOSIT',
      approved.user_id,
      approved.id,
      {
        amount: approved.amount,
        startDate: startStr,
        maturityDate: maturityStr,
      },
      ipAddress,
    );

    return approved;
  }

  /**
   * Rejects a pending deposit.
   */
  async rejectInvestment(
    adminId: number,
    id: number,
    dto: RejectInvestmentDto,
    ipAddress?: string,
  ) {
    const supabase = this.supabaseService.getClient();

    // 1. Fetch investment
    const { data: investment, error } = await supabase
      .from('investments')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !investment) {
      throw new NotFoundException('Investment request not found');
    }

    if (investment.status !== 'pending') {
      throw new BadRequestException(
        `Investment request is already processed (Status: ${investment.status})`,
      );
    }

    // 2. Reject only if it is still pending
    const { data: rejected, error: updateError } = await supabase
      .from('investments')
      .update({
        status: 'rejected',
        admin_note: dto.adminNote,
        updated_at: getISTDateTimeString(),
      })
      .eq('id', id)
      .eq('status', 'pending')
      .select('*')
      .maybeSingle();

    if (updateError) {
      this.logger.error('Failed to reject investment:', updateError);
      throw new InternalServerErrorException(
        'Error completing deposit rejection process',
      );
    }

    if (!rejected) {
      throw new BadRequestException(
        'Investment request has already been processed by another administrator',
      );
    }

    // 3. Log admin audit event
    await this.auditService.log(
      'admin',
      adminId,
      'REJECT_DEPOSIT',
      rejected.user_id,
      rejected.id,
      { amount: rejected.amount, reason: dto.adminNote },
      ipAddress,
    );

    return rejected;
  }
}
