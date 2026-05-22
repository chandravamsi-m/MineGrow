import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { SupabaseClientService } from '../config/supabase.client';

@Injectable()
export class NotificationsService {
  constructor(private readonly supabaseService: SupabaseClientService) {}

  /**
   * Fetches historical notifications for a user from Supabase.
   */
  async getNotifications(userId: number) {
    const supabase = this.supabaseService.getClient();
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (error) {
      throw new InternalServerErrorException('Error retrieving notifications');
    }

    return (
      data?.map((n) => ({
        ...n,
        message: n.body,
        notification_type: n.type,
        createdAt: n.created_at,
        isRead: n.is_read,
      })) || []
    );
  }

  /**
   * Marks a specific notification as read.
   */
  async markAsRead(userId: number, id: number) {
    const supabase = this.supabaseService.getClient();
    const { data, error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('id', id)
      .eq('user_id', userId)
      .select('*')
      .single();

    if (error) {
      throw new InternalServerErrorException(
        'Error updating notification status',
      );
    }

    return {
      ...data,
      message: data.body,
      notification_type: data.type,
      createdAt: data.created_at,
      isRead: data.is_read,
    };
  }
}
