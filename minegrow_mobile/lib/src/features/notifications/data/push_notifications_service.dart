import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  static const _androidChannel = AndroidNotificationChannel(
    'minegrow_alerts',
    'MineGrow alerts',
    description: 'Investment, wallet, withdrawal, and account updates.',
    importance: Importance.high,
  );

  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _localNotificationsReady = false;

  static Future<bool> bootstrapFirebase() async {
    if (Firebase.apps.isNotEmpty) return true;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _bootstrapLocalNotifications();
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
    _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
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

  static Future<void> _bootstrapLocalNotifications() async {
    if (_localNotificationsReady) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(settings: initializationSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
    _localNotificationsReady = true;
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    await _bootstrapLocalNotifications();

    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data.isEmpty ? null : message.data.toString(),
    );
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
