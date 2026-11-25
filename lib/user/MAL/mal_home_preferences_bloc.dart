import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';

// Events
abstract class HomePreferencesEvent {}

class LoadHomePreferencesEvent extends HomePreferencesEvent {}

class UpdateHomePreferencesEvent extends HomePreferencesEvent {
  final MalHomePreferences preferences;
  
  UpdateHomePreferencesEvent(this.preferences);
}

class ResetHomePreferencesEvent extends HomePreferencesEvent {}

/// The active account changed: the home shows that tracker's own layout (#348).
class HomeTrackerChangedEvent extends HomePreferencesEvent {
  final AccountType tracker;
  HomeTrackerChangedEvent(this.tracker);
}

// State
class HomePreferencesState {
  final MalHomePreferences preferences;
  final bool isLoading;
  final String? error;
  
  HomePreferencesState({
    required this.preferences,
    this.isLoading = false,
    this.error,
  });

  HomePreferencesState copyWith({
    MalHomePreferences? preferences,
    bool? isLoading,
    String? error,
  }) {
    return HomePreferencesState(
      preferences: preferences ?? this.preferences,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// BLoC
/// The home layout of the active tracker. Owner rule (2026-10-29): each tracker is its own app,
/// so each keeps its own layout ([MalHomePreferences.storageKey]); given an [accounts] bloc, the
/// layout follows the selected account.
class HomePreferencesBloc extends Bloc<HomePreferencesEvent, HomePreferencesState> {
  HomePreferencesBloc({AccountBloc? accounts, AccountType? tracker})
      : _tracker = tracker ?? _selected(accounts?.state),
        super(HomePreferencesState(preferences: MalHomePreferences())) {
    on<LoadHomePreferencesEvent>(_onLoadPreferences);
    on<UpdateHomePreferencesEvent>(_onUpdatePreferences);
    on<ResetHomePreferencesEvent>(_onResetPreferences);
    on<HomeTrackerChangedEvent>(_onTrackerChanged);
    _accounts = accounts?.stream.listen((state) {
      final next = _selected(state);
      if (next != null && next != _tracker) add(HomeTrackerChangedEvent(next));
    });
  }

  AccountType? _tracker;
  StreamSubscription<AccountState>? _accounts;

  /// The tracker whose layout is shown; null before the accounts loaded (the shared layout).
  AccountType? get tracker => _tracker;

  static AccountType? _selected(AccountState? state) =>
      state is AccountLoaded && state.selectedAccountType != AccountType.none ? state.selectedAccountType : null;

  Future<void> _onTrackerChanged(HomeTrackerChangedEvent event, Emitter<HomePreferencesState> emit) async {
    _tracker = event.tracker;
    emit(state.copyWith(preferences: await MalHomePreferences.load(tracker: _tracker), isLoading: false));
  }

  @override
  Future<void> close() async {
    await _accounts?.cancel();
    return super.close();
  }

  Future<void> _onLoadPreferences(
    LoadHomePreferencesEvent event, 
    Emitter<HomePreferencesState> emit
  ) async {
    emit(state.copyWith(isLoading: true));
    
    try {
      final preferences = await MalHomePreferences.load(tracker: _tracker);
      emit(state.copyWith(
        preferences: preferences,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to load preferences: $e',
      ));
    }
  }

  Future<void> _onUpdatePreferences(
    UpdateHomePreferencesEvent event, 
    Emitter<HomePreferencesState> emit
  ) async {
    emit(state.copyWith(isLoading: true));
    
    try {
      await event.preferences.save(tracker: _tracker);
      emit(state.copyWith(
        preferences: event.preferences,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to save preferences: $e',
      ));
    }
  }

  Future<void> _onResetPreferences(
    ResetHomePreferencesEvent event, 
    Emitter<HomePreferencesState> emit
  ) async {
    emit(state.copyWith(isLoading: true));
    
    try {
      final preferences = MalHomePreferences()..reset();
      await preferences.save(tracker: _tracker);
      emit(state.copyWith(
        preferences: preferences,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to reset preferences: $e',
      ));
    }
  }
}