import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

@Injectable()
export class SupabaseClientService implements OnModuleInit {
  private clientInstance: SupabaseClient;
  private authClientInstance: SupabaseClient;

  constructor(private configService: ConfigService) {}

  onModuleInit() {
    const supabaseUrl = this.configService.get<string>('supabase.url');
    const anonKey = this.configService.get<string>('supabase.anonKey');
    const serviceRoleKey = this.configService.get<string>('supabase.serviceRoleKey');

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      throw new Error('SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY must be defined in env variables');
    }

    // Initialize the client with the service role key to bypass RLS policies
    this.clientInstance = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    // Initialize a public auth client for Supabase Auth flows such as phone OTP.
    this.authClientInstance = createClient(supabaseUrl, anonKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });
  }

  /**
   * Retrieves the initialized Supabase client singleton instance.
   */
  getClient(): SupabaseClient {
    return this.clientInstance;
  }

  /**
   * Retrieves the initialized Supabase Auth client.
   */
  getAuthClient(): SupabaseClient {
    return this.authClientInstance;
  }
}
