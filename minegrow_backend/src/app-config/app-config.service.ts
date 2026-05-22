import { Injectable, Logger, InternalServerErrorException } from '@nestjs/common';
import { SupabaseClientService } from '../config/supabase.client';

@Injectable()
export class AppConfigService {
  private readonly logger = new Logger(AppConfigService.name);
  private cache: Record<string, string> | null = null;
  private cacheExpiresAt: number = 0;

  constructor(private readonly supabaseService: SupabaseClientService) {}

  /**
   * Loads configurations from the database into the cache if expired.
   */
  private async loadCache(): Promise<Record<string, string>> {
    const now = Date.now();
    if (this.cache && now < this.cacheExpiresAt) {
      return this.cache;
    }

    try {
      const supabase = this.supabaseService.getClient();
      const { data, error } = await supabase
        .from('app_config')
        .select('key, value');

      if (error) {
        if (error.code === 'PGRST205') {
          this.logger.warn("Table 'app_config' not found. Returning default system configurations.");
          const defaultCache = {
            payment_upi_id: 'minegrow@upi',
            otp_resend_delay: '30',
            support_email: 'support@minegrow.app',
            support_phone: '+91 90000 00000',
            terms_url: 'https://minegrow.app/terms',
            privacy_url: 'https://minegrow.app/privacy',
            risk_disclosure: 'Mining investment returns depend on active plan terms, approved deposits, and wallet eligibility rules.',
          };
          this.cache = defaultCache;
          this.cacheExpiresAt = now + 60000; // Cache defaults for 60 seconds
          return defaultCache;
        }
        this.logger.error('Failed to load app configurations from Supabase:', error);
        // Serve from stale cache if available, otherwise return empty
        return this.cache || {};
      }

      const newCache: Record<string, string> = {};
      if (data) {
        for (const item of data) {
          newCache[item.key] = item.value;
        }
      }

      this.cache = newCache;
      this.cacheExpiresAt = now + 60000; // Cache for 60 seconds
      return this.cache;
    } catch (err) {
      this.logger.error('Exception occurred loading app config:', err);
      return this.cache || {};
    }
  }

  /**
   * Retrieves a configuration value by key with a fallback value.
   */
  async getVal(key: string, fallback: string): Promise<string> {
    const config = await this.loadCache();
    return config[key] ?? fallback;
  }

  /**
   * Retrieves all loaded configurations.
   */
  async getAll(): Promise<Record<string, string>> {
    return this.loadCache();
  }

  /**
   * Updates a single configuration key-value pair and invalidates the memory cache.
   */
  async updateVal(key: string, value: string): Promise<void> {
    const supabase = this.supabaseService.getClient();

    const { error } = await supabase
      .from('app_config')
      .upsert({
        key,
        value,
        updated_at: new Date().toISOString(),
      });

    if (error) {
      this.logger.error(`Failed to update config key "${key}":`, error);
      throw new InternalServerErrorException(`Database error saving config key "${key}"`);
    }

    // Invalidate the cache to ensure updates are fetched next time
    this.clearCache();
  }

  /**
   * Manually clears the cache (e.g. after administrative updates).
   */
  clearCache(): void {
    this.cache = null;
    this.cacheExpiresAt = 0;
  }
}
