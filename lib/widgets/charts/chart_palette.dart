import 'package:flutter/material.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';

/// Default colour of each list status slot (current, completed, on hold, dropped, planned),
/// DailyAL's status colours, used where the user's "stats chart colors" preference leaves the
/// theme colour.
const List<Color> defaultStatusChartColors = [
  AppColors.watchingBase,
  AppColors.completedBase,
  AppColors.onHoldBase,
  AppColors.droppedBase,
  AppColors.plannedBase,
];

/// The five status colours: the preference when the user picked one for the slot, the
/// default otherwise.
List<Color> statusChartColors(List<int> preference) {
  return [
    for (var i = 0; i < defaultStatusChartColors.length; i++)
      _slot(preference, i) ?? defaultStatusChartColors[i],
  ];
}

Color? _slot(List<int> preference, int index) {
  if (index >= preference.length) return null;
  final value = preference[index];
  // `themeChartColor` is the "follow the theme" marker of the preferences contract.
  if (value == themeChartColor) return null;
  return Color(value);
}

/// A lighter shade of [color], for the top of a gradient bar.
Color lighten(Color color, [double amount = 0.3]) =>
    Color.lerp(color, Colors.white, amount) ?? color;
