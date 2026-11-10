import 'package:equatable/equatable.dart';
import 'package:mywatchlist/user/preferences/content_preferences.dart';
import 'package:mywatchlist/user/preferences/general_preferences.dart';
import 'package:mywatchlist/user/preferences/list_preferences.dart';
import 'package:mywatchlist/user/preferences/notification_preferences.dart';

/// Every DailyAL preference of the app, in four groups. Immutable: change it through
/// `PreferencesBloc` events, read it with `Preferences.current` (or the bloc state in widgets).
class AppPreferences extends Equatable {
  final GeneralPreferences general;
  final ContentPreferences content;
  final ListPreferences list;
  final NotificationPreferences notifications;

  const AppPreferences({
    this.general = const GeneralPreferences(),
    this.content = const ContentPreferences(),
    this.list = const ListPreferences(),
    this.notifications = const NotificationPreferences(),
  });

  AppPreferences copyWith({
    GeneralPreferences? general,
    ContentPreferences? content,
    ListPreferences? list,
    NotificationPreferences? notifications,
  }) =>
      AppPreferences(
        general: general ?? this.general,
        content: content ?? this.content,
        list: list ?? this.list,
        notifications: notifications ?? this.notifications,
      );

  @override
  List<Object?> get props => [general, content, list, notifications];
}
