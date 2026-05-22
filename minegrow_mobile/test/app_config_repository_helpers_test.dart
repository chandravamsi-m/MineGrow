import 'package:flutter_test/flutter_test.dart';
import 'package:minegrow/src/features/app_config/data/app_config_repository.dart';

void main() {
  test('RemoteAppConfig parses support and legal fields', () {
    final config = RemoteAppConfig.fromJson({
      'payment_upi_id': 'minegrow@upi',
      'support_email': 'help@minegrow.test',
      'support_phone': '+91 99999 99999',
      'terms_url': 'https://minegrow.test/terms',
      'privacy_url': 'https://minegrow.test/privacy',
      'risk_disclosure': 'Returns vary by approved plan terms.',
    });

    expect(config.supportEmail, 'help@minegrow.test');
    expect(config.supportPhone, '+91 99999 99999');
    expect(config.termsUrl, 'https://minegrow.test/terms');
    expect(config.privacyUrl, 'https://minegrow.test/privacy');
    expect(config.riskDisclosure, 'Returns vary by approved plan terms.');
  });
}
