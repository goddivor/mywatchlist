import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/settings/coming_soon_page.dart';

/// Weekly airing schedule (DAL `AnimeCalendarWidget`).
///
/// Stub created by the app shell; open it with `AppRoutes.openCalendar`. The calendar
/// unit replaces the body.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ComingSoonPage(
      title: S.current.AnimeCalendar,
      icon: Icons.calendar_month_outlined,
    );
  }
}
