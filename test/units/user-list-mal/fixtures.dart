import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';

/// One MAL list item as `users/@me/animelist` answers it.
Map<String, dynamic> malAnimeItem({
  required int id,
  String title = 'Title',
  String status = 'watching',
  int score = 0,
  int watched = 0,
  int episodes = 12,
  String mediaType = 'tv',
  String airing = 'finished_airing',
  List<String> genres = const ['Action'],
  String updatedAt = '2026-10-01T10:00:00+00:00',
  int priority = 0,
  String? en,
  String? startDate = '2024-04-06',
}) =>
    {
      'node': {
        'id': id,
        'title': title,
        'main_picture': {
          'medium': 'https://cdn.myanimelist.net/images/anime/$id.jpg',
          'large': 'https://cdn.myanimelist.net/images/anime/${id}l.jpg',
        },
        'alternative_titles': {
          'synonyms': ['Syn $id'],
          'en': en ?? '',
          'ja': 'ジャ$id',
        },
        'mean': 8.1,
        'num_list_users': 1000 + id,
        'num_scoring_users': 500,
        'popularity': id,
        'status': airing,
        'media_type': mediaType,
        'genres': [
          for (var i = 0; i < genres.length; i++) {'id': i + 1, 'name': genres[i]},
        ],
        'start_date': startDate,
        'num_episodes': episodes,
        'broadcast': {'day_of_the_week': 'saturday', 'start_time': '23:30'},
      },
      'list_status': {
        'status': status,
        'score': score,
        'num_episodes_watched': watched,
        'is_rewatching': false,
        'updated_at': updatedAt,
        'priority': priority,
        'tags': ['fav'],
      },
    };

ListEntryView entry(
  int id, {
  String title = 'T',
  ListEntryStatus? status = ListEntryStatus.current,
  int score = 0,
  int progress = 0,
  int total = 12,
  String mediaType = 'tv',
  List<String> genres = const [],
  DateTime? updatedAt,
  ReleaseState release = ReleaseState.finished,
  int priority = 0,
  String category = 'anime',
}) =>
    ListEntryView(
      id: id,
      malId: id,
      category: category,
      title: title,
      status: status,
      score: score,
      progress: progress,
      total: total,
      mediaType: mediaType,
      genres: genres,
      updatedAt: updatedAt,
      releaseState: release,
      priority: priority,
    );

/// In-memory tracker: [lists] per status, served in pages; sorts like MAL.
class FakeListAdapter extends UserListAdapter {
  FakeListAdapter(this.all, {this.pageLimit = 1000});

  List<ListEntryView> all;
  final int pageLimit;
  final List<({ListEntryStatus? status, int offset, int limit, String? sort})> calls = [];
  Object? error;
  final List<(int, int)> steps = [];

  @override
  AccountType get tracker => AccountType.myanimelist;

  @override
  String? get owner => 'tester';

  @override
  int get maxPageSize => pageLimit;

  @override
  List<ListSortOption> sortOptions(String category) => standardSortOptions(isAnime: true);

  @override
  String? apiSort(String category, String sortKey, SortDirection direction) =>
      sortKey == ListSortKeys.updated && direction == SortDirection.descending
          ? 'list_updated_at'
          : null;

  @override
  Future<ListPage> fetch({
    required String category,
    required ListEntryStatus? status,
    required int offset,
    required int limit,
    String? apiSort,
  }) async {
    calls.add((status: status, offset: offset, limit: limit, sort: apiSort));
    if (error != null) throw error!;
    final matching = all.where((e) => status == null || e.status == status).toList();
    final page = matching.skip(offset).take(limit).toList();
    return ListPage(page, hasMore: offset + page.length < matching.length);
  }

  @override
  Future<Map<ListEntryStatus, int>?> statusCounts(String category) async => null;

  @override
  void open(BuildContext context, ListEntryView entry) {}

  @override
  Future<ListEditResult> edit(BuildContext context, ListEntryView entry) async =>
      const ListEditUnchanged();

  @override
  bool canStep(ListEntryView entry) => entry.status != null;

  @override
  Future<ListEntryView> step(ListEntryView entry, int delta) async {
    steps.add((entry.id, delta));
    return entry.copyWith(progress: entry.progress + delta);
  }

  @override
  Future<void> signInAgain(BuildContext context) async {}
}
