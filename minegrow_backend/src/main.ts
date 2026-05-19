import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import helmet from 'helmet';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';

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

  // 7. Initialize Swagger API Documentation UI (Section 12: Week 4)
  const config = new DocumentBuilder()
    .setTitle('MineGrow Mining API')
    .setDescription('Definitive backend technical reference documentation for the MineGrow Mining Investment App ecosystem.')
    .setVersion('1.0')
    .addBearerAuth({
      type: 'http',
      scheme: 'bearer',
      bearerFormat: 'JWT',
      name: 'JWT',
      description: 'Enter your custom JWT token to access protected user/admin routes',
      in: 'header',
    }, 'JWT-auth')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api-docs', app, document);

  const port = process.env.PORT || 3000;
  await app.listen(port);
  console.log(`Mining App Backend successfully listening on: http://localhost:${port}/api/v1`);
  console.log(`Swagger Interactive Documentation available at: http://localhost:${port}/api-docs`);
}
bootstrap();
