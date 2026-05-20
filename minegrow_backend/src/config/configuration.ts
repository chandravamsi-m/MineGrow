export default () => ({
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '3000', 10) || 3000,
  supabase: {
    url: process.env.SUPABASE_URL,
    anonKey: process.env.SUPABASE_ANON_KEY,
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
    bucket: process.env.SUPABASE_STORAGE_BUCKET || 'mining-app-files',
  },
  jwt: {
    // NOTE: No fallback — JWT_SECRET is enforced as required by env.validation.ts
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '15m',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
  },
  adminSeedSecret: process.env.ADMIN_SEED_SECRET,
  // MED-3: Disable seed endpoint in production via env flag
  adminSeedEnabled: process.env.ADMIN_SEED_ENABLED !== 'false',
  // CRIT-5: CORS allowed origins (comma-separated)
  corsAllowedOrigins:
    process.env.CORS_ALLOWED_ORIGINS ||
    'http://localhost:3001,http://localhost:4200',
  otpExpiryMinutes: parseInt(process.env.OTP_EXPIRY_MINUTES || '5', 10) || 5,
  sms: {
    provider: process.env.SMS_PROVIDER || 'DEV',
    apiKey: process.env.SMS_API_KEY,
    senderId: process.env.SMS_SENDER_ID || 'MINEAP',
  },
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY
      ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
      : undefined,
  },
  roiCronSchedule: process.env.ROI_CRON_SCHEDULE || '0 0 * * *',
});
