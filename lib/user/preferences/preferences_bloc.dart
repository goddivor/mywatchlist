import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/user/preferences/app_preferences.dart';
import 'package:mywatchlist/user/preferences/content_preferences.dart';
import 'package:mywatchlist/user/preferences/general_preferences.dart';
import 'package:mywatchlist/user/preferences/list_preferences.dart';
import 'package:mywatchlist/user/preferences/notification_preferences.dart';
import 'package:mywatchlist/user/preferences/preferences_event.dart';
import 'package:mywatchlist/user/preferences/preferences_store.dart';

/// App-wide DailyAL preferences. The state is the whole [AppPreferences]; it starts from the
/// saved values synchronously, so the first frame already uses them. Each change is saved
/// before it is emitted.
class PreferencesBloc extends Bloc<PreferencesEvent, AppPreferences> {
  final PreferencesStore store;

  PreferencesBloc({required this.store}) : super(store.read()) {
    Preferences._bloc = this;
    on<GeneralPreferencesChanged>(
        (event, emit) => _apply(emit, state.copyWith(general: event.update(state.general))));
    on<ContentPreferencesChanged>(
        (event, emit) => _apply(emit, state.copyWith(content: event.update(state.content))));
    on<ListPreferencesChanged>(
        (event, emit) => _apply(emit, state.copyWith(list: event.update(state.list))));
    on<NotificationPreferencesChanged>((event, emit) =>
        _apply(emit, state.copyWith(notifications: event.update(state.notifications))));
    on<PreferencesReset>(_onReset);
    on<PreferencesReloaded>((event, emit) => emit(store.read()));
  }

  Future<void> _apply(Emitter<AppPreferences> emit, AppPreferences next) async {
    if (next == state) return;
    await store.write(next, previous: state);
    emit(next);
  }

  Future<void> _onReset(PreferencesReset event, Emitter<AppPreferences> emit) {
    const defaults = AppPreferences();
    bool all(PreferencesGroup group) => event.groups.isEmpty || event.groups.contains(group);
    return _apply(
      emit,
      AppPreferences(
        general: all(PreferencesGroup.general) ? defaults.general : state.general,
        content: all(PreferencesGroup.content) ? defaults.content : state.content,
        list: all(PreferencesGroup.list) ? defaults.list : state.list,
        notifications:
            all(PreferencesGroup.notifications) ? defaults.notifications : state.notifications,
      ),
    );
  }

  @override
  Future<void> close() {
    if (identical(Preferences._bloc, this)) Preferences._bloc = null;
    return super.close();
  }
}

/// Read access for code without a `BuildContext` (services, API clients, notification
/// scheduling): `Preferences.current.general.nsfw`, `Preferences.content.timezone`…
///
/// Widgets read the bloc instead (`context.select((PreferencesBloc b) => b.state.general.nsfw)`)
/// so they rebuild on change. Before the bloc exists (tests, a background isolate) the
/// defaults are returned; a background isolate reads `PreferencesStore(...).read()` instead.
abstract final class Preferences {
  static PreferencesBloc? _bloc;

  /// The running bloc, to send an event from non-widget code; null before `main` created it.
  static PreferencesBloc? get bloc => _bloc;

  static AppPreferences get current => _bloc?.state ?? const AppPreferences();
  static GeneralPreferences get general => current.general;
  static ContentPreferences get content => current.content;
  static ListPreferences get list => current.list;
  static NotificationPreferences get notifications => current.notifications;

  /// Forgets the registered bloc (tests).
  @visibleForTesting
  static void reset() => _bloc = null;
}
