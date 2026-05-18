import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import helmet from 'helmet';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // 1. Enable Helmet for secure HTTP headers
  app.use(helmet());

  // 2. Enable Cross-Origin Resource Sharing (CORS)
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    credentials: true,
  });

  // 3. Set base path for API versioning (Section 12: Base URL: /api/v1)
  app.setGlobalPrefix('api/v1');

  // 4. Register global transformation and validation pipes
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
    }),
  );

  // 5. Register global exception filter to envelope all API errors
  app.useGlobalFilters(new HttpExceptionFilter());

  // 6. Register global interceptor to envelope all API success responses
  app.useGlobalInterceptors(new TransformInterceptor());

  const port = process.env.PORT || 3000;
  await app.listen(port);
  console.log(`Mining App Backend successfully listening on: http://localhost:${port}/api/v1`);
}
bootstrap();
