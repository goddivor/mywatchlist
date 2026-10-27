import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/header/next_episode.dart';

/// "Ep. 5 · 2d 3h 10m": time left before [episode] airs, as a small pill.
/// Only this widget rebuilds each second; it disappears when the episode has
/// aired (the page keeps its layout: the header reserves the row).
class CountdownChip extends StatefulWidget {
  final NextEpisode episode;

  /// Clock; tests replace it.
  final DateTime Function() now;

  const CountdownChip({super.key, required this.episode, this.now = DateTime.now});

  @override
  State<CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<CountdownChip> {
  Timer? _timer;
  late Duration _left;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_update);
    });
  }

  @override
  void didUpdateWidget(CountdownChip old) {
    super.didUpdateWidget(old);
    if (old.episode != widget.episode) _update();
  }

  void _update() => _left = widget.episode.airingAt.difference(widget.now());

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_left.isNegative || _left == Duration.zero) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final label = '${S.current.Dh_Episode_Short(widget.episode.episode)} · ${formatCountdown(_left)}';
    return Semantics(
      label: '${S.current.Dh_Next_Episode}: $label',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 16, color: scheme.onSecondaryContainer),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "2d 3h 10m 5s", leaving out the leading zero units (seconds always shown).
String formatCountdown(Duration left) {
  final s = S.current;
  final days = left.inDays;
  final hours = left.inHours % 24;
  final minutes = left.inMinutes % 60;
  final seconds = left.inSeconds % 60;
  return [
    if (days > 0) s.Dh_Time_Days(days),
    if (days > 0 || hours > 0) s.Dh_Time_Hours(hours),
    if (days > 0 || hours > 0 || minutes > 0) s.Dh_Time_Minutes(minutes),
    s.Dh_Time_Seconds(seconds),
  ].join(' ');
}
