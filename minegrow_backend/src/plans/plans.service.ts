import {
  Injectable,
  BadRequestException,
  NotFoundException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { SupabaseClientService } from '../config/supabase.client';
import { AuditService } from '../audit/audit.service';
import { UpdatePlanDto, CreatePlanDto } from './dto/plans.dto';
import { getISTDateTimeString } from '../common/utils/date.utils';

@Injectable()
export class PlansService {
  private readonly logger = new Logger(PlansService.name);

  constructor(
    private readonly supabaseService: SupabaseClientService,
    private readonly auditService: AuditService,
  ) {}

  /**
   * Fetch details of standard plan. Always filters to plan ID = 1.
   * If publicOnly is true, verifies the plan is currently marked active.
   */
  /**
   * Fetch all active plans (for public users) or all plans (for admins).
   */
  async getPlans(publicOnly = true) {
    const supabase = this.supabaseService.getClient();
    let query = supabase
      .from('investment_plan')
      .select('*')
      .order('id', { ascending: true });

    if (publicOnly) {
      query = query.eq('is_active', true);
    }

    const { data: plans, error } = await query;
    if (error) {
      this.logger.error('Failed to fetch investment plans:', error);
      throw new InternalServerErrorException(
        'Error retrieving investment plans',
      );
    }

    return plans;
  }

  /**
   * Fetch a specific plan by its ID.
   */
  async getPlanById(id: number, publicOnly = true) {
    const supabase = this.supabaseService.getClient();

    const { data: plan, error } = await supabase
      .from('investment_plan')
      .select('*')
      .eq('id', id)
      .maybeSingle();

    if (error || !plan) {
      throw new NotFoundException(`Investment plan with ID ${id} not found`);
    }

    if (publicOnly && !plan.is_active) {
      throw new BadRequestException(
        `Investment plan '${plan.plan_name}' is currently paused`,
      );
    }

    return plan;
  }

  /**
   * Admin updates details of a specific investment plan in-place.
   * Logs details of previous plan parameters to audit log.
   */
  async updatePlan(
    adminId: number,
    id: number,
    dto: UpdatePlanDto,
    ipAddress?: string,
  ) {
    const supabase = this.supabaseService.getClient();

    // 1. Fetch previous config for audit logging metadata
    const previousPlan = await this.getPlanById(id, false);

    // 2. Perform in-place update
    const { data: updatedPlan, error } = await supabase
      .from('investment_plan')
      .update({
        plan_name: dto.planName,
        min_amount: dto.minAmount,
        max_amount: dto.maxAmount,
        daily_roi_pct: dto.dailyRoiPct,
        lock_days: dto.lockDays,
        roi_withdraw_days: dto.roiWithdrawDays,
        image_url: dto.imageUrl !== undefined ? dto.imageUrl : previousPlan.image_url,
        updated_at: getISTDateTimeString(),
      })
      .eq('id', id)
      .select('*')
      .single();

    if (error || !updatedPlan) {
      this.logger.error(`Failed to update plan ID ${id}:`, error);
      throw new InternalServerErrorException(
        'Error saving investment plan updates',
      );
    }

    // 3. Write audit log
    await this.auditService.log(
      'admin',
      adminId,
      'UPDATE_INVESTMENT_PLAN',
      null,
      id,
      { before: previousPlan, after: updatedPlan },
      ipAddress,
    );

    return updatedPlan;
  }

  /**
   * Toggles standard plan active status by ID.
   */
  async togglePlan(adminId: number, id: number, ipAddress?: string) {
    const supabase = this.supabaseService.getClient();
    const previousPlan = await this.getPlanById(id, false);

    const newStatus = !previousPlan.is_active;

    const { data: updatedPlan, error } = await supabase
      .from('investment_plan')
      .update({
        is_active: newStatus,
        updated_at: getISTDateTimeString(),
      })
      .eq('id', id)
      .select('*')
      .single();

    if (error || !updatedPlan) {
      this.logger.error(`Failed to toggle status for plan ID ${id}:`, error);
      throw new InternalServerErrorException(
        'Error updating plan active state',
      );
    }

    // Write audit log
    await this.auditService.log(
      'admin',
      adminId,
      newStatus ? 'ACTIVATE_INVESTMENT_PLAN' : 'PAUSE_INVESTMENT_PLAN',
      null,
      id,
      { active: newStatus },
      ipAddress,
    );

    return updatedPlan;
  }

  async createPlan(adminId: number, dto: CreatePlanDto, ipAddress?: string) {
    const supabase = this.supabaseService.getClient();
    const { data: newPlan, error } = await supabase
      .from('investment_plan')
      .insert({
        plan_name: dto.planName,
        min_amount: dto.minAmount,
        max_amount: dto.maxAmount,
        daily_roi_pct: dto.dailyRoiPct,
        lock_days: dto.lockDays,
        roi_withdraw_days: dto.roiWithdrawDays,
        image_url: dto.imageUrl ?? null,
        is_active: true,
        created_at: getISTDateTimeString(),
        updated_at: getISTDateTimeString(),
      })
      .select('*')
      .single();

    if (error || !newPlan) {
      this.logger.error('Failed to create investment plan:', error);
      throw new InternalServerErrorException('Error creating investment plan');
    }

    await this.auditService.log(
      'admin',
      adminId,
      'CREATE_INVESTMENT_PLAN',
      null,
      newPlan.id,
      { after: newPlan },
      ipAddress,
    );

    return newPlan;
  }

  async deletePlan(adminId: number, id: number, ipAddress?: string) {
    const supabase = this.supabaseService.getClient();
    // Fetch current plan for audit
    const previousPlan = await this.getPlanById(id, false);

    const { error } = await supabase.from('investment_plan').delete().eq('id', id);
    if (error) {
      this.logger.error(`Failed to delete plan ID ${id}:`, error);
      throw new InternalServerErrorException('Error deleting investment plan');
    }

    await this.auditService.log(
      'admin',
      adminId,
      'DELETE_INVESTMENT_PLAN',
      null,
      id,
      { before: previousPlan },
      ipAddress,
    );
    return { success: true };
  }
}
