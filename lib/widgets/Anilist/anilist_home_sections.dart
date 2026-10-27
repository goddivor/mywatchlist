import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_forum_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_user_page.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_browse_screen.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_media_card.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_thread_tile.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumSkeleton;
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/loading/loadingcard.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// The AniList query behind a home section of the shared home preferences, or null when
/// AniList has nothing for it (news and features are MyAnimeList's) or the section is drawn
/// by its own widget (user list, forum).
AnilistMediaQuery? anilistQueryFor(HomeSectionPreference section) {
  switch (section.type) {
    case SectionType.seasonNow:
      final season = section.season;
      final (currentSeason, currentYear) = AnilistDiscoverService.seasonOf(DateTime.now());
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
          category: 'anime', sort: 'POPULARITY_DESC', status: 'NOT_YET_RELEASED');
    case SectionType.topScore:
      return const AnilistMediaQuery(category: 'anime', sort: 'SCORE_DESC');
    case SectionType.topFavorites:
      return const AnilistMediaQuery(category: 'anime', sort: 'FAVOURITES_DESC');
    case SectionType.topPopular:
      return const AnilistMediaQuery(category: 'anime', sort: 'POPULARITY_DESC');
    case SectionType.topAnimeAiring:
      return const AnilistMediaQuery(category: 'anime', sort: 'SCORE_DESC', status: 'RELEASING');
    case SectionType.topAnimeTV:
      return const AnilistMediaQuery(
          category: 'anime', sort: 'SCORE_DESC', formats: ['TV', 'TV_SHORT']);
    case SectionType.topAnimeMovie:
      return const AnilistMediaQuery(category: 'anime', sort: 'SCORE_DESC', formats: ['MOVIE']);
    case SectionType.topAnimeSpecial:
      return const AnilistMediaQuery(
          category: 'anime', sort: 'SCORE_DESC', formats: ['SPECIAL']);
    case SectionType.topManga:
      return const AnilistMediaQuery(category: 'manga', sort: 'SCORE_DESC');
    case SectionType.topMangaPopular:
      return const AnilistMediaQuery(category: 'manga', sort: 'POPULARITY_DESC');
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

/// One section of the AniList home: a row of covers, the user's list or the forum.
class AnilistHomeSection extends StatelessWidget {
  final HomeSectionPreference section;
  final double cardWidth;
  final double cardHeight;
  final int refresh;

  const AnilistHomeSection({
    super.key,
    required this.section,
    required this.cardWidth,
    required this.cardHeight,
    this.refresh = 0,
  });

  @override
  Widget build(BuildContext context) {
    final padding = const EdgeInsets.symmetric(vertical: 10);
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

  String get _title {
    final custom = section.customTitle;
    if (custom != null && custom.isNotEmpty) return custom;
    // "Suggested for you" has no AniList meaning: the row shows what is trending.
    if (section.type == SectionType.suggested) return S.current.Al_Sec_Trending;
    return section.getDisplayTitle();
  }

  Widget _loading() => loadingCardList(
        containerHeight: cardHeight,
        height: cardHeight,
        width: cardWidth,
        itemCount: section.itemCount,
        listPadding: const EdgeInsets.all(8),
      );

  Widget _row(BuildContext context, AnilistMediaQuery query) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: _title,
          onTap: () => AppRoutes.push<void>(
              context, AnilistBrowseScreen(title: _title, query: query)),
        ),
        HomeAsync<List<AnilistMedia>>(
          cacheKey: 'al:${query.key}:${section.itemCount}',
          maxAge: Duration(hours: section.cacheDurationHours),
          refresh: refresh,
          load: () async => (await AnilistDiscoverService.instance
                  .media(query, perPage: section.itemCount.clamp(1, 50)))
              .items,
          loading: _loading(),
          builder: (context, items) => items.isEmpty
              ? HomeMessage(icon: Icons.inbox_outlined, text: S.current.Hw_Empty_Items)
              : AnilistMediaRow(items: items, cardWidth: cardWidth, cardHeight: cardHeight),
        ),
      ],
    );
  }

  Widget _userList(BuildContext context) {
    final category = section.userCategory;
    final status = ListEntryStatus.fromMal(section.userStatus);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: section.getDisplayTitle(),
          onTap: () => AppRoutes.push<void>(
            context,
            Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: const AnilistUserPage(),
            ),
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
              load: () => recentEntries(category, status, section.itemCount,
                  force: refresh > 0),
              loading: _loading(),
              builder: (context, items) => items.isEmpty
                  ? HomeMessage(icon: Icons.inbox_outlined, text: S.current.Hw_Empty_List)
                  : AnilistMediaRow(items: items, cardWidth: cardWidth, cardHeight: cardHeight),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: _forumTitle,
          onTap: () => AppRoutes.push<void>(
            context,
            Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: const AnilistForumPage(),
            ),
          ),
        ),
        HomeAsync<List<AnilistThread>>(
          cacheKey: 'al:forum',
          maxAge: Duration(hours: section.cacheDurationHours),
          refresh: refresh,
          load: () async => (await AnilistDiscoverService.instance.threads(perPage: 8)).items,
          loading: const ForumSkeleton(count: 3),
          builder: (context, threads) {
            if (threads.isEmpty) {
              return HomeMessage(
                  icon: Icons.forum_outlined, text: S.current.Fc_Topics_Empty_Title);
            }
            return Column(
              children: [for (final t in threads.take(6)) AnilistThreadTile(thread: t)],
            );
          },
        ),
      ],
    );
  }

  String get _forumTitle {
    final custom = section.customTitle;
    return custom != null && custom.isNotEmpty ? custom : S.current.Al_Forum_Title;
  }
}
