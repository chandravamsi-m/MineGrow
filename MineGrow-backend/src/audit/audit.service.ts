import { Injectable, Logger } from '@nestjs/common';
import { SupabaseClientService } from '../config/supabase.client';

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly supabaseService: SupabaseClientService) {}

  /**
   * Logs an administrative, financial, or system critical event.
   * Required for compliance. Append-only, never deletes or updates.
   */
  async log(
    actorType: 'admin' | 'system' | 'user',
    actorId: number | null,
    action: string,
    targetUserId: number | null = null,
    referenceId: number | null = null,
    metadata: any = {},
    ipAddress?: string,
  ): Promise<void> {
    const supabase = this.supabaseService.getClient();

    const { error } = await supabase
      .from('audit_logs')
      .insert({
        actor_type: actorType,
        actor_id: actorId,
        target_user_id: targetUserId,
        action,
        reference_id: referenceId,
        metadata,
        ip_address: ipAddress || null,
      });

    if (error) {
      this.logger.error(`Audit logs write failed for action ${action}:`, error);
    }
  }
}
