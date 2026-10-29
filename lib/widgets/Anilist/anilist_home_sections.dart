import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_forum_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_user_page.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_feeds_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_browse_screen.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_thread_tile.dart';
import 'package:mywatchlist/widgets/Anilist/home/anilist_following_preview.dart';
import 'package:mywatchlist/widgets/Anilist/home/anilist_home_cards.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumSkeleton;
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// The AniList query behind a home section of the shared home preferences, or null when
/// AniList has nothing for it (news and features are MyAnimeList's) or the section is drawn
/// by its own widget (user list, forum).
AnilistMediaQuery? anilistQueryFor(HomeSectionPreference section) {
  switch (section.type) {
    case SectionType.seasonNow:
      final season = section.season;
      final (currentSeason, currentYear) =
          AnilistDiscoverService.seasonOf(DateTime.now());
      return AnilistMediaQuery(
        category: 'anime',
        sort: 'POPULARITY_DESC',
        season: season == null ? currentSeason : season.name.toUpperCase(),
        seasonYear: section.year ?? currentYear,
      );
    case SectionType.suggested:
      return const AnilistMediaQuery(category: 'anime', sort: 'TRENDING_DESC');
    case SectionType.upcoming:
      return const AnilistMediaQuery(
          category: 'anime',
          sort: 'POPULARITY_DESC',
          status: 'NOT_YET_RELEASED');
    case SectionType.topScore:
      return const AnilistMediaQuery(category: 'anime', sort: 'SCORE_DESC');
    case SectionType.topFavorites:
      return const AnilistMediaQuery(
          category: 'anime', sort: 'FAVOURITES_DESC');
    case SectionType.topPopular:
      return const AnilistMediaQuery(
          category: 'anime', sort: 'POPULARITY_DESC');
    case SectionType.topAnimeAiring:
      return const AnilistMediaQuery(
          category: 'anime', sort: 'SCORE_DESC', status: 'RELEASING');
    case SectionType.topAnimeTV:
      return const AnilistMediaQuery(
          category: 'anime', sort: 'SCORE_DESC', formats: ['TV', 'TV_SHORT']);
    case SectionType.topAnimeMovie:
      return const AnilistMediaQuery(
          category: 'anime', sort: 'SCORE_DESC', formats: ['MOVIE']);
    case SectionType.topAnimeSpecial:
      return const AnilistMediaQuery(
          category: 'anime', sort: 'SCORE_DESC', formats: ['SPECIAL']);
    case SectionType.topManga:
      return const AnilistMediaQuery(category: 'manga', sort: 'SCORE_DESC');
    case SectionType.topMangaPopular:
      return const AnilistMediaQuery(
          category: 'manga', sort: 'POPULARITY_DESC');
    case SectionType.topAnimeOva:
      return const AnilistMediaQuery(
          category: 'anime', sort: 'SCORE_DESC', formats: ['OVA']);
    case SectionType.topAnimeOna:
      return const AnilistMediaQuery(
          category: 'anime', sort: 'SCORE_DESC', formats: ['ONA']);
    case SectionType.topMangaOnly:
      return const AnilistMediaQuery(
          category: 'manga',
          sort: 'SCORE_DESC',
          formats: ['MANGA'],
          country: 'JP');
    case SectionType.topMangaFavorites:
      return const AnilistMediaQuery(
          category: 'manga', sort: 'FAVOURITES_DESC');
    case SectionType.topOneshots:
      return const AnilistMediaQuery(
          category: 'manga', sort: 'SCORE_DESC', formats: ['ONE_SHOT']);
    case SectionType.topLightNovels:
      return const AnilistMediaQuery(
          category: 'manga',
          sort: 'SCORE_DESC',
          formats: ['NOVEL'],
          country: 'JP');
    case SectionType.topNovels:
      return const AnilistMediaQuery(
          category: 'manga', sort: 'POPULARITY_DESC', formats: ['NOVEL']);
    case SectionType.topManhwa:
      return const AnilistMediaQuery(
          category: 'manga', sort: 'SCORE_DESC', country: 'KR');
    case SectionType.topManhua:
      return const AnilistMediaQuery(
          category: 'manga', sort: 'SCORE_DESC', country: 'CN');
    // AniList has no doujinshi format.
    case SectionType.topDoujin:
    case SectionType.news:
    case SectionType.features:
    case SectionType.userList:
    case SectionType.forum:
      return null;
  }
}

/// Whether the AniList home draws [section] at all.
bool anilistShowsSection(HomeSectionPreference section) =>
    section.type == SectionType.userList ||
    section.type == SectionType.forum ||
    anilistQueryFor(section) != null;

/// What the AniList home asks in its one request: the media row of each section (by the
/// section's place in [sections]), and whether the recommendations, the forum, the
/// following feed and the birthdays are wanted.
@immutable
class AnilistHomePlan {
  AnilistHomePlan._(this.sections, this.rows, this.rowOf, this.signedIn);

