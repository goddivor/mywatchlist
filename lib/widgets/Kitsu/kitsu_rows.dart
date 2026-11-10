import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_open.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_entry_sheet.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_my_library.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_rating.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_unit_sheet.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_feed.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuFeedPost, KitsuMediaKind, KitsuReaction;
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart' show KitsuMedia;
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_feed_parts.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart' show Anime;
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Whether the Kitsu home can draw [section]: a catalogue row, the user's list or the Kitsu news.
bool kitsuSectionSupported(HomeSectionPreference section) =>
    kitsuQueryForSection(section) != null ||
    section.type == SectionType.userList ||
    section.type == SectionType.news;

/// The Kitsu search that fills a home section of the user's home layout, or null when Kitsu has
/// no equivalent (features, suggestions, forum) or the section is not a catalogue row (the user's own list,
/// the news, which come from the Kitsu News Network group).
KitsuMediaQuery? kitsuQueryForSection(HomeSectionPreference section) {
  KitsuMediaQuery anime(
          {Map<String, String> filters = const {}, String? sort}) =>
      KitsuMediaQuery(isAnime: true, filters: filters, sort: sort);
  KitsuMediaQuery manga(
          {Map<String, String> filters = const {}, String? sort}) =>
      KitsuMediaQuery(isAnime: false, filters: filters, sort: sort);

  switch (section.type) {
    case SectionType.seasonNow:
      return anime(filters: {
        'season': section.effectiveSeason.name.toLowerCase(),
        'seasonYear': '${section.effectiveYear}',
      }, sort: '-userCount');
    case SectionType.upcoming:
      return anime(filters: {'status': 'upcoming'}, sort: '-userCount');
    case SectionType.topScore:
      return anime(sort: 'ratingRank');
    case SectionType.topFavorites:
      return anime(sort: '-favoritesCount');
    case SectionType.topPopular:
      return anime(sort: 'popularityRank');
    case SectionType.topAnimeAiring:
      return anime(filters: {'status': 'current'}, sort: '-userCount');
    case SectionType.topAnimeTV:
      return anime(filters: {'subtype': 'TV'}, sort: 'ratingRank');
    case SectionType.topAnimeMovie:
      return anime(filters: {'subtype': 'movie'}, sort: 'ratingRank');
    case SectionType.topAnimeSpecial:
      return anime(filters: {'subtype': 'special'}, sort: 'ratingRank');
    case SectionType.topManga:
      return manga(sort: 'ratingRank');
    case SectionType.topMangaPopular:
      return manga(sort: 'popularityRank');
    case SectionType.topAnimeOva:
      return anime(filters: {'subtype': 'OVA'}, sort: 'ratingRank');
    case SectionType.topAnimeOna:
      return anime(filters: {'subtype': 'ONA'}, sort: 'ratingRank');
    case SectionType.topMangaOnly:
      return manga(filters: {'subtype': 'manga'}, sort: 'ratingRank');
    case SectionType.topMangaFavorites:
      return manga(sort: '-favoritesCount');
    case SectionType.topOneshots:
      return manga(filters: {'subtype': 'oneshot'}, sort: 'ratingRank');
    case SectionType.topDoujin:
      return manga(filters: {'subtype': 'doujin'}, sort: 'ratingRank');
    // Kitsu has one `novel` subtype for light novels and novels alike.
    case SectionType.topLightNovels:
    case SectionType.topNovels:
      return manga(filters: {'subtype': 'novel'}, sort: 'ratingRank');
    case SectionType.topManhwa:
      return manga(filters: {'subtype': 'manhwa'}, sort: 'ratingRank');
    case SectionType.topManhua:
      return manga(filters: {'subtype': 'manhua'}, sort: 'ratingRank');
    case SectionType.news:
    case SectionType.suggested:
    case SectionType.features:
    case SectionType.userList:
    case SectionType.forum:
      return null;
  }
}

