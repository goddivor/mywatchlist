import 'package:mywatchlist/services/notifications/notification_backend.dart';
import 'package:mywatchlist/services/notifications/notification_models.dart';

/// Records every call instead of touching the notification plugin.
class FakeBackend implements NotificationBackend {
  FakeBackend({
    this.supported = true,
    this.permission = const NotificationPermissions(notifications: true, exactAlarms: true),
    this.launch,
  });

  bool supported;
  NotificationPermissions permission;
  String? launch;
  bool grantOnRequest = true;

  void Function(String? payload)? tapHandler;
  int cancelAllCalls = 0;
  int requestCalls = 0;
  final List<PlannedNotification> scheduled = [];
  final List<NotificationLook> looks = [];

  @override
  bool get isSupported => supported;

  @override
  Future<void> init(void Function(String? payload) onTap) async => tapHandler = onTap;

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<NotificationPermissions> permissions() async => permission;

  @override
  Future<NotificationPermissions> requestPermissions() async {
    requestCalls++;
    if (grantOnRequest) {
      permission = const NotificationPermissions(notifications: true, exactAlarms: true);
    }
    return permission;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    scheduled.clear();
    looks.clear();
  }

  @override
  Future<void> schedule(PlannedNotification notification, NotificationLook look) async {
    scheduled.add(notification);
    looks.add(look);
  }

  @override
  Future<int> pendingCount() async => scheduled.length;
}

class FakeTexts implements NotificationTexts {
  const FakeTexts();

  @override
  String episodeTitle(String anime, int episode) => 'Ep $episode of $anime';

  @override
  String newEpisodeTitle(String anime) => 'New: $anime';

  @override
  String get watchingBody => 'watching-body';

  @override
  String get planToWatchBody => 'plan-body';

  @override
  String get watchingChannel => 'Watching';

  @override
  String get watchingChannelDescription => 'Watching desc';

  @override
  String get planToWatchChannel => 'Plan';

  @override
  String get planToWatchChannelDescription => 'Plan desc';

  @override
  String get testBody => 'test-body';
}
