import 'package:flutter/material.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';

/// Default colour of each list status slot (current, completed, on hold, dropped, planned),
/// DailyAL's status colours, used where the user's "stats chart colors" preference leaves the
/// theme colour. Screens use [themedStatusChartColors], which gives the shade of each hue that
/// reads on the current theme.
const List<Color> defaultStatusChartColors = [
  AppColors.watchingBase,
  AppColors.completedBase,
  AppColors.onHoldBase,
  AppColors.droppedBase,
  AppColors.plannedBase,
];

/// The status tones in the order of the chart slots and of `GeneralPreferences.statsChartColors`.
const List<ListStatusTone> statusChartTones = [
  ListStatusTone.watching,
  ListStatusTone.completed,
  ListStatusTone.onHold,
  ListStatusTone.dropped,
  ListStatusTone.planned,
];

/// The five status colours: the preference when the user picked one for the slot, the
/// default otherwise.
List<Color> statusChartColors(List<int> preference) {
  return [
    for (var i = 0; i < defaultStatusChartColors.length; i++)
      _slot(preference, i) ?? defaultStatusChartColors[i],
  ];
}

/// The five status colours for the current theme: the preference when the user picked one
/// for the slot, otherwise the list status token's mark colour (`AppColors.watching.color`…),
/// the same hues as the list status chips in the shade that keeps 3:1 on light, dark and
/// black cards.
List<Color> themedStatusChartColors(AppColors tokens, List<int> preference) {
  return [
    for (var i = 0; i < statusChartTones.length; i++)
      _slot(preference, i) ?? tokens.status(statusChartTones[i]).color,
  ];
}

Color? _slot(List<int> preference, int index) {
  if (index >= preference.length) return null;
  final value = preference[index];
  // `themeChartColor` is the "follow the theme" marker of the preferences contract.
  if (value == themeChartColor) return null;
  return Color(value);
}
