import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/header/next_episode.dart';

/// DailyAL's countdown of the next episode, above the genres of the synopsis: a card with
/// "Ep 20 in 06d · 06h · 49m · 29s", ticking every second. For half an hour after the episode
/// airs it says "Currently airing"; then it goes. Unlike DailyAL it has no close button.
class NextEpisodeCard extends StatefulWidget {
  const NextEpisodeCard({super.key, required this.episode, this.now = DateTime.now});

  final NextEpisode episode;

  /// Clock; tests replace it.
  final DateTime Function() now;

  /// How long "Currently airing" shows after the episode aired.
  static const Duration airingWindow = Duration(minutes: 30);

  @override
  State<NextEpisodeCard> createState() => _NextEpisodeCardState();
}

class _NextEpisodeCardState extends State<NextEpisodeCard> {
  Timer? _timer;
  late Duration _left;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_update);
      if (-_left > NextEpisodeCard.airingWindow) _timer?.cancel();
    });
  }

  @override
  void didUpdateWidget(NextEpisodeCard old) {
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
    final aired = _left.isNegative || _left == Duration.zero;
    if (aired && -_left > NextEpisodeCard.airingWindow) return const SizedBox.shrink();
    final s = S.of(context);
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium;
    final muted = base?.copyWith(color: base.color?.withValues(alpha: 0.7), fontSize: 13);
    final prefix = Text.rich(
      TextSpan(
        text: '${s.Dc_Ep} ',
        style: muted,
        children: [
          TextSpan(text: '${widget.episode.episode}', style: base),
          if (!aired) TextSpan(text: ' ${s.Dc_In}'),
        ],
      ),
    );
    final time = aired ? '' : dalCountdown(_left);
    return Semantics(
      label: aired ? '${s.Dc_Ep} ${widget.episode.episode}, ${s.Dc_Airing_Now}' : s.Dc_Label(widget.episode.episode, time),
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              prefix,
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  aired ? s.Dc_Airing_Now : time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: aired
                      ? base?.copyWith(color: Colors.green, fontWeight: FontWeight.w600)
                      : base?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "06d · 06h · 49m · 29s" (DailyAL's): two digits per unit, the empty leading units left out,
/// the seconds always there.
String dalCountdown(Duration left) {
  final s = S.current;
  String two(int v) => v.toString().padLeft(2, '0');
  final days = left.inDays;
  final hours = left.inHours % 24;
  final minutes = left.inMinutes % 60;
  final seconds = left.inSeconds % 60;
  return [
    if (days > 0) s.Dc_Days(two(days)),
    if (hours > 0) s.Dc_Hours(two(hours)),
    if (minutes > 0) s.Dc_Minutes(two(minutes)),
    s.Dc_Seconds(two(seconds)),
  ].join(' · ');
}
