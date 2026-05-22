import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minegrow/src/features/profile/data/profile_repository.dart';
import 'package:minegrow/src/shared/data/app_models.dart';

void main() {
  test('buildKycUploadFormData uses expected multipart fields', () {
    final file = MultipartFile.fromBytes([1, 2, 3], filename: 'aadhaar.pdf');

    final formData = buildKycUploadFormData(docType: 'aadhaar', file: file);

    expect(formData.fields, contains(const MapEntry('docType', 'aadhaar')));
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
}
