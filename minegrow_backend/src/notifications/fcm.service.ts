import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseClientService } from '../config/supabase.client';
import * as admin from 'firebase-admin';

@Injectable()
export class FcmService implements OnModuleInit {
  private readonly logger = new Logger(FcmService.name);
  private firebaseApp: admin.app.App | null = null;

  constructor(
    private readonly configService: ConfigService,
    private readonly supabaseService: SupabaseClientService,
  ) {}

  onModuleInit() {
    const projectId = this.configService.get<string>('firebase.projectId');
    const clientEmail = this.configService.get<string>('firebase.clientEmail');
    const privateKey = this.configService.get<string>('firebase.privateKey');

    // Detect dummy or placeholder keys
    const isMock =
      !privateKey ||
      privateKey.includes('-----BEGIN PRIVATE KEY-----\\nMIIEvgIBADAN');

    if (projectId && clientEmail && privateKey && !isMock) {
      try {
        this.firebaseApp = admin.initializeApp({
          credential: admin.credential.cert({
            projectId,
            clientEmail,
            privateKey,
          }),
        });
        this.logger.log(
          'Firebase Admin SDK initialized successfully for production FCM dispatch',
        );
      } catch (err) {
        this.logger.error(
          'Firebase Admin SDK failed to initialize. Running in fallback mode:',
          err,
        );
      }
    } else {
      this.logger.warn(
        'Firebase credentials not configured or dummy. FCM will run in developer console log mode.',
      );
    }
  }

  /**
   * Dispatches push notification to all registered device tokens of a user.
   * Gracefully falls back to simulation mode when Firebase is not initialized.
   */
  async sendNotification(
    userId: number,
    title: string,
    body: string,
    data: any = {},
  ): Promise<void> {
    const supabase = this.supabaseService.getClient();

    // Map raw notification types to allowed database constraint enums
    let dbType = 'general';
    const rawType = data?.type || '';
    const allowedTypes = [
      'roi_credit',
      'deposit_approved',
      'deposit_rejected',
      'withdrawal_approved',
      'withdrawal_completed',
      'withdrawal_rejected',
      'investment_matured',
      'general',
    ];
    if (allowedTypes.includes(rawType)) {
      dbType = rawType;
    } else if (rawType === 'investment_maturity') {
      dbType = 'investment_matured';
    } else if (rawType === 'deposit') {
      dbType = 'deposit_approved';
    } else if (rawType === 'withdrawal') {
      dbType = 'withdrawal_approved';
    }

    // 1. Persist notification to Supabase database history
    try {
      const { error: dbError } = await supabase.from('notifications').insert({
        user_id: userId,
        title,
        body,
        type: dbType,
        is_read: false,
      });
      if (dbError) {
        this.logger.error(`Failed to save notification record to DB:`, dbError);
      }
    } catch (dbErr) {
      this.logger.error(`Exception writing notification to DB:`, dbErr);
    }

    // 2. Fetch active device tokens
    const { data: tokens, error } = await supabase
      .from('device_tokens')
      .select('fcm_token')
      .eq('user_id', userId);

    if (error || !tokens || tokens.length === 0) {
      this.logger.log(
        `[FCM SIMULATION] User ${userId} (No Tokens registered) | Message: [${title}] ${body}`,
      );
      return;
    }

    const tokenStrings = tokens.map((t) => t.fcm_token);

    if (this.firebaseApp) {
      try {
        const payloadData = data
          ? Object.keys(data).reduce(
              (acc, key) => {
                acc[key] = String(data[key]);
                return acc;
              },
              {} as Record<string, string>,
            )
          : {};

        const message: admin.messaging.MulticastMessage = {
          tokens: tokenStrings,
          notification: {
            title,
            body,
          },
          data: payloadData,
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        this.logger.log(
          `FCM Multicast success: ${response.successCount} delivered, ${response.failureCount} failed`,
        );

        // Optionally clean up invalid tokens if FCM indicates failure, but keep it simple here
      } catch (err) {
        this.logger.error(
          `FCM multicast delivery failed for user ${userId}:`,
          err,
        );
      }
    } else {
      this.logger.log(
        `[FCM SIMULATION] User: ${userId} | Device Tokens: [${tokenStrings.join(', ')}] | Message: [${title}] ${body}`,
      );
    }
  }
}
