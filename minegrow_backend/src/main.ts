import { NestFactory } from '@nestjs/core';
import { RequestMethod, ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import helmet from 'helmet';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import * as dotenv from 'dotenv';

// Load .env BEFORE NestFactory.create so process.env is fully populated
// when we read CORS_ALLOWED_ORIGINS (ConfigModule runs inside the module)
dotenv.config();


async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // 1. Enable Helmet for secure HTTP headers
  app.use(helmet());

  // 2. Enable Cross-Origin Resource Sharing (CORS) — CRIT-5: Restrict to known origins
  const allowedOrigins = process.env.CORS_ALLOWED_ORIGINS
    ? process.env.CORS_ALLOWED_ORIGINS.split(',').map((o) => o.trim())
    : [
        'http://localhost:3000',
        'http://localhost:3001',
        'http://localhost:4200',
        'http://localhost:5173', // Admin panel (Vite default)
        'http://localhost:5174', // Admin panel (Vite fallback)
      ];

  app.enableCors({
    origin: (
      origin: string | undefined,
      callback: (err: Error | null, allow?: boolean) => void,
    ) => {
      // Allow requests with no origin (mobile apps, curl, Postman)
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error(`CORS policy: origin '${origin}' is not allowed`));
      }
    },
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    credentials: true,
  });

  // 3. Set base path for API versioning (Section 12: Base URL: /api/v1)
  app.setGlobalPrefix('api/v1', {
    exclude: [{ path: 'health', method: RequestMethod.GET }],
  });

  // 4. Register global transformation and validation pipes — HIGH-4: forbidNonWhitelisted: true
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  // 5. Register global exception filter to envelope all API errors
  app.useGlobalFilters(new HttpExceptionFilter());

  // 6. Register global interceptor to envelope all API success responses
  app.useGlobalInterceptors(new TransformInterceptor());

  // 7. Initialize Swagger API Documentation UI (Section 12: Week 4)
  const config = new DocumentBuilder()
    .setTitle('MineGrow Mining API')
    .setDescription(
      'Definitive backend technical reference documentation for the MineGrow Mining Investment App ecosystem.',
    )
    .setVersion('1.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        name: 'JWT',
        description:
          'Enter your custom JWT token to access protected user/admin routes',
        in: 'header',
      },
      'JWT-auth',
    )
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api-docs', app, document);

  const port = process.env.PORT || 3000;
  await app.listen(port);
  console.log(
    `Mining App Backend successfully listening on: http://localhost:${port}/api/v1`,
  );
  console.log(
    `Swagger Interactive Documentation available at: http://localhost:${port}/api-docs`,
  );
}
bootstrap();
