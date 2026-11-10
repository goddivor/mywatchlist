import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/sync_errors.dart';

/// The MyAnimeList end of a sync, in [SyncEntry] terms.
abstract class MalEntrySide {
  /// A MyAnimeList account is signed in (the sync needs it either way).
  bool get connected;

  /// The user's MAL entry; null when it is not on their list.
  Future<SyncEntry?> read(int malId, {required bool isAnime});

  Future<SyncEntry> write(int malId, SyncEntry entry, {required bool isAnime});
}

/// [MalEntrySide] over [MalApi] (token renewal and the session-expired signal
/// included): reads through the edit sheet's loader, writes through
/// `saveAnimeListStatus` / `saveMangaListStatus`.
class MalApiSide implements MalEntrySide {
  const MalApiSide();

  @override
  bool get connected =>
      UserManager.instance.isAuthenticated(AccountType.myanimelist);

  @override
  Future<SyncEntry?> read(int malId, {required bool isAnime}) async {
    try {
      final content =
          await const MalListEntryService().load(malId, isAnime: isAnime);
      final e = content.entry;
      return e == null ? null : fromListEntry(e, isAnime);
    } on MalSessionExpired {
      throw const SyncAuthRequired(AccountType.myanimelist);
    }
  }

  @override
  Future<SyncEntry> write(int malId, SyncEntry entry,
      {required bool isAnime}) async {
    final e = entry.compact();
    final score = e.score == null ? null : SyncScores.toMal(e.score!);
    try {
      final MyListStatus saved = isAnime
          ? await MalApi().saveAnimeListStatus(
              animeId: malId,
              status: e.status,
              score: score,
              numWatchedEpisodes: e.progress,
              numTimesRewatched: e.repeat,
              comments: e.notes,
              startDate: e.startDate,
              finishDate: e.finishDate,
            )
          : await MalApi().saveMangaListStatus(
              mangaId: malId,
              status: e.status,
              score: score,
              numChaptersRead: e.progress,
              numVolumesRead: e.volumes,
              numTimesReread: e.repeat,
              comments: e.notes,
              startDate: e.startDate,
              finishDate: e.finishDate,
            );
      return fromStatus(saved, isAnime);
    } on MalSessionExpired {
      throw const SyncAuthRequired(AccountType.myanimelist);
    }
  }

  static SyncEntry fromListEntry(ListEntry e, bool isAnime) => SyncEntry(
        status: e.status,
        score: e.score.toDouble(),
        progress: e.progress,
        volumes: isAnime ? null : e.volumes,
        startDate: e.startDate,
        finishDate: e.finishDate,
        repeat: e.timesRepeated,
        notes: e.comments,
      );

  static SyncEntry fromStatus(MyListStatus s, bool isAnime) => SyncEntry(
        status: s.status.isEmpty ? null : s.status,
        score: s.score.toDouble(),
        progress: isAnime ? s.numEpisodesWatched : s.numChaptersRead,
        volumes: isAnime ? null : s.numVolumesRead,
        startDate: s.startDate,
        finishDate: s.finishDate,
        repeat: isAnime ? s.numTimesRewatched : s.numTimesReread,
        notes: s.comments,
      );
}
