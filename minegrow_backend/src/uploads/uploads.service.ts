import {
  Injectable,
  BadRequestException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
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
   * Validates file magic bytes (signatures) to verify the file type.
   */
  private checkFileSignature(buffer: Buffer): 'jpg' | 'png' | 'pdf' | null {
    if (!buffer || buffer.length < 4) {
      return null;
    }
    // PNG: 89 50 4E 47
    if (
      buffer[0] === 0x89 &&
      buffer[1] === 0x50 &&
      buffer[2] === 0x4E &&
      buffer[3] === 0x47
    ) {
      return 'png';
    }
    // JPEG/JPG: FF D8 FF
    if (
      buffer[0] === 0xFF &&
      buffer[1] === 0xD8 &&
      buffer[2] === 0xFF
    ) {
      return 'jpg';
    }
    // PDF: 25 50 44 46 (%PDF)
    if (
      buffer[0] === 0x25 &&
      buffer[1] === 0x50 &&
      buffer[2] === 0x44 &&
      buffer[3] === 0x46
    ) {
      return 'pdf';
    }
    return null;
  }

  /**
   * Uploads a file (KYC scan or Payment Proof) directly to private Supabase Storage.
   * Enforces 10MB limits for payment screenshots and 5MB limits for KYC documents.
   * Validates file signatures strictly (magic bytes) to prevent disguised uploads.
   */
  async uploadFile(
    userId: number,
    bucket: 'payment-proofs' | 'kyc-documents',
    file: any,
    uniquePrefix?: string,
  ): Promise<string> {
    const supabase = this.supabaseService.getClient();

    if (!file || !file.buffer) {
      throw new BadRequestException('Invalid file payload');
    }

    // 1. Validate File Signature (Magic Bytes)
    const detectedExt = this.checkFileSignature(file.buffer);
    if (!detectedExt) {
      throw new BadRequestException(
        'Invalid or unsupported file format. Only true JPEG, PNG, and PDF files are allowed',
      );
    }

    // 2. Validate Size limits (10MB for payment proofs, 5MB for KYC)
    const maxSizeBytes =
      bucket === 'payment-proofs' ? 10 * 1024 * 1024 : 5 * 1024 * 1024;
    if (file.size > maxSizeBytes) {
      const displaySize = bucket === 'payment-proofs' ? '10MB' : '5MB';
      throw new BadRequestException(
        `File size exceeds maximum permitted limit of ${displaySize}`,
      );
    }

    // 3. Generate unique path: {bucket_name}/{bucket_prefix}/{user_id}/{uniquePrefix}_{timestamp}.{ext}
    const timestamp = Date.now();
    const cleanPrefix = uniquePrefix
      ? uniquePrefix.replace(/[^a-zA-Z0-9_-]/g, '')
      : '';
    const fileBase = cleanPrefix
      ? `${cleanPrefix}_${timestamp}`
      : `file_${timestamp}`;
    
    // filePath prefix structure matches allowed bucket routing
    const filePath = `${bucket}/${userId}/${fileBase}.${detectedExt}`;

    // 4. Perform upload to Supabase bucket
    const rootBucketName =
      this.configService.get<string>('supabase.bucket') || 'mining-app-files';

    const { data, error } = await supabase.storage
      .from(rootBucketName)
      .upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: true,
      });

    if (error) {
      this.logger.error(
        `Supabase Storage upload failed for path ${filePath}:`,
        error,
      );
      throw new InternalServerErrorException(
        'Error uploading document to storage',
      );
    }

    return filePath; // returns final storage key path
  }

  /**
   * Generates a short-lived temporary URL to display private files to admins.
   * Default expiry is 5 minutes (300 seconds).
   */
  async getSignedUrl(filePath: string, expirySeconds = 300): Promise<string> {
    const supabase = this.supabaseService.getClient();
    const rootBucketName =
      this.configService.get<string>('supabase.bucket') || 'mining-app-files';

    const { data, error } = await supabase.storage
      .from(rootBucketName)
      .createSignedUrl(filePath, expirySeconds);

    if (error || !data?.signedUrl) {
      this.logger.error(
        `Error generating signed URL for path ${filePath}:`,
        error,
      );
      throw new InternalServerErrorException(
        'Error generating secure signed viewing URL',
      );
    }

    return data.signedUrl;
  }
}
