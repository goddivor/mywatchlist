import 'package:flutter/widgets.dart';

/// Material 3 window size classes, by window width in logical pixels.
enum ScreenSize {
  /// Under 600: phones in portrait.
  compact,

  /// 600 to 839: small tablets, foldables, phones in landscape.
  medium,

  /// 840 to 1199: tablets in landscape.
  expanded,

  /// 1200 and more: desktops.
  large;

  /// Classifies a window [width].
  static ScreenSize fromWidth(double width) {
    if (width < 600) return ScreenSize.compact;
    if (width < 840) return ScreenSize.medium;
    if (width < 1200) return ScreenSize.expanded;
    return ScreenSize.large;
  }

  /// The size class of the current window. Depends only on the window size
  /// (`MediaQuery.sizeOf`), so keyboard or padding changes do not rebuild.
  static ScreenSize of(BuildContext context) => fromWidth(MediaQuery.sizeOf(context).width);

  /// True from [medium] up (tablet layouts, navigation rail, two panes).
  bool get isTablet => index >= ScreenSize.medium.index;
}

/// Picks a value for the current [ScreenSize]; a missing size falls back to
/// the next smaller one given.
///
/// ```dart
/// final columns = adaptiveValue(context, compact: 3, medium: 4, expanded: 6);
/// ```
T adaptiveValue<T>(BuildContext context, {required T compact, T? medium, T? expanded, T? large}) {
  return switch (ScreenSize.of(context)) {
    ScreenSize.compact => compact,
    ScreenSize.medium => medium ?? compact,
    ScreenSize.expanded => expanded ?? medium ?? compact,
    ScreenSize.large => large ?? expanded ?? medium ?? compact,
  };
}

/// Builds a different layout per [ScreenSize]; a missing builder falls back to
/// the next smaller one given. Only the chosen builder runs.
///
/// ```dart
/// AdaptiveLayout(
///   compact: (context) => const DetailPage(),
///   expanded: (context) => const Row(children: [ListPane(), DetailPane()]),
/// )
/// ```
class AdaptiveLayout extends StatelessWidget {
  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder? expanded;
  final WidgetBuilder? large;

  const AdaptiveLayout({super.key, required this.compact, this.medium, this.expanded, this.large});

  @override
  Widget build(BuildContext context) {
    final builder = adaptiveValue<WidgetBuilder>(
      context,
      compact: compact,
      medium: medium,
      expanded: expanded,
      large: large,
    );
    return builder(context);
  }
}