  /// The sections drawn, in order.
  final List<HomeSectionPreference> sections;
  final List<AnilistRowRequest> rows;

  /// Index in [sections] -> index in [rows] (sections without a media row are absent).
  final Map<int, int> rowOf;
  final bool signedIn;

  /// The plan of the enabled [sections] AniList can draw. "Suggested" asks the
  /// recommendations of the user's list when [signedIn], and trending as its fallback.
  factory AnilistHomePlan.of(List<HomeSectionPreference> all, {required bool signedIn}) {
    final sections = [
      for (final s in all)
        if (s.enabled && anilistShowsSection(s)) s,
    ];
    final rows = <AnilistRowRequest>[];
    final rowOf = <int, int>{};
    for (var i = 0; i < sections.length; i++) {
      final query = anilistQueryFor(sections[i]);
      if (query == null) continue;
      rowOf[i] = rows.length;
      rows.add(AnilistRowRequest(query, sections[i].itemCount.clamp(1, 50)));
    }
    return AnilistHomePlan._(sections, rows, rowOf, signedIn);
  }

  bool get recommended => signedIn && sections.any((s) => s.type == SectionType.suggested);
  bool get forum => sections.any((s) => s.type == SectionType.forum);

  /// The shortest cache time the sections ask for (2 hours by default).
  Duration get maxAge {
    final hours = [for (final s in sections) s.cacheDurationHours];
    if (hours.isEmpty) return const Duration(hours: 2);
    return Duration(hours: hours.reduce((a, b) => a < b ? a : b).clamp(1, 48));
  }

  /// Changes whenever the request would change.
  String get key => [
        signedIn,
        recommended,
        forum,
        for (final r in rows) r.key,
      ].join('|');

  /// Loads the plan (one request; see [AnilistFeedsService.home]).
  Future<AnilistFeed> load(AnilistFeedsService service, {bool force = false}) => service.home(
        rows: rows,
        recommended: recommended,
        following: signedIn,
        forum: forum,
        birthdays: true,
        maxAge: maxAge,
        force: force,
      );
}

/// One section of the AniList home: a row of covers, the recommendations of the user's
/// list, the user's own list or the forum. Rows read their part of the home's single
/// request ([feed]); the user list reads the list the List tab keeps.
class AnilistHomeSection extends StatelessWidget {
  final HomeSectionPreference section;

  /// Index of this section's media row in the home request, null for the user list and the
  /// forum.
  final int? row;
  final AsyncSnapshot<AnilistFeed> feed;
  final double cardWidth;
  final double cardHeight;
  final int refresh;
  final VoidCallback onRetry;

