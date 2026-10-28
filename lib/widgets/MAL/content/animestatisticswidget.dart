import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/charts/chart_palette.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';

/// List statuses of the members (official MAL API `statistics`): one bar per
/// status in the list status colours (theme tokens, or the colours picked in
/// the stats chart preference), share above, label and count below.
class AnimeStatisticsWidget extends StatelessWidget {
  final Statistics stats;
  const AnimeStatisticsWidget({required this.stats, super.key});

  static const double _maxBarHeight = 150;

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// The stats chart colours preference; none (theme colours) without the bloc (tests).
  static List<int> _chartPreference(BuildContext context) {
    if (Preferences.bloc == null) return const [];
    return context.select((PreferencesBloc b) => b.state.general.statsChartColors);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final compact = NumberFormat.compact(locale: locale);
    final percentFormat = NumberFormat.decimalPercentPattern(locale: locale, decimalDigits: 1);
    final status = stats.status;
    final colors = themedStatusChartColors(AppColors.of(context), _chartPreference(context));
    final bars = <(String, double, Color)>[
      (S.current.Res_Status_Watching, _toDouble(status.watching), colors[0]),
      (S.current.Res_Status_Completed, _toDouble(status.completed), colors[1]),
      (S.current.Res_Status_On_Hold, _toDouble(status.onHold), colors[2]),
      (S.current.Res_Status_Dropped, _toDouble(status.dropped), colors[3]),
      (S.current.Res_Status_Plan_To_Watch, _toDouble(status.planToWatch), colors[4]),
    ];
    final sum = bars.fold<double>(0, (a, b) => a + b.$2);
    if (sum == 0) {
      return SectionMessage(icon: Icons.bar_chart, message: S.current.No_Content);
    }
    final maxValue = bars.fold<double>(1, (m, b) => b.$2 > m ? b.$2 : m);
    final members = stats.numListUsers > 0 ? stats.numListUsers.toDouble() : sum;
    final small = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            height: _maxBarHeight + 76,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (label, value, color) in bars)
                  Expanded(
                    child: Semantics(
                      label: '$label: ${compact.format(value)}',
                      excludeSemantics: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(percentFormat.format(value / members), style: small),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: (value / maxValue * _maxBarHeight).clamp(2.0, _maxBarHeight),
                            width: 22,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 30,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          Text(compact.format(value), style: theme.textTheme.labelMedium),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            S.current.Res_Total_Members(NumberFormat.decimalPattern(locale).format(members)),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
