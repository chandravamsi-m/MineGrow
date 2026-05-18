import * as Joi from 'joi';

export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),
  PORT: Joi.number().default(3000),
  SUPABASE_URL: Joi.string().required(),
  SUPABASE_ANON_KEY: Joi.string().required(),
  SUPABASE_SERVICE_ROLE_KEY: Joi.string().required(),
  SUPABASE_STORAGE_BUCKET: Joi.string().default('mining-app-files'),
  JWT_SECRET: Joi.string().min(32).required(),
  JWT_EXPIRES_IN: Joi.string().default('15m'),
  JWT_REFRESH_EXPIRES_IN: Joi.string().default('7d'),
  ADMIN_SEED_SECRET: Joi.string().required(),
  OTP_EXPIRY_MINUTES: Joi.number().default(5),
  SMS_PROVIDER: Joi.string().default('DEV'),
  SMS_API_KEY: Joi.string().optional(),
  SMS_SENDER_ID: Joi.string().default('MINEAP'),
  FIREBASE_PROJECT_ID: Joi.string().optional(),
  FIREBASE_CLIENT_EMAIL: Joi.string().optional(),
  FIREBASE_PRIVATE_KEY: Joi.string().optional(),
  ROI_CRON_SCHEDULE: Joi.string().default('0 0 * * *'),
});
