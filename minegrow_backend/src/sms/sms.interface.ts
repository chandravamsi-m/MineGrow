export interface SmsProvider {
  sendOtp(mobile: string, otp: string): Promise<{ success: boolean; messageId?: string }>;
}
