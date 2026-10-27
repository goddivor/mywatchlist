import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';

/// Keeps the status bar and the navigation bar readable on every screen, including the ones
/// without an app bar (an `AppBar` sets the same style through `AppBarTheme.systemOverlayStyle`).
///
/// Follows the theme mode and, in 'auto', the device's light/dark switch.
class SystemBars with WidgetsBindingObserver {
  SystemBars._();

  static final SystemBars instance = SystemBars._();

  ThemeState? _state;
  bool _observing = false;
  bool _edgeToEdge = false;

  /// Applies the style of [state] now and whenever the device brightness changes.
  void follow(ThemeState state) {
    _state = state;
    final binding = _binding;
    if (binding == null) return;
    if (!_observing) {
      binding.addObserver(this);
      _observing = true;
    }
    if (!_edgeToEdge) {
      _edgeToEdge = true;
      // Android 15+ always draws edge to edge; older versions do the same so the transparent
      // bars look identical everywhere.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _apply();
  }

  /// The style for [state] on a device in [platformBrightness] (pure, for tests).
  static SystemUiOverlayStyle styleFor(ThemeState state, Brightness platformBrightness) =>
      AppThemes.systemOverlayStyle(state.brightnessFor(platformBrightness));

  @override
  void didChangePlatformBrightness() => _apply();

  void _apply() {
    final state = _state;
    final binding = _binding;
    if (state == null || binding == null) return;
    SystemChrome.setSystemUIOverlayStyle(
      styleFor(state, binding.platformDispatcher.platformBrightness),
    );
  }

  static WidgetsBinding? get _binding {
    try {
      return WidgetsBinding.instance;
    } catch (_) {
      return null; // No binding yet (pure Dart tests).
    }
  }
}
