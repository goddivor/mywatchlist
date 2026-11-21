import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_kind.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The catalogue the Simkl home and Explore tabs show, shared by both like the switch of
/// Simkl's own apps (TV shows first) and kept across runs (`simkl_catalogue`).
class SimklCatalogue extends ValueNotifier<SimklKind> {
  SimklCatalogue._() : super(SimklKind.tv);

  static final SimklCatalogue instance = SimklCatalogue._();

  static const String _key = 'simkl_catalogue';
  bool _loaded = false;

  /// Reads the saved catalogue once.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      final kind = SimklKind.values.where((k) => k.name == saved).firstOrNull;
      if (kind != null) value = kind;
    } catch (_) {
      // nothing saved: TV shows
    }
  }

  /// Tests: start on [kind] without reading the saved choice.
  @visibleForTesting
  void reset([SimklKind kind = SimklKind.tv]) {
    _loaded = true;
    value = kind;
  }

  void pick(SimklKind kind) {
    if (kind == value) return;
    value = kind;
    SharedPreferences.getInstance().then((p) => p.setString(_key, kind.name)).ignore();
  }
}

/// Translated name of a catalogue.
String simklKindLabel(SimklKind kind) => switch (kind) {
      SimklKind.tv => S.current.Skm_Shows,
      SimklKind.anime => S.current.UserList_Anime,
      SimklKind.movie => S.current.Skm_Movies,
    };

IconData simklKindIcon(SimklKind kind) => switch (kind) {
      SimklKind.tv => Icons.tv_rounded,
      SimklKind.anime => Icons.animation_rounded,
      SimklKind.movie => Icons.movie_outlined,
    };

/// TV shows / Anime / Movies, full width.
class SimklKindSwitch extends StatelessWidget {
  const SimklKindSwitch({super.key, required this.value, required this.onChanged});

  final SimklKind value;
  final ValueChanged<SimklKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 4, 15, 4),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: SegmentedButton<SimklKind>(
          segments: [
            for (final k in SimklKind.values)
              ButtonSegment(
                value: k,
                icon: Icon(simklKindIcon(k), size: 18),
                label: Text(simklKindLabel(k), maxLines: 1, softWrap: false),
              ),
          ],
          selected: {value},
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    );
  }
}
