import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';

/// Whether scores are hidden by the user's "Hide score" preference
/// (`content.hideScore`). Rebuilds the caller when the preference changes;
/// without a [PreferencesBloc] above (tests, isolated widgets) it reads
/// [Preferences.current].
bool scoreHiddenOf(BuildContext context) {
  try {
    return context.select((PreferencesBloc bloc) => bloc.state.content.hideScore);
  } on ProviderNotFoundException {
    return Preferences.content.hideScore;
  }
}

/// Shows [child] (a score) normally, or, when scores are hidden, an eye icon
/// that reveals this one score on tap for [revealFor] (DailyAL tap-to-reveal).
/// Tapping a revealed score hides it again at once.
///
/// [hidden] forces the state; leave it null to follow the preference
/// ([scoreHiddenOf]). [revealFor] = [Duration.zero] keeps the score shown until
/// the next tap.
///
/// ```dart
/// ScoreReveal(child: starField(mean.toStringAsFixed(2)))
/// ```
class ScoreReveal extends StatefulWidget {
  final Widget child;
  final bool? hidden;
  final Duration revealFor;
  final double iconSize;
  final Color? iconColor;

  const ScoreReveal({
    super.key,
    required this.child,
    this.hidden,
    this.revealFor = const Duration(seconds: 3),
    this.iconSize = 16,
    this.iconColor,
  });

  @override
  State<ScoreReveal> createState() => _ScoreRevealState();
}

class _ScoreRevealState extends State<ScoreReveal> {
  bool _revealed = false;
  Timer? _timer;

  void _toggle() {
    _timer?.cancel();
    setState(() => _revealed = !_revealed);
    if (_revealed && widget.revealFor > Duration.zero) {
      _timer = Timer(widget.revealFor, () {
        if (mounted) setState(() => _revealed = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = widget.hidden ?? scoreHiddenOf(context);
    if (!hidden) return widget.child;
    final color = widget.iconColor ?? IconTheme.of(context).color?.withValues(alpha: 0.6);
    return Semantics(
      button: true,
      label: _revealed ? S.current.Kit_Hide_Score : S.current.Kit_Show_Score,
      excludeSemantics: !_revealed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _revealed
              ? KeyedSubtree(key: const ValueKey(true), child: widget.child)
              : Padding(
                  key: const ValueKey(false),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.visibility_off_outlined, size: widget.iconSize, color: color),
                ),
        ),
      ),
    );
  }
}
