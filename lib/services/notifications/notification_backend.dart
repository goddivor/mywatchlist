import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_models.dart';

/// What the system lets the app do with notifications.
@immutable
class NotificationPermissions {
  const NotificationPermissions({this.notifications = false, this.exactAlarms = false});

  /// Notifications may be shown (Android 13+ runtime permission, channel not blocked).
  final bool notifications;

  /// Alarms may fire at the exact minute (Android 12+ special access); without it the
  /// notification still arrives, a few minutes late.
  final bool exactAlarms;

  @override
  bool operator ==(Object other) =>
      other is NotificationPermissions &&
      other.notifications == notifications &&
      other.exactAlarms == exactAlarms;

  @override
  int get hashCode => Object.hash(notifications, exactAlarms);
}

/// Text and look of one scheduled notification, resolved by the service.
@immutable
class NotificationLook {
  const NotificationLook({
    required this.channelName,
    required this.channelDescription,
    this.imagePath,
    this.bigPicture = false,
  });

  final String channelName;
  final String channelDescription;

  /// Local file of the cover (large icon); null = none.
  final String? imagePath;

  /// Expand the notification with the cover as a big picture.
  final bool bigPicture;
}

/// The part of the notification plugin the app uses, so the service is tested with a fake.
abstract class NotificationBackend {
  /// False on platforms without scheduled notifications (everything but Android).
  bool get isSupported;

  /// Starts the plugin; [onTap] receives the payload of a notification tapped while the
  /// app runs.
  Future<void> init(void Function(String? payload) onTap);

  /// Payload of the notification that launched the app (cold start), or null.
  Future<String?> launchPayload();

  Future<NotificationPermissions> permissions();

  /// Asks Android for the notification permission and the exact alarm access.
  Future<NotificationPermissions> requestPermissions();

  Future<void> cancelAll();

  Future<void> schedule(PlannedNotification notification, NotificationLook look);

  Future<int> pendingCount();
}

/// Backend on `flutter_local_notifications` (Android).
///
/// Times are given in UTC: a notification is an absolute instant, so no device time zone
/// lookup is needed, and the weekly repeat of the broadcast fallback keeps the same instant.
class PluginNotificationBackend implements NotificationBackend {
  PluginNotificationBackend([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _exact = false;

  /// Drawable `ic_stat_notification` (android/app/src/main/res/drawable).
  static const String smallIcon = 'ic_stat_notification';

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> init(void Function(String? payload) onTap) async {
    if (!isSupported) return;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings(smallIcon)),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  @override
  Future<String?> launchPayload() async {
    if (!isSupported) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }

  @override
  Future<NotificationPermissions> permissions() async {
    if (!isSupported) return const NotificationPermissions();
    final android = _android;
    final shown = await android?.areNotificationsEnabled() ?? false;
    _exact = await android?.canScheduleExactNotifications() ?? false;
    return NotificationPermissions(notifications: shown, exactAlarms: _exact);
  }

  @override
  Future<NotificationPermissions> requestPermissions() async {
    if (!isSupported) return const NotificationPermissions();
    final android = _android;
    await android?.requestNotificationsPermission();
    if (await android?.canScheduleExactNotifications() != true) {
      // Opens the system "Alarms & reminders" screen; the result is read back below.
      await android?.requestExactAlarmsPermission();
    }
    return permissions();
  }

  @override
  Future<void> cancelAll() async {
    if (!isSupported) return;
    await _plugin.cancelAllPendingNotifications();
  }

  @override
  Future<void> schedule(PlannedNotification n, NotificationLook look) async {
    if (!isSupported) return;
    final image = look.imagePath == null ? null : FilePathAndroidBitmap(look.imagePath!);
    final style = image != null && look.bigPicture
        ? BigPictureStyleInformation(
            image,
            largeIcon: image,
            contentTitle: n.title,
            summaryText: n.body,
            hideExpandedLargeIcon: true,
          )
        : BigTextStyleInformation(n.body, contentTitle: n.title);
    await _plugin.zonedSchedule(
      id: n.id,
      title: n.title,
      body: n.body,
      scheduledDate: tz.TZDateTime.from(n.at, tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          n.kind.channelId,
          look.channelName,
          channelDescription: look.channelDescription,
          priority: Priority.high,
          importance: Importance.high,
          icon: smallIcon,
          largeIcon: image,
          styleInformation: style,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
      androidScheduleMode: _exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: n.payload,
      matchDateTimeComponents: n.repeatsWeekly ? DateTimeComponents.dayOfWeekAndTime : null,
    );
  }

  @override
  Future<int> pendingCount() async {
    if (!isSupported) return 0;
    return (await _plugin.pendingNotificationRequests()).length;
  }
}
