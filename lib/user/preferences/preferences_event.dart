import 'package:mywatchlist/user/preferences/content_preferences.dart';
import 'package:mywatchlist/user/preferences/general_preferences.dart';
import 'package:mywatchlist/user/preferences/list_preferences.dart';
import 'package:mywatchlist/user/preferences/notification_preferences.dart';

/// Events of `PreferencesBloc`. Every field is updated through its group's event with a
/// `copyWith`, so one event covers each field with full typing:
///
/// ```dart
/// bloc.add(GeneralPreferencesChanged((p) => p.copyWith(nsfw: true)));
/// bloc.add(ContentPreferencesChanged((p) => p.copyWith(timezone: TimezonePref.jst)));
/// bloc.add(NotificationPreferencesChanged((p) => p.unsubscribed()));
/// ```
sealed class PreferencesEvent {
  const PreferencesEvent();
}

class GeneralPreferencesChanged extends PreferencesEvent {
  final GeneralPreferences Function(GeneralPreferences current) update;
  const GeneralPreferencesChanged(this.update);
}

class ContentPreferencesChanged extends PreferencesEvent {
  final ContentPreferences Function(ContentPreferences current) update;
  const ContentPreferencesChanged(this.update);
}

class ListPreferencesChanged extends PreferencesEvent {
  final ListPreferences Function(ListPreferences current) update;
  const ListPreferencesChanged(this.update);
}

class NotificationPreferencesChanged extends PreferencesEvent {
  final NotificationPreferences Function(NotificationPreferences current) update;
  const NotificationPreferencesChanged(this.update);
}

/// Which groups [PreferencesReset] puts back to their defaults.
enum PreferencesGroup { general, content, list, notifications }

/// Back to the defaults, for the given groups (all when empty).
class PreferencesReset extends PreferencesEvent {
  final Set<PreferencesGroup> groups;
  const PreferencesReset([this.groups = const {}]);
}

/// Re-reads the storage (after a backup restore, for instance).
class PreferencesReloaded extends PreferencesEvent {
  const PreferencesReloaded();
}
