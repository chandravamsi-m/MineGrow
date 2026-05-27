import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/app_logger.dart';

final pushNotificationsServiceProvider = Provider<PushNotificationsService>((
  ref,
) {
  return PushNotificationsService(
    apiClient: ref.watch(apiClientProvider),
    logger: ref.watch(loggerProvider),
  );
});

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushNotificationsService.bootstrapFirebase();
}

class PushNotificationsService {
  PushNotificationsService({
    required ApiClient apiClient,
    required Logger logger,
  }) : _apiClient = apiClient,
       _logger = logger;

  final ApiClient _apiClient;
  final Logger _logger;
  StreamSubscription<String>? _tokenRefreshSubscription;

  static Future<bool> bootstrapFirebase() async {
    if (Firebase.apps.isNotEmpty) return true;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> registerCurrentDevice() async {
    if (!_supportsPushPlatform) return;

    final initialized = await bootstrapFirebase();
    if (!initialized) {
      _logger.w(
        'Firebase is not configured for this build; skipping push token registration.',
      );
      return;
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    await _registerToken(token);
    _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh
        .listen((nextToken) {
          _registerToken(nextToken);
        });
  }

  Future<void> _registerToken(String token) async {
    final platform = _platformName;
    if (platform == null) return;

    try {
      await _apiClient.postData<void>(
        '/users/device-token',
        data: {'fcmToken': token, 'platform': platform},
        parser: (_) {},
      );
    } catch (error, stackTrace) {
      _logger.w(
        'Could not register push notification token.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static bool get _supportsPushPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String? get _platformName {
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return null;
  }
}
