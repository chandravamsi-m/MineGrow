import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { SupabaseClientService } from '../config/supabase.client';
import { FcmService } from '../notifications/fcm.service';
import { AuditService } from '../audit/audit.service';
import { getISTDateString } from '../common/utils/date.utils';

@Injectable()
export class RoiCronService {
  private readonly logger = new Logger(RoiCronService.name);

  constructor(
    private readonly supabaseService: SupabaseClientService,
    private readonly fcmService: FcmService,
    private readonly auditService: AuditService,
  ) {}

  /**
   * Automated cron executor. Fired based on configured cron schedule.
   */
  @Cron(process.env.ROI_CRON_SCHEDULE || '0 0 * * *')
  async runDailyRoi() {
    this.logger.log(
      'Triggering scheduled daily ROI calculation and maturity cron...',
    );
    try {
      await this.executeRoiRoutine(null);
    } catch (e: unknown) {
      this.logger.error('Scheduled daily ROI execution failed:', e);
    }
  }

  /**
   * Main calculation routine. Atomically executes pg SQL, summarizes
   * earnings, sends push alerts, and marks matured plans.
   */
  async executeRoiRoutine(adminId: number | null, ipAddress?: string) {
    const supabase = this.supabaseService.getClient();
    const todayStr = getISTDateString();

    try {
      // 1. Invoke atomic postgres transaction RPC
      const { data, error } = await supabase.rpc('credit_daily_roi', {
        p_credited_date: todayStr,
      });

      if (error) {
        this.logger.error(
          `PG Database error executing daily ROI credits: ${error.message}`,
        );
        throw new Error(error.message);
      }

      this.logger.log(
        `Daily ROI PG credit transaction complete: ${JSON.stringify(data)}`,
      );

      // 2. Query and dispatch notifications for daily ROI earnings
      const { data: credits } = await supabase
        .from('roi_history')
        .select('user_id, roi_amount')
        .eq('credited_date', todayStr);

      if (credits && credits.length > 0) {
        // Group by user_id to prevent multi-device token spamming
        const userEarnings: Record<number, number> = {};
        for (const c of credits) {
          userEarnings[c.user_id] =
            (userEarnings[c.user_id] || 0) + Number(c.roi_amount);
        }

        for (const [userIdStr, amount] of Object.entries(userEarnings)) {
          const userId = parseInt(userIdStr, 10);
          await this.fcmService.sendNotification(
            userId,
            'Daily ROI Credited',
            `Your wallet has been credited with Rs. ${amount.toFixed(2)} in daily ROI earnings.`,
            { type: 'roi_credit', amount },
          );
        }
      }

      // 3. Query and dispatch notifications for matured investments
      const { data: matured } = await supabase
        .from('investments')
        .select('user_id, amount')
        .eq('status', 'matured')
        .eq('maturity_date', todayStr);

      if (matured && matured.length > 0) {
        for (const inv of matured) {
          await this.fcmService.sendNotification(
            inv.user_id,
            'Investment Matured',
            `Your investment of Rs. ${Number(inv.amount).toLocaleString()} has matured! The principal is fully unlocked.`,
            { type: 'investment_maturity', amount: inv.amount },
          );
        }
      }

      // 4. Log compliance audit record
      await this.auditService.log(
        adminId ? 'admin' : 'system',
        adminId,
        'EXECUTE_DAILY_ROI_ROUTINE',
        null,
        null,
        { creditedDate: todayStr, result: data },
        ipAddress,
      );

      return {
        success: true,
        message: 'Daily ROI routine executed successfully',
        details: data,
      };
    } catch (err: unknown) {
      const errorMessage =
        err instanceof Error ? err.message : 'Unknown ROI routine error';

      // Log failure audit record
      await this.auditService.log(
        adminId ? 'admin' : 'system',
        adminId,
        'EXECUTE_DAILY_ROI_ROUTINE_FAILED',
        null,
        null,
        { creditedDate: todayStr, error: errorMessage },
        ipAddress,
      );
      throw err;
    }
  }
}
