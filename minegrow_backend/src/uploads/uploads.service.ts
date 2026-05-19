import { Injectable, BadRequestException, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseClientService } from '../config/supabase.client';

@Injectable()
export class UploadsService {
  private readonly logger = new Logger(UploadsService.name);

  constructor(
    private readonly supabaseService: SupabaseClientService,
    private readonly configService: ConfigService,
  ) {}

  /**
   * Uploads a file (KYC scan or Payment Proof) directly to private Supabase Storage.
   * Enforces 10MB limits for payment screenshots and 5MB limits for KYC documents.
   */
  async uploadFile(
    userId: number,
    bucket: 'payment-proofs' | 'kyc-documents',
    file: any,
    uniquePrefix?: string,
  ): Promise<string> {
    const supabase = this.supabaseService.getClient();

    // 1. Validate Mimetypes
    const allowedMimeTypes = ['image/jpeg', 'image/png', 'application/pdf', 'image/jpg'];
    if (!allowedMimeTypes.includes(file.mimetype.toLowerCase())) {
      throw new BadRequestException('Unsupported file format. Only JPEG, PNG, and PDF files are allowed');
    }

    // 2. Validate Size limits (10MB for payment proofs, 5MB for KYC)
    const maxSizeBytes = bucket === 'payment-proofs' ? 10 * 1024 * 1024 : 5 * 1024 * 1024;
    if (file.size > maxSizeBytes) {
      const displaySize = bucket === 'payment-proofs' ? '10MB' : '5MB';
      throw new BadRequestException(`File size exceeds maximum permitted limit of ${displaySize}`);
    }

    // 3. Generate unique path: {bucket_name}/{bucket_prefix}/{user_id}/{uniquePrefix}_{timestamp}.{ext}
    const timestamp = Date.now();
    const originalExt = file.originalname.split('.').pop() || 'jpg';
    const cleanExt = originalExt.toLowerCase();
    const fileBase = uniquePrefix ? `${uniquePrefix}_${timestamp}` : `file_${timestamp}`;
    const filePath = `${bucket}/${userId}/${fileBase}.${cleanExt}`;

    // 4. Perform upload to Supabase bucket
    const rootBucketName = this.configService.get<string>('supabase.bucket') || 'mining-app-files';

    const { data, error } = await supabase.storage
      .from(rootBucketName)
      .upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: true,
      });

    if (error) {
      this.logger.error(`Supabase Storage upload failed for path ${filePath}:`, error);
      throw new InternalServerErrorException('Error uploading document to storage');
    }

    return filePath; // returns final storage key path
  }

  /**
   * Generates a short-lived temporary URL to display private files to admins.
   * Default expiry is 5 minutes (300 seconds).
   */
  async getSignedUrl(filePath: string, expirySeconds = 300): Promise<string> {
    const supabase = this.supabaseService.getClient();
    const rootBucketName = this.configService.get<string>('supabase.bucket') || 'mining-app-files';

    const { data, error } = await supabase.storage
      .from(rootBucketName)
      .createSignedUrl(filePath, expirySeconds);

    if (error || !data?.signedUrl) {
      this.logger.error(`Error generating signed URL for path ${filePath}:`, error);
      throw new InternalServerErrorException('Error generating secure signed viewing URL');
    }

    return data.signedUrl;
  }
}
