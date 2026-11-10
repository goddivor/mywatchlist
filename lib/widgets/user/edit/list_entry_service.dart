import 'dart:convert';

import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/models/my_anime_list_status.dart';
import 'package:mywatchlist/services/api/MAL/models/my_manga_list_status.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';

/// The list entry could not be loaded (HTTP error or unreadable answer).
class EntryLoadFailed implements Exception {
  final Object cause;
  const EntryLoadFailed(this.cause);
  @override
  String toString() => 'EntryLoadFailed: $cause';
}

/// Result of a list write: the new entry and the tracker status given as is
/// to `ContentEditWidget.onListStatusChange` (`MyAnimeListStatus` or
/// `MyMangaListStatus` for MAL, dates kept as MAL text).
class EntryUpdate {
  final ListEntry entry;
  final Object status;
  const EntryUpdate(this.entry, this.status);
}

/// Reads and writes the user's list entry on one tracker.
///
/// Every method may throw [MalSessionExpired] when the session is dead.
abstract class ListEntryService {
  /// False when the selected account cannot edit this list.
  bool get canEdit;

  Future<EditableContent> load(int id, {required bool isAnime});

  Future<EntryUpdate> update(int id,
      {required bool isAnime, required EntryPatch patch, ListEntry? previous});

  Future<void> delete(int id, {required bool isAnime});
}

/// [ListEntryService] on MyAnimeList, through [MalApi] (token refresh and
/// session-expired signal included).
class MalListEntryService implements ListEntryService {
  const MalListEntryService();

  // Every list field, so the sheet is pre-filled exactly as on MAL (the detail
  // page's MalAnime keeps only status, score, episodes and rewatching).
  static const String animeFields = 'id,num_episodes,status,start_date,'
      'start_season,my_list_status{status,score,num_episodes_watched,'
      'is_rewatching,num_times_rewatched,rewatch_value,priority,start_date,'
      'finish_date,tags,comments,updated_at}';
  static const String mangaFields = 'id,num_chapters,num_volumes,status,'
      'start_date,my_list_status{status,score,num_chapters_read,'
      'num_volumes_read,is_rereading,num_times_reread,reread_value,priority,'
      'start_date,finish_date,tags,comments,updated_at}';

  @override
  bool get canEdit =>
      AccountManagerSingleton().selectedAcc == AccountType.myanimelist;

  @override
  Future<EditableContent> load(int id, {required bool isAnime}) async {
    final base =
        isAnime ? Constants.malanimeEndPoint : Constants.malmangaEndPoint;
    final fields = isAnime ? animeFields : mangaFields;
    final response = await MalApi.authorizedGet('$base/$id?fields=$fields');
    // A dead session is replayed publicly: the answer then has no list
    // status, which would wrongly read as "not on the list".
    if (MalApi.sessionExpired.value) throw const MalSessionExpired();
    if (response.statusCode != 200) {
      throw EntryLoadFailed('HTTP ${response.statusCode}');
    }
    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return EditableContent.fromMalJson(data, isAnime: isAnime);
    } catch (e) {
      throw EntryLoadFailed(e);
    }
  }

  @override
  Future<EntryUpdate> update(int id,
      {required bool isAnime,
      required EntryPatch patch,
      ListEntry? previous}) async {
    // save*ListStatus sends the dates as given and answers the whole entry
    // with MAL's text dates, so a partial date (`2019-03`, `2019`) survives.
    final MyListStatus answer;
    if (isAnime) {
      answer = await MalApi().saveAnimeListStatus(
        animeId: id,
        status: patch.status,
        score: patch.score,
        numWatchedEpisodes: patch.progress,
        isRewatching: patch.isRepeating,
        numTimesRewatched: patch.timesRepeated,
        rewatchValue: patch.repeatValue,
        priority: patch.priority,
        startDate: patch.startDate,
        finishDate: patch.finishDate,
        tags: patch.tags,
        comments: patch.comments,
      );
    } else {
      answer = await MalApi().saveMangaListStatus(
        mangaId: id,
        status: patch.status,
        score: patch.score,
        numChaptersRead: patch.progress,
        numVolumesRead: patch.volumes,
        isRereading: patch.isRepeating,
        numTimesReread: patch.timesRepeated,
        rereadValue: patch.repeatValue,
        priority: patch.priority,
        startDate: patch.startDate,
        finishDate: patch.finishDate,
        tags: patch.tags,
        comments: patch.comments,
      );
    }
    return EntryUpdate(
      ListEntry.fromListStatus(answer, isAnime: isAnime, previous: previous),
      // Callers of onListStatusChange (detail page) expect the typed models.
      isAnime
          ? MyAnimeListStatus.fromListStatus(answer)
          : MyMangaListStatus.fromListStatus(answer),
    );
  }

  @override
  Future<void> delete(int id, {required bool isAnime}) => isAnime
      ? MalApi().deleteAnimeFromList(id)
      : MalApi().deleteMangaFromList(id);
}
