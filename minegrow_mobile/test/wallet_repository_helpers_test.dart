import 'package:flutter_test/flutter_test.dart';
import 'package:minegrow/src/features/wallet/data/wallet_repository.dart';
import 'package:minegrow/src/shared/data/app_models.dart';

void main() {
  test('summarizeRoiByMonth totals credits by month newest first', () {
    final summaries = summarizeRoiByMonth(const [
      RoiHistoryItem(
        id: 1,
        investmentId: 10,
        amount: 100,
        creditedDate: '2026-04-01',
      ),
      RoiHistoryItem(
        id: 2,
        investmentId: 10,
        amount: 150,
        creditedDate: '2026-05-03',
      ),
      RoiHistoryItem(
        id: 3,
        investmentId: 11,
        amount: 50,
        creditedDate: '2026-05-20T00:00:00.000Z',
      ),
    ]);

    expect(summaries, hasLength(2));
    expect(summaries.first.monthKey, '2026-05');
    expect(summaries.first.total, 200);
    expect(summaries.first.entries, 2);
    expect(summaries.last.monthKey, '2026-04');
    expect(summaries.last.total, 100);
  });
}
