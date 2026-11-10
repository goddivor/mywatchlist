/// The preferences contract: every DailyAL preference, typed and persisted.
///
/// - State: `PreferencesBloc` (provided in `main.dart`), state = [AppPreferences].
/// - Change: `context.read<PreferencesBloc>().add(GeneralPreferencesChanged((p) => p.copyWith(nsfw: true)))`.
/// - Read in a widget: `context.select((PreferencesBloc b) => b.state.content.hideScore)`.
/// - Read elsewhere: `Preferences.current`, `Preferences.general.nsfw`, `Preferences.content.timezone`.
library;

export 'app_preferences.dart';
export 'content_card_props.dart';
export 'content_preferences.dart';
export 'general_preferences.dart';
export 'list_preferences.dart';
export 'notification_preferences.dart';
export 'preferences_bloc.dart';
export 'preferences_event.dart';
export 'preferences_store.dart';