  const AnilistHomeSection({
    super.key,
    required this.section,
    required this.feed,
    required this.onRetry,
    required this.cardWidth,
    required this.cardHeight,
    this.row,
    this.refresh = 0,
  });

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(vertical: 10);
    switch (section.type) {
      case SectionType.userList:
        return Padding(padding: padding, child: _userList(context));
      case SectionType.forum:
        return Padding(padding: padding, child: _forum(context));
      default:
        final query = anilistQueryFor(section);
        if (query == null) return const SizedBox.shrink();
        return Padding(padding: padding, child: _row(context, query));
    }
  }

  bool get _isSuggested => section.type == SectionType.suggested;

  String get _custom => section.customTitle ?? '';

  String _title({required bool recommended}) {
    if (_custom.isNotEmpty) return _custom;
    // "Suggested for you": the recommendations of the user's list, else what is trending.
    if (_isSuggested) {
      return recommended ? S.current.Ahx_Sec_Recommended : S.current.Al_Sec_Trending;
    }
    return section.getDisplayTitle();
  }

  Widget _loading() => anilistRowSkeleton(
        cardWidth: cardWidth,
        cardHeight: cardHeight,
        count: section.itemCount.clamp(1, 8),
      );

  /// The body of a part of the request: skeleton, error with Retry, or [builder].
  Widget _part(Widget Function(AnilistFeed feed) builder) {
    if (feed.hasError) return AnilistRowMessage(failed: true, onRetry: onRetry);
    final data = feed.data;
    if (data == null) return _loading();
    return builder(data);
  }

  Widget _row(BuildContext context, AnilistMediaQuery query) {
    final alias = row == null ? null : AnilistHomeParts.row(row!);
    final recommendations = _isSuggested
        ? feed.data?.recommendations(AnilistHomeParts.recommended, notOnList: true)
        : null;
    final showRecommended = recommendations != null && recommendations.isNotEmpty;
    final title = _title(recommended: showRecommended);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          onTap: showRecommended
              ? null
              : () => AppRoutes.push<void>(context, AnilistBrowseScreen(title: title, query: query)),
        ),
        _part((data) {
          if (showRecommended) {
            return AnilistRecommendedRow(
              items: recommendations.take(section.itemCount).toList(),
              cardWidth: cardWidth,
              cardHeight: cardHeight,
            );
          }
          final items = alias == null ? null : data.media(alias);
          if (items == null || items.isEmpty) {
            return AnilistRowMessage(failed: items == null, onRetry: onRetry);
          }
          return AnilistMediaCardRow(items: items, cardWidth: cardWidth, cardHeight: cardHeight);
        }),
      ],
    );
  }

  Widget _userList(BuildContext context) {
    final category = section.userCategory;
    final status = ListEntryStatus.fromMal(section.userStatus);
    final title = section.getDisplayTitle();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          onTap: () => AppRoutes.push<void>(
            context,
            AnilistPushedTab(title: title, child: const AnilistUserPage()),
          ),
        ),
        ListenableBuilder(
          listenable: UserManager.instance,
          builder: (context, _) {
            if (!UserManager.instance.isAuthenticated(AccountType.anilist)) {
              return HomeMessage(
                icon: Icons.person_outline_rounded,
                text: S.current.Al_Sign_In_List,
                actionLabel: S.current.Acc_Connect_Tracker,
                onAction: () => AppRoutes.openManageAccounts(context),
              );
            }
            return HomeAsync<List<AnilistMedia>>(
              cacheKey: 'al:userlist:$category:${status?.name ?? 'all'}:${section.itemCount}',
              maxAge: Duration(hours: section.cacheDurationHours),
              refresh: refresh,
              load: () => recentEntries(category, status, section.itemCount, force: refresh > 0),
              loading: _loading(),
              builder: (context, items) => items.isEmpty
                  ? HomeMessage(icon: Icons.inbox_outlined, text: S.current.Hw_Empty_List)
                  : AnilistMediaCardRow(items: items, cardWidth: cardWidth, cardHeight: cardHeight),
            );
          },
        ),
      ],
    );
  }

  /// The [count] entries of the user's list updated last, as cards.
  static Future<List<AnilistMedia>> recentEntries(
      String category, ListEntryStatus? status, int count,
      {bool force = false}) async {
    final all = await AnilistListService.instance.all(category, force: force);
    final entries = [
      for (final e in all)
        if (status == null || e.status == status) e,
    ]..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    return [
      for (final e in entries.take(count))
        AnilistMedia(
          id: e.id,
          malId: e.malId,
          category: e.category,
          title: e.title,
          coverUrl: e.imageUrl,
          score: e.meanScore,
        ),
    ];
  }

  Widget _forum(BuildContext context) {
    final title = _custom.isNotEmpty ? _custom : S.current.Al_Forum_Title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          onTap: () => openAnilistForumTab(context, title),
        ),
        if (feed.hasError)
          AnilistRowMessage(failed: true, onRetry: onRetry)
        else if (feed.data == null)
          const ForumSkeleton(count: 3)
        else
          Builder(builder: (context) {
            final threads = feed.data!.threads(AnilistHomeParts.forum);
            if (threads == null || threads.isEmpty) {
              return AnilistRowMessage(failed: threads == null, onRetry: onRetry);
            }
            return Column(
              children: [for (final t in threads.take(6)) AnilistThreadTile(thread: t)],
            );
          }),
      ],
    );
  }
}

/// Opens the AniList forum tab ([initialTab] 0 = Forum, 1 = Activity) as a page of its own,
/// with an app bar and a back button.
Future<void> openAnilistForumTab(BuildContext context, String title, {int initialTab = 0}) =>
    AppRoutes.push<void>(
      context,
      AnilistForumPage(initialTab: initialTab, standalone: true),
    );

/// The blocks of the AniList home that are not home settings sections: what the people the
/// user follows did (signed in), then today's birthdays. Each one hides when it has nothing.
class AnilistHomeExtras extends StatelessWidget {
  const AnilistHomeExtras({super.key, required this.feed, required this.signedIn});

  final AsyncSnapshot<AnilistFeed> feed;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final data = feed.data;
    if (data == null) return const SizedBox.shrink();
    final s = S.of(context);
    final following = signedIn ? data.activities(AnilistHomeParts.following) : null;
    final birthdays = [
      ...?data.people(AnilistHomeParts.birthdayCharacters, isStaff: false),
      ...?data.people(AnilistHomeParts.birthdayStaff, isStaff: true),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (following != null && following.isNotEmpty) ...[
          const SizedBox(height: 10),
          SectionHeader(
            title: s.Ahx_Sec_Following,
            onTap: () => openAnilistForumTab(context, s.Al_Forum_Title, initialTab: 1),
          ),
          AnilistFollowingPreview(items: following),
        ],
        if (birthdays.isNotEmpty) ...[
          const SizedBox(height: 10),
          SectionHeader(title: s.Ahx_Sec_Birthdays),
          AnilistPeopleRow(items: birthdays, showKind: true),
        ],
      ],
    );
  }
}
