import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../shared/data/app_models.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

final notificationsProvider = FutureProvider<List<ApiNotification>>((ref) {
  return ref.watch(notificationsRepositoryProvider).getNotifications();
});

class NotificationsRepository {
  const NotificationsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ApiNotification>> getNotifications() {
    return _apiClient.getData<List<ApiNotification>>(
      '/notifications',
      parser: (json) => (json as List)
          .map((item) => ApiNotification.fromJson(item))
          .toList(growable: false),
    );
  }

  Future<ApiNotification> markAsRead(int id) {
    return _apiClient.patchData<ApiNotification>(
      '/notifications/$id/read',
      parser: ApiNotification.fromJson,
    );
  }
}
