import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationsService {
  LocalNotificationsService._();

  static final LocalNotificationsService instance =
      LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'ldsp_updates',
    'LDSP Updates',
    description: 'Applicant alerts and application status updates.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showUnreadAlert({
    required int unreadCount,
    String? title,
    String? body,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final safeTitle = (title ?? '').trim().isEmpty
        ? 'LDSP Applicant Portal'
        : title!.trim();
    final safeBody = (body ?? '').trim().isEmpty
        ? 'You have $unreadCount unread notification${unreadCount == 1 ? '' : 's'}.'
        : body!.trim();

    await _plugin.show(
      1001,
      safeTitle,
      safeBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'notifications',
    );
  }
}