/// The tile model of a list entry: Kitsu's own title, mapped to MyAnimeList or not.
KitsuMedia kitsuEntryToMedia(ListEntryView entry) => KitsuMedia(
      id: entry.id,
      isAnime: entry.isAnime,
      title: entry.title,
      posterUrl: entry.imageUrl ?? entry.largeImageUrl,
      largePosterUrl: entry.largeImageUrl ?? entry.imageUrl,
      subtype: entry.mediaType,
      releaseState: entry.releaseState,
      meanScore: entry.meanScore,
      userCount: entry.members ?? 0,
      popularityRank: entry.popularity,
      total: entry.total,
      totalVolumes: entry.totalVolumes,
      startDate: entry.releaseStart,
      endDate: entry.releaseEnd,
      malId: entry.malId,
    );

/// The home-card model of a list entry; null when Kitsu maps its title to no MyAnimeList page.
Anime? kitsuEntryToAnime(ListEntryView entry) {
  final mal = entry.malId;
  if (mal == null) return null;
  return Anime(
    id: mal,
    title: entry.title,
    imageUrl: entry.largeImageUrl ?? entry.imageUrl ?? '',
    score: entry.meanScore ?? 0,
    members: entry.members ?? 0,
    popularity: entry.popularity,
    numEpisodes: entry.isAnime ? entry.total : null,
    numVolumes: entry.totalVolumes == 0 ? null : entry.totalVolumes,
    startDate: entry.releaseStart,
    endDate: entry.releaseEnd,
    mediaType: entry.mediaType,
  );
}

/// The "News" row of the home: the latest posts of the Kitsu News Network group as cards, each
/// opening its thread. Draws nothing when the group answers nothing, since a failing bonus row
/// would only be noise; "View all" opens the whole news feed.
class KitsuNewsRow extends StatelessWidget {
  final String title;
  final int limit;
  final Duration maxAge;
  final int refresh;
  final KitsuFeed? feed;
  final void Function(KitsuFeedPost post) onOpenPost;
  final VoidCallback? onViewAll;

  const KitsuNewsRow({
    super.key,
    required this.title,
    required this.onOpenPost,
    this.limit = 10,
    this.maxAge = const Duration(hours: 1),
    this.refresh = 0,
    this.feed,
    this.onViewAll,
  });

  static const double cardWidth = 290;
  static const double cardHeight = 150;

  @override
  Widget build(BuildContext context) {
    Widget section(Widget body) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [SectionHeader(title: title, onTap: onViewAll), body],
          ),
        );
    final count = limit.clamp(1, 20);
    return HomeAsync<List<KitsuFeedPost>>(
      cacheKey: 'kitsu:news:$count',
      maxAge: maxAge,
      refresh: refresh,
      load: () async {
        try {
          return await (feed ?? KitsuFeed()).newsPosts(limit: count);
        } catch (_) {
          return const <KitsuFeedPost>[];
        }
      },
      loading: section(const SizedBox(height: cardHeight)),
      builder: (context, posts) => posts.isEmpty
          ? const SizedBox.shrink()
          : section(SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: posts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, i) =>
                    KitsuNewsCard(post: posts[i], onTap: () => onOpenPost(posts[i])),
              ),
            )),
    );
  }
}

/// One news post in the home row: author and time, then the first lines of text.
class KitsuNewsCard extends StatelessWidget {
  final KitsuFeedPost post;
  final VoidCallback onTap;

