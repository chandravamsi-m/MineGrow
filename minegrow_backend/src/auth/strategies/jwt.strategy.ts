import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { SupabaseClientService } from '../../config/supabase.client';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private readonly supabaseService: SupabaseClientService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromExtractors([
        ExtractJwt.fromAuthHeaderAsBearerToken(),
        (req: any) => {
          return req?.query?.token as string;
        },
      ]),
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('jwt.secret'),
    });
  }

  async validate(payload: any) {
    // payload: { sub, role, tv (token_version), jti, type, iat, exp }
    if (payload.type !== 'access') {
      throw new UnauthorizedException('Invalid token type');
    }

    const supabase = this.supabaseService.getClient();

    if (payload.role === 'ADMIN') {
      const { data: admin, error } = await supabase
        .from('admins')
        .select('id, full_name, email, status, is_super, token_version')
        .eq('id', payload.sub)
        .single();

      if (error || !admin || admin.status !== 'active') {
        throw new UnauthorizedException(
          'Admin account is suspended, inactive, or invalid',
        );
      }

      // CRIT-3: Validate token_version — invalidates all tokens issued before last logout
      if (payload.tv !== admin.token_version) {
        throw new UnauthorizedException(
          'Session has been invalidated. Please log in again.',
        );
      }

      return {
        id: admin.id,
        name: admin.full_name,
        email: admin.email,
        role: 'ADMIN',
        isSuper: admin.is_super,
      };
    } else {
      const { data: user, error } = await supabase
        .from('users')
        .select(
          'id, full_name, mobile, email, status, kyc_verified, token_version',
        )
        .eq('id', payload.sub)
        .single();

      if (error || !user || user.status === 'suspended') {
        throw new UnauthorizedException('User account is suspended or invalid');
      }

      // CRIT-3: Validate token_version — invalidates all tokens issued before last logout
      if (payload.tv !== user.token_version) {
        throw new UnauthorizedException(
          'Session has been invalidated. Please log in again.',
        );
      }

      return {
        id: user.id,
        name: user.full_name,
        mobile: user.mobile,
        email: user.email,
        role: 'USER',
        status: user.status,
        kycVerified: user.kyc_verified,
      };
    }
  }
}
