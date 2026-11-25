import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The status a title gets when it is added to the list of one tracker app (AniList, Kitsu,
/// Simkl), per category: the edit sheet of a title off the list opens on it.
///
/// Each tracker keeps its own choice (`default_add_status_<tracker>_<anime|manga>`). MyAnimeList
/// keeps its own settings (`ContentPreferences.defaultAnimeAddStatus` / `defaultMangaAddStatus`).
/// Until the user picks one, a title opens on "Plan to watch / read", as before.
abstract final class TrackerAddStatus {
  static const ListEntryStatus fallback = ListEntryStatus.planned;

  static final Map<String, ValueNotifier<ListEntryStatus>> _values = {};

  static String _key(AccountType tracker, bool anime) =>
      'default_add_status_${tracker.name}_${anime ? 'anime' : 'manga'}';

  /// The choice of [tracker] for [anime] or manga, to listen to.
  static ValueNotifier<ListEntryStatus> notifier(AccountType tracker, {required bool anime}) =>
      _values.putIfAbsent(_key(tracker, anime), () => ValueNotifier(fallback));

  /// The status a new [tracker] entry starts on.
  static ListEntryStatus of(AccountType tracker, {required bool anime}) =>
      notifier(tracker, anime: anime).value;

  /// Reads every saved choice (at launch, before any sheet opens).
  static Future<void> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final tracker in const [AccountType.anilist, AccountType.kitsu, AccountType.simkl]) {
        for (final anime in const [true, false]) {
          final saved = prefs.getString(_key(tracker, anime));
          final status = ListEntryStatus.values.where((s) => s.name == saved).firstOrNull;
          if (status != null) notifier(tracker, anime: anime).value = status;
        }
      }
    } catch (_) {
      // nothing saved: Plan to watch / read
    }
  }

  static void set(AccountType tracker, ListEntryStatus status, {required bool anime}) {
    final n = notifier(tracker, anime: anime);
    if (n.value == status) return;
    n.value = status;
    SharedPreferences.getInstance().then((p) => p.setString(_key(tracker, anime), status.name)).ignore();
  }

  /// Tests: forget every choice.
  @visibleForTesting
  static void resetAll() => _values.clear();
}

/// The settings row that picks [tracker]'s default status for [anime] or manga titles.
class TrackerAddStatusTile extends StatelessWidget {
  const TrackerAddStatusTile({
    super.key,
    required this.tracker,
    required this.anime,
    this.statuses = ListEntryStatus.values,
    this.title,
  });

  /// The row's title, "Status for added anime / manga" by default.
  final String? title;

  final AccountType tracker;
  final bool anime;

  /// The statuses the tracker offers.
  final List<ListEntryStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final name = title ?? (anime ? s.Prefs_Add_Anime : s.Prefs_Add_Manga);
    return ValueListenableBuilder<ListEntryStatus>(
      valueListenable: TrackerAddStatus.notifier(tracker, anime: anime),
      builder: (context, current, _) => ListTile(
        leading: const Icon(Icons.playlist_add_check),
        title: Text(name),
        subtitle: Text(current.label(isAnime: anime)),
        onTap: () async {
          final picked = await showDialog<ListEntryStatus>(
            context: context,
            builder: (context) => SimpleDialog(
              title: Text(name),
              children: [
                for (final st in statuses)
                  ListTile(
                    title: Text(st.label(isAnime: anime)),
                    trailing: st == current ? const Icon(Icons.check_rounded) : null,
                    onTap: () => Navigator.of(context).pop(st),
                  ),
              ],
            ),
          );
          if (picked != null) TrackerAddStatus.set(tracker, picked, anime: anime);
        },
      ),
    );
  }
}