  const KitsuNewsCard({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = post.user;
    return SizedBox(
      width: KitsuNewsRow.cardWidth,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KitsuByline(
                  name: user?.name ?? '?',
                  avatarUrl: user?.avatarUrl,
                  at: post.createdAt,
                  nsfw: post.isNsfw,
                  avatarSize: 30,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRect(
                    child: KitsuGuardedBody(
                      text: post.content,
                      isSpoiler: post.isSpoiler,
                      isNsfw: post.isNsfw,
                      maxLines: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kitsu's Quick update, first on the home of a signed-in user: one card per title being
/// watched (or read), last updated first, with the next episode's picture and title, the
/// progress, a "✓ Episode N" button (Complete on the last one, then the rating) and the
/// episode's discussion behind the picture. Draws nothing when the list is empty or unreadable.
class KitsuQuickUpdateRow extends StatefulWidget {
  final KitsuMediaKind kind;
  final int refresh;
  final KitsuMyLibrary? service;

  const KitsuQuickUpdateRow({super.key, this.kind = KitsuMediaKind.anime, this.refresh = 0, this.service});

  static const double cardWidth = 260;

  @override
  State<KitsuQuickUpdateRow> createState() => _KitsuQuickUpdateRowState();
}

class _KitsuQuickUpdateRowState extends State<KitsuQuickUpdateRow> {
  List<KitsuMyEntry>? _entries;
  final Set<String> _busy = {};
  int _token = 0;

  KitsuMyLibrary get _service => widget.service ?? KitsuMyLibrary.instance;
  bool get _anime => widget.kind == KitsuMediaKind.anime;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant KitsuQuickUpdateRow old) {
    super.didUpdateWidget(old);
    if (old.refresh != widget.refresh || old.kind != widget.kind) _load();
  }

  Future<void> _load() async {
    final token = ++_token;
    List<KitsuMyEntry> found;
    try {
      found = await _service.currentEntries(kind: widget.kind);
    } catch (_) {
      found = const [];
    }
    if (mounted && token == _token) setState(() => _entries = found);
  }

  void _replace(KitsuMyEntry old, KitsuMyEntry? now) {
    final list = [...?_entries];
    final i = list.indexWhere((e) => e.id == old.id);
    if (i < 0) return;
    if (now == null || now.status != ListEntryStatus.current) {
      list.removeAt(i);
    } else {
      list[i] = now;
    }
    setState(() => _entries = list);
  }

  Future<void> _mark(KitsuMyEntry e) async {
    if (_busy.contains(e.id)) return;
    final next = e.progress + 1;
    final last = e.total > 0 && next >= e.total;
    setState(() => _busy.add(e.id));
    KitsuMyEntry? saved;
    try {
      saved = await _service.update(e.id, progress: next, status: last ? ListEntryStatus.completed : null);
    } catch (_) {
      saved = null;
    }
    if (!mounted) return;
    setState(() => _busy.remove(e.id));
    if (saved == null) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(S.current.Kr_Save_Failed)));
      return;
    }
    if (last) {
      _replace(e, null);
      final picked = await showKitsuRatingSheet(context, title: S.current.Kr_Completed_Rate);
      if (picked != null && picked > 0) {
        try {
          await _service.update(e.id, rating: picked);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.maybeOf(context)
              ?..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(S.current.Kr_Save_Failed)));
          }
        }
      }
      return;
    }
    // The answer carries the following episode, picture included.
    _replace(e, saved.media == null
        ? KitsuMyEntry(
            id: saved.id,
            status: saved.status,
            progress: saved.progress,
            rating: saved.rating,
            reaction: saved.reaction,
            nextUnit: saved.nextUnit,
            media: e.media,
            banner: e.banner,
            total: e.total,
          )
        : saved);
  }

  Future<void> _edit(KitsuMyEntry e) async {
    final media = e.media!;
    final result = await showKitsuEntrySheet(
      context,
      kind: media.kind,
      mediaId: media.id,
      title: media.titles.display,
      total: e.total,
      initial: e,
      service: _service,
    );
    if (result == null || !mounted) return;
    _load();
  }

