import { ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus } from '@nestjs/common';
import { Response } from 'express';
import { getISTDateTimeString } from '../utils/date.utils';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: any, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    const statusCode =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    let message = 'Internal server error';
    let code = 'INTERNAL_SERVER_ERROR';

    if (exception instanceof HttpException) {
      const res = exception.getResponse();
      if (typeof res === 'object' && res !== null) {
        const resMessage = (res as any).message;
        message = Array.isArray(resMessage) ? resMessage.join(', ') : resMessage || exception.message;
        code = (res as any).error || exception.name || 'HTTP_EXCEPTION';
        if (Array.isArray(resMessage)) {
          code = 'VALIDATION_ERROR';
        }
      } else {
        message = exception.message;
      }
    } else if (exception instanceof Error) {
      message = exception.message;
      code = exception.name || 'ERROR';
    }

    response.status(statusCode).json({
      success: false,
      error: {
        code: code.toUpperCase().replace(/\s+/g, '_'),
        message,
        statusCode,
      },
      timestamp: getISTDateTimeString(),
    });
  }
}
