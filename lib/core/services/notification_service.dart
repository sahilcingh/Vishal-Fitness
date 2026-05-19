import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../main.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // FCM shows the notification automatically when the app is in background/killed.
}

class NotificationService {
  static final _local = FlutterLocalNotificationsPlugin();

  static const _channelId = 'announcements';
  static const _channelName = 'Announcements';

  static Future<void> initialize(String userId) async {
    // Push notifications are not supported on web.
    if (kIsWeb) return;

    // Create Android notification channel (required for Android 8+)
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Gym announcements from Vishal Fitness',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Init local notifications (used for foreground display)
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Request permission
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Get token and store it
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _storeToken(userId, token);

    // Keep token fresh
    FirebaseMessaging.instance.onTokenRefresh
        .listen((t) => _storeToken(userId, t));

    // Show foreground notifications via local notifications
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _local.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Gym announcements',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  static Future<void> _storeToken(String userId, String token) async {
    try {
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'other';
      await supabase.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');
    } catch (e) {
      debugPrint('FCM token store error: $e');
    }
  }

  static Future<void> removeToken() async {
    if (kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      final userId = supabase.auth.currentUser?.id;
      if (token == null || userId == null) return;
      await supabase
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('FCM token remove error: $e');
    }
  }
}