  void _openUnit(KitsuMyEntry e) {
    final unit = e.nextUnit;
    final media = e.media!;
    if (unit == null) {
      openKitsuTitle(context, kind: media.kind, id: media.id, slug: media.slug, title: media.titles.display, posterUrl: media.poster?.url);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => KitsuUnitDiscussionPage(unit: unit, kind: media.kind, mediaTitle: media.titles.display, service: _service),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    if (entries == null || entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: _anime ? S.current.Kr_Quick_Update : S.current.Kr_Quick_Update_Manga),
          SizedBox(
            height: _QuickCard.heightFor(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final e = entries[i];
                return _QuickCard(
                  key: ValueKey(e.id),
                  entry: e,
                  anime: _anime,
                  busy: _busy.contains(e.id),
                  onMark: () => _mark(e),
                  onEdit: () => _edit(e),
                  onOpenUnit: () => _openUnit(e),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final KitsuMyEntry entry;
  final bool anime;
  final bool busy;
  final VoidCallback onMark;
  final VoidCallback onEdit;
  final VoidCallback onOpenUnit;

  const _QuickCard({
    super.key,
    required this.entry,
    required this.anime,
    required this.busy,
    required this.onMark,
    required this.onEdit,
    required this.onOpenUnit,
  });

  static const double _w = KitsuQuickUpdateRow.cardWidth;

  static double heightFor(BuildContext context) =>
      _w * 9 / 16 + MediaQuery.textScalerOf(context).scale(64) + 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = AppColors.of(context);
    final s = S.current;
    final media = entry.media!;
    final unit = entry.nextUnit;
    final next = entry.progress + 1;
    final last = entry.total > 0 && next >= entry.total;
    final picture = unit?.thumbnail?.url ?? entry.banner?.url ?? media.poster?.url;
    final progress = entry.total > 0
        ? (anime ? s.Kr_Ep_Of(entry.progress, entry.total) : s.Kr_Ch_Of(entry.progress, entry.total))
        : (anime ? s.Kr_Ep_N(entry.progress) : s.Kr_Ch_N(entry.progress));
    return SizedBox(
      width: _w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpenUnit,
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                AppImage(
                  url: picture,
                  width: _w,
                  height: _w * 9 / 16,
                  borderRadius: BorderRadius.circular(12),
                  placeholderColor: scheme.surfaceContainerHighest,
                  semanticLabel: media.titles.display,
                ),
                if (unit != null)
                  PositionedDirectional(
                    start: 8,
                    bottom: 8,
                    end: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.imageScrim.withValues(alpha: AppColors.imageScrimOpacity),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.forum_outlined, size: 14, color: tokens.onImageScrim),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                [
                                  anime ? s.Kr_Mark_Episode(unit.number) : s.Kr_Mark_Chapter(unit.number),
                                  if (unit.title != null) unit.title!,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(color: tokens.onImageScrim),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => openKitsuTitle(context,
                kind: media.kind, id: media.id, slug: media.slug, title: media.titles.display, posterUrl: media.poster?.url),
            child: Text(media.titles.display, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(progress, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: entry.total > 0 ? (entry.progress / entry.total).clamp(0.0, 1.0) : null,
                    minHeight: 4,
                    color: tokens.watching.color,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: busy ? null : onMark,
                  icon: busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    last ? s.Kr_Complete : (anime ? s.Kr_Mark_Episode(next) : s.Kr_Mark_Chapter(next)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                tooltip: s.Kr_Edit_Entry,
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The site's latest reactions: the title's poster, the reaction, its author and its votes. A
/// tap opens the title's Kitsu page. Draws nothing when Kitsu answers nothing.
class KitsuReactionsRow extends StatelessWidget {
  final String title;
  final int refresh;
  final Future<List<KitsuReaction>> Function()? load;

  const KitsuReactionsRow({super.key, required this.title, this.refresh = 0, this.load});

  static const double cardWidth = 280;
  static const double cardHeight = 132;

  @override
  Widget build(BuildContext context) {
    return HomeAsync<List<KitsuReaction>>(
      cacheKey: 'kitsu:reactions:recent',
      maxAge: const Duration(minutes: 30),
      refresh: refresh,
      load: () async {
        try {
          return await (load ?? () => KitsuCatalog.instance.recentReactions())();
        } catch (_) {
          return const <KitsuReaction>[];
        }
      },
      loading: const SizedBox.shrink(),
      builder: (context, items) => items.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: title),
                  SizedBox(
                    height: cardHeight,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) => KitsuHomeReactionCard(reaction: items[i]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class KitsuHomeReactionCard extends StatelessWidget {
  final KitsuReaction reaction;

  const KitsuHomeReactionCard({super.key, required this.reaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = reaction.media;
    return SizedBox(
      width: KitsuReactionsRow.cardWidth,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: media == null
              ? null
              : () => openKitsuTitle(context,
                  kind: media.kind, id: media.id, slug: media.slug, title: media.titles.display, posterUrl: media.poster?.url),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppImage(
                url: media?.poster?.url,
                width: 80,
                placeholderColor: scheme.surfaceContainerHighest,
                semanticLabel: media?.titles.display,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (media != null)
                        Text(media.titles.display,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(reaction.text,
                            maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(reaction.author.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                          ),
                          Icon(Icons.arrow_upward_rounded, size: 14, color: scheme.primary),
                          Text('${reaction.likes}',
                              semanticsLabel: S.current.Kr_Reaction_Votes(reaction.likes),
                              style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
