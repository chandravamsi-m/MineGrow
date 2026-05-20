import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { getISTDateTimeString } from '../utils/date.utils';

export interface ResponseEnvelope<T> {
  success: boolean;
  data: T;
  message?: string;
  pagination?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
  timestamp: string;
}

@Injectable()
export class TransformInterceptor<T> implements NestInterceptor<
  T,
  ResponseEnvelope<T>
> {
  intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Observable<ResponseEnvelope<T>> {
    return next.handle().pipe(
      map((res) => {
        const timestamp = getISTDateTimeString();

        // 1. If response is already formatted
        if (res && typeof res === 'object' && 'success' in res) {
          return {
            timestamp,
            ...res,
          };
        }

        // 2. If response matches custom standard structure with paging
        if (
          res &&
          typeof res === 'object' &&
          'data' in res &&
          ('pagination' in res || 'message' in res)
        ) {
          return {
            success: true,
            data: res.data,
            message: res.message || 'Request successful',
            pagination: res.pagination,
            timestamp,
          };
        }

        // 3. Fallback standard wrapper
        return {
          success: true,
          data: res === undefined ? null : res,
          message: 'Request successful',
          timestamp,
        };
      }),
    );
  }
}
