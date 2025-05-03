import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/utils/mal_home_page_preferences.dart';

// Events
abstract class HomePreferencesEvent {}

class LoadHomePreferencesEvent extends HomePreferencesEvent {}

class UpdateHomePreferencesEvent extends HomePreferencesEvent {
  final MalHomePreferences preferences;
  
  UpdateHomePreferencesEvent(this.preferences);
}

class ResetHomePreferencesEvent extends HomePreferencesEvent {}

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
class HomePreferencesBloc extends Bloc<HomePreferencesEvent, HomePreferencesState> {
  HomePreferencesBloc() : super(HomePreferencesState(preferences: MalHomePreferences())) {
    on<LoadHomePreferencesEvent>(_onLoadPreferences);
    on<UpdateHomePreferencesEvent>(_onUpdatePreferences);
    on<ResetHomePreferencesEvent>(_onResetPreferences);
  }

  Future<void> _onLoadPreferences(
    LoadHomePreferencesEvent event, 
    Emitter<HomePreferencesState> emit
  ) async {
    emit(state.copyWith(isLoading: true));
    
    try {
      final preferences = await MalHomePreferences.load();
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
      await event.preferences.save();
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
      await preferences.save();
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