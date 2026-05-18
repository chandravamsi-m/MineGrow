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
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('jwt.secret') || 'supersecretkey123',
    });
  }

  async validate(payload: any) {
    // payload: { sub: userId, role: USER|ADMIN, iat, exp }
    const supabase = this.supabaseService.getClient();

    if (payload.role === 'ADMIN') {
      const { data: admin, error } = await supabase
        .from('admins')
        .select('id, full_name, email, status, is_super')
        .eq('id', payload.sub)
        .single();

      if (error || !admin || admin.status !== 'active') {
        throw new UnauthorizedException('Admin account is suspended, inactive, or invalid');
      }

      return { 
        id: admin.id, 
        name: admin.full_name, 
        email: admin.email, 
        role: 'ADMIN',
        isSuper: admin.is_super
      };
    } else {
      const { data: user, error } = await supabase
        .from('users')
        .select('id, full_name, mobile, email, status, kyc_verified')
        .eq('id', payload.sub)
        .single();

      if (error || !user || user.status === 'suspended') {
        throw new UnauthorizedException('User account is suspended or invalid');
      }

      return { 
        id: user.id, 
        name: user.full_name, 
        mobile: user.mobile, 
        email: user.email, 
        role: 'USER', 
        status: user.status,
        kycVerified: user.kyc_verified
      };
    }
  }
}
