import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('app/config')
  getAppConfig() {
    const paymentUpiId = process.env.PAYMENT_UPI_ID || 'minegrow@upi';
    return {
      payment_upi_id: paymentUpiId,
      paymentUpiId: paymentUpiId,
    };
  }
}
