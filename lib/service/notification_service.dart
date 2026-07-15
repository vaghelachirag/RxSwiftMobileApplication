// ============================================================================
// lib/service/notification_service.dart
//
// Firebase Cloud Messaging integration.
//
//  • Foreground: FCM does not surface a tray notification by itself, so we
//    render one manually via flutter_local_notifications.
//  • Background/terminated: the OS renders the tray notification straight
//    from the payload's `notification` block (see the
//    com.google.firebase.messaging.default_notification_* meta-data in
//    AndroidManifest.xml) — firebaseMessagingBackgroundHandler only needs to
//    run for silent/data-only messages, so it's a no-op today.
//  • Tapping a notification just brings the app to the foreground (default
//    OS/FCM behavior) — no deep-link navigation is wired up.
// ============================================================================

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notifications/data/fcm_token_remote_datasource.dart';

/// Must be a top-level function — it runs in its own isolate when a message
/// arrives while the app is backgrounded/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

const _androidChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Order Notifications',
  description: 'Notifications about new and updated delivery orders.',
  importance: Importance.high,
);

class NotificationService {
  NotificationService(this._tokenDataSource);
  final FcmTokenRemoteDataSource _tokenDataSource;

  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// One-time setup: permissions, local-notification channel, and the
  /// foreground/token-refresh listeners. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.instance.onTokenRefresh.listen(_sendTokenSilently);
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Fetches the current FCM token and registers it with the backend.
  /// Call once after a successful login.
  Future<void> registerDeviceToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _sendTokenSilently(token);
  }

  /// Silent failure mirrors the rest of the app's fire-and-forget sync calls
  /// (e.g. LocationSyncRepository) — a dropped registration just means the
  /// driver misses pushes until the next successful call.
  Future<void> _sendTokenSilently(String token) async {
    try {
      await _tokenDataSource.registerToken(token);
    } catch (_) {}
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(fcmTokenRemoteDataSourceProvider)),
);
