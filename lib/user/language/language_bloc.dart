import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/user/language/language_event.dart';
import 'package:mywatchlist/user/language/language_state.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  final SharedPreferences prefs;

  LanguageBloc({required this.prefs}) : super(const LanguageState.initial()) {
    on<LanguageLoadStarted>(_onLanguageLoadStarted);
    on<LanguageChanged>(_onLanguageChanged);
  }

  void _onLanguageLoadStarted(LanguageLoadStarted event, Emitter<LanguageState> emit) {
    final String languageCode = prefs.getString('language_code') ?? 'en';
    final bool useSystemLanguage = prefs.getBool('use_system_language') ?? false;
    
    emit(state.copyWith(
      languageCode: languageCode,
      useSystemLanguage: useSystemLanguage,
    ));
  }

  void _onLanguageChanged(LanguageChanged event, Emitter<LanguageState> emit) async {
    await prefs.setString('language_code', event.languageCode);
    await prefs.setBool('use_system_language', event.useSystemLanguage);

    final locale = event.useSystemLanguage 
        ? Locale(Intl.getCurrentLocale()) 
        : Locale(event.languageCode);
    
    await S.load(locale);
    
    emit(state.copyWith(
      languageCode: event.languageCode,
      useSystemLanguage: event.useSystemLanguage,
    ));
  }
}