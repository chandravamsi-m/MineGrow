import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minegrow/src/features/profile/data/profile_repository.dart';
import 'package:minegrow/src/shared/data/app_models.dart';
import 'package:minegrow/src/shared/utils/upi_validator.dart';

void main() {
  test('buildKycUploadFormData uses expected multipart fields', () {
    final file = MultipartFile.fromBytes([1, 2, 3], filename: 'aadhaar.pdf');

    final formData = buildKycUploadFormData(docType: 'aadhaar', file: file);

    expect(
      formData.fields,
      contains(
        isA<MapEntry<String, String>>()
            .having((entry) => entry.key, 'key', 'docType')
            .having((entry) => entry.value, 'value', 'aadhaar'),
      ),
    );
    expect(formData.files.single.key, 'file');
    expect(formData.files.single.value.filename, 'aadhaar.pdf');
  });

  test('parseKycDocuments accepts wrapped backend responses', () {
    final documents = parseKycDocuments({
      'documents': [
        {
          'id': 7,
          'doc_type': 'pan',
          'status': 'pending',
          'doc_url': 'https://example.test/pan.pdf',
        },
      ],
    });

    expect(documents, hasLength(1));
    expect(documents.single.id, 7);
    expect(documents.single.docType, 'pan');
    expect(documents.single.status, 'pending');
    expect(documents.single.fileUrl, 'https://example.test/pan.pdf');
  });

  test('notificationPreferencesPayload matches backend preference body', () {
    const preferences = NotificationPreferences(
      push: false,
      investments: true,
      wallet: false,
      promotions: true,
    );

    expect(notificationPreferencesPayload(preferences), {
      'push': false,
      'investments': true,
      'wallet': false,
      'promotions': true,
    });
  });

  test('upiAccountPayload omits bank-only fields for UPI accounts', () {
    expect(upiAccountPayload(upiId: 'client@oksbi'), {
      'account_type': 'upi',
      'upi_id': 'client@oksbi',
    });

    expect(
      upiAccountPayload(upiId: 'client@oksbi', accountHolder: '  Client  '),
      {
        'account_type': 'upi',
        'upi_id': 'client@oksbi',
        'account_holder': 'Client',
      },
    );
  });

  test('UPI IDs are normalized and validated consistently', () {
    expect(normalizeUpiId('  Client.Name@OKSBI  '), 'client.name@oksbi');
    expect(isValidUpiId('client@oksbi'), isTrue);
    expect(isValidUpiId('client.name-1@okhdfcbank'), isTrue);
    expect(isValidUpiId('client'), isFalse);
    expect(isValidUpiId('client@'), isFalse);
    expect(isValidUpiId('c@oksbi'), isFalse);
  });
}
