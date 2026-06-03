import { envValidationSchema } from './env.validation';
import configuration from './configuration';

describe('Configuration & Env Validation', () => {
  describe('envValidationSchema', () => {
    const baseEnv = {
      SUPABASE_URL: 'https://example.supabase.co',
      SUPABASE_ANON_KEY: 'anon-key-123',
      SUPABASE_SERVICE_ROLE_KEY: 'service-role-key-123',
      JWT_SECRET: 'super-secret-key-32-chars-long-or-more',
      ADMIN_SEED_SECRET: 'admin-seed-secret-123',
    };

    it('should default ADMIN_SEED_ENABLED to false when omitted', () => {
      const { value, error } = envValidationSchema.validate(baseEnv);
      expect(error).toBeUndefined();
      expect(value.ADMIN_SEED_ENABLED).toBe('false');
    });

    it('should validate ADMIN_SEED_ENABLED as true', () => {
      const { value, error } = envValidationSchema.validate({
        ...baseEnv,
        ADMIN_SEED_ENABLED: 'true',
      });
      expect(error).toBeUndefined();
      expect(value.ADMIN_SEED_ENABLED).toBe('true');
    });

    it('should validate ADMIN_SEED_ENABLED as false', () => {
      const { value, error } = envValidationSchema.validate({
        ...baseEnv,
        ADMIN_SEED_ENABLED: 'false',
      });
      expect(error).toBeUndefined();
      expect(value.ADMIN_SEED_ENABLED).toBe('false');
    });

    it('should reject invalid values for ADMIN_SEED_ENABLED', () => {
      const { error } = envValidationSchema.validate({
        ...baseEnv,
        ADMIN_SEED_ENABLED: 'invalid-value',
      });
      expect(error).toBeDefined();
    });
  });

  describe('configuration factory', () => {
    let originalEnv: NodeJS.ProcessEnv;

    beforeAll(() => {
      originalEnv = { ...process.env };
    });

    afterEach(() => {
      process.env = { ...originalEnv };
    });

    it('should map adminSeedEnabled to true when ADMIN_SEED_ENABLED env is true', () => {
      process.env.ADMIN_SEED_ENABLED = 'true';
      const config = configuration();
      expect(config.adminSeedEnabled).toBe(true);
    });

    it('should map adminSeedEnabled to false when ADMIN_SEED_ENABLED env is false', () => {
      process.env.ADMIN_SEED_ENABLED = 'false';
      const config = configuration();
      expect(config.adminSeedEnabled).toBe(false);
    });

    it('should map adminSeedEnabled to false when ADMIN_SEED_ENABLED env is undefined', () => {
      delete process.env.ADMIN_SEED_ENABLED;
      const config = configuration();
      expect(config.adminSeedEnabled).toBe(false);
    });
  });
});
