import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/MAL/content/videowidget.dart' show showYouTubeVideo;
import 'package:shared_preferences/shared_preferences.dart';

/// The "built-in YouTube player" switch of one tracker app (AniList, Kitsu, Simkl).
///
/// Each tracker is its own app: turning the player on in one tracker's settings leaves the
/// others as they are. MyAnimeList keeps its own switch (`GeneralPreferences.allowYoutubePlayer`).
/// Off by default, like MyAnimeList's. Saved as `embedded_youtube_<tracker>`.
class TrackerYoutubePlayer extends ValueNotifier<bool> {
  TrackerYoutubePlayer._(this.tracker) : super(false);

  final AccountType tracker;
  bool _loaded = false;

  static final Map<AccountType, TrackerYoutubePlayer> _all = {};

  /// The switch of [tracker].
  static TrackerYoutubePlayer of(AccountType tracker) =>
      _all.putIfAbsent(tracker, () => TrackerYoutubePlayer._(tracker));

  String get _key => 'embedded_youtube_${tracker.name}';

  /// Reads the saved choice once.
  Future<bool> ensureLoaded() async {
    if (_loaded) return value;
    _loaded = true;
    try {
      value = (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } catch (_) {
      // nothing saved: off
    }
    return value;
  }

  void set(bool on) {
    _loaded = true;
    if (on == value) return;
    value = on;
    SharedPreferences.getInstance().then((p) => p.setBool(_key, on)).ignore();
  }

  /// Tests: forget every tracker's choice.
  @visibleForTesting
  static void resetAll() => _all.clear();
}

/// Plays the trailer at [url] in the built-in player when [tracker] has it on, else runs
/// [outside] (the tracker's own way to open YouTube). A video its owner keeps off other sites
/// falls back to [outside] too.
Future<void> playTrackerTrailer(
  BuildContext context, {
  required String url,
  required AccountType tracker,
  required Future<void> Function() outside,
}) async {
  final on = await TrackerYoutubePlayer.of(tracker).ensureLoaded();
  if (!context.mounted) return;
  if (!on) return outside();
  return showYouTubeVideo(url: url, context: context, embedded: true, outside: outside);
}

/// The settings row of [tracker]'s built-in YouTube player.
class TrackerYoutubeSwitch extends StatefulWidget {
  const TrackerYoutubeSwitch({super.key, required this.tracker});

  final AccountType tracker;

  @override
  State<TrackerYoutubeSwitch> createState() => _TrackerYoutubeSwitchState();
}

class _TrackerYoutubeSwitchState extends State<TrackerYoutubeSwitch> {
  late final TrackerYoutubePlayer _player = TrackerYoutubePlayer.of(widget.tracker);

  @override
  void initState() {
    super.initState();
    _player.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: _player,
      builder: (context, on, _) => SwitchListTile(
        secondary: const Icon(Icons.smart_display_outlined),
        title: Text(s.Prefs_Youtube),
        subtitle: Text(s.Prefs_Youtube_Desc),
        value: on,
        onChanged: _player.set,
      ),
    );
  }
}
