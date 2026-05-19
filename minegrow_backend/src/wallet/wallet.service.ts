import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { SupabaseClientService } from '../config/supabase.client';

@Injectable()
export class WalletService {
  private readonly logger = new Logger(WalletService.name);

  constructor(private readonly supabaseService: SupabaseClientService) {}

  async getWallet(userId: number) {
    const supabase = this.supabaseService.getClient();
    const { data: wallet, error } = await supabase
      .from('wallets')
      .select('roi_balance, principal_balance, total_roi_earned, last_roi_withdrawal_at, updated_at')
      .eq('user_id', userId)
      .single();

    if (error || !wallet) {
      throw new InternalServerErrorException('Error loading wallet balances');
    }

    return wallet;
  }

  async getLedger(userId: number, page = 1, limit = 20) {
    const supabase = this.supabaseService.getClient();
    const from = (page - 1) * limit;
    const to = from + limit - 1;

    // Get count and data
    const { data: ledger, count, error } = await supabase
      .from('wallet_ledger')
      .select('*', { count: 'exact' })
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .range(from, to);

    if (error) {
      this.logger.error('Error fetching wallet ledger:', error);
      throw new InternalServerErrorException('Error loading transaction history');
    }

    const total = count || 0;
    const totalPages = Math.ceil(total / limit);

    return {
      data: ledger,
      pagination: {
        page,
        limit,
        total,
        totalPages,
      },
    };
  }

  async getRoiHistory(userId: number, startDate?: string, endDate?: string) {
    const supabase = this.supabaseService.getClient();
    let query = supabase
      .from('roi_history')
      .select('id, roi_amount, credited_date, created_at, investment_id')
      .eq('user_id', userId);

    if (startDate) {
      query = query.gte('credited_date', startDate);
    }
    if (endDate) {
      query = query.lte('credited_date', endDate);
    }

    const { data: history, error } = await query.order('credited_date', { ascending: false });

    if (error) {
      this.logger.error('Error fetching ROI history:', error);
      throw new InternalServerErrorException('Error loading daily ROI earnings records');
    }

    return history;
  }
}
