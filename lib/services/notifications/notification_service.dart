/// Airing notifications (flutter_local_notifications + timezone).
///
/// Stub created by `deps-prefs-contract` so `main.dart` already calls [init]; the
/// `notifications` unit fills it (plugin initialization, channels, scheduling from
/// `Preferences.notifications`, permission requests, open-from-notification).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Called once by `main` before `runApp`. Must stay cheap and must never throw: a
  /// notification failure cannot block the app start.
  Future<void> init() async {
    _initialized = true;
  }
}
