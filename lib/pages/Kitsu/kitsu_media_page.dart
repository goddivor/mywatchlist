import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_browse_screen.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media_detail.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart' show launchWebView;
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_media_cards.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_media_format.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_media_header.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_media_parts.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_paged_screen.dart';
import 'package:share_plus/share_plus.dart';

/// Native Kitsu title page: only Kitsu's own data (owner rule for Kitsu accounts), anonymous
/// and read-only. One request returns the record with the first page of every section; the
/// rating histogram is a second request and its section is simply absent when it fails. A
/// section Kitsu has nothing for is not shown. "Open on MyAnimeList" stays in the menu when
/// Kitsu maps the title to MyAnimeList.
class KitsuMediaPage extends StatefulWidget {
  final KitsuMediaKind kind;

  /// Kitsu id or slug, at least one.
  final String? id;
  final String? slug;

  /// Shown while the record loads (the tile that was tapped).
  final String? title;
  final String? posterUrl;
  final KitsuMediaDetailService? service;

  const KitsuMediaPage({
    super.key,
    required this.kind,
    this.id,
    this.slug,
    this.title,
    this.posterUrl,
    this.service,
  }) : assert(id != null || slug != null, 'give an id or a slug');

  @override
  State<KitsuMediaPage> createState() => _KitsuMediaPageState();
}

enum _Phase { loading, ready, failed, notFound }

class _KitsuMediaPageState extends State<KitsuMediaPage> {
  late final KitsuMediaDetailService _service = widget.service ?? KitsuMediaDetailService.instance;

  _Phase _phase = _Phase.loading;
  KitsuMediaDetail? _detail;
  KitsuRatingFrequencies? _ratings;
  bool _ratingsLoading = true;

  KitsuMediaKind get _kind => widget.kind;

  @override
  void initState() {
    super.initState();
    final key = widget.id ?? widget.slug!;
    _detail = _service.peek<KitsuMediaDetail>(KitsuMediaDetailService.detailKey(_kind, key));
    if (_detail != null) {
      _phase = _Phase.ready;
      _ratings = _service.peek<KitsuRatingFrequencies>(KitsuMediaDetailService.ratingsKey(_kind, _detail!.id));
      _ratingsLoading = _ratings == null;
    }
    _load();
  }

  Future<void> _load({bool force = false}) async {
    try {
      final found = await _service.detail(_kind, id: widget.id, slug: widget.slug, force: force);
      if (!mounted) return;
      if (found == null) {
        if (_detail == null) setState(() => _phase = _Phase.notFound);
        return;
      }
      setState(() {
        _detail = found;
        _phase = _Phase.ready;
      });
      unawaited(_loadRatings(found.id, force));
    } catch (_) {
      if (mounted && _detail == null) setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _loadRatings(String id, bool force) async {
    if (mounted && _ratings == null) setState(() => _ratingsLoading = true);
    try {
      final r = await _service.ratings(_kind, id, force: force);
      if (mounted) setState(() => _ratings = r);
    } catch (_) {
      // The histogram is a nice-to-have: the page stays whole without it.
    } finally {
      if (mounted) setState(() => _ratingsLoading = false);
    }
  }

  String get _pageUrl => KitsuMediaFormat.pageUrl(_kind, _detail?.slug ?? widget.slug ?? widget.id!);

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  void _openTitle(KitsuMediaRef ref) => _push(KitsuMediaPage(
        kind: ref.kind,
        id: ref.id,
        slug: ref.slug,
        title: ref.titles.display,
        posterUrl: ref.poster?.url,
        service: widget.service,
      ));

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    final name = d?.titles.display.isNotEmpty == true ? d!.titles.display : (widget.title ?? '');
    return Scaffold(
      body: RefreshIndicator(
        edgeOffset: KitsuMediaHeader.extent(context) * 0.3,
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: KitsuMediaHeader.extent(context) - MediaQuery.paddingOf(context).top,
              title: _CollapsedTitle(name),
              actions: [
                IconButton(
                  tooltip: S.current.Kmp_Open_On_Kitsu,
                  icon: const Icon(Icons.open_in_browser),
                  onPressed: () => launchWebView(_pageUrl, context: context),
                ),
                _menu(context),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: KitsuMediaHeader(
                  detail: d,
                  kind: _kind,
                  fallbackTitle: name,
                  fallbackPoster: widget.posterUrl,
                ),
              ),
            ),
            ..._body(context),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final mal = _detail?.malId;
    return PopupMenuButton<String>(
      onSelected: (v) {
        switch (v) {
          case 'mal':
            if (mal != null) AppRoutes.openContent(context, id: mal, category: _kind.path);
          case 'share':
            Share.share(_pageUrl);
        }
      },
      itemBuilder: (_) => [
        if (mal != null)
          PopupMenuItem(
            value: 'mal',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.launch),
              title: Text(S.current.Kmp_Open_On_Mal),
            ),
          ),
        PopupMenuItem(
          value: 'share',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.share_outlined),
            title: Text(S.current.Kmp_Share),
          ),
        ),
      ],
    );
  }

  List<Widget> _body(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return const [
          SliverToBoxAdapter(child: KitsuBlockSkeleton(height: 110)),
          SliverToBoxAdapter(child: KitsuBlockSkeleton(height: 180)),
        ];
      case _Phase.notFound:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SectionMessage(icon: Icons.search_off, message: S.current.Kmp_Not_Found),
          ),
        ];
      case _Phase.failed:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SectionMessage(
              icon: Icons.cloud_off_outlined,
              message: S.current.Kmp_Load_Error,
              onRetry: () {
                setState(() => _phase = _Phase.loading);
                _load(force: true);
              },
            ),
          ),
        ];
      case _Phase.ready:
        // One lazily built list: sections further down only build when they come near.
        return [SliverList.list(children: _sections(context, _detail!))];
    }
  }

  List<Widget> _sections(BuildContext context, KitsuMediaDetail d) {
    final out = <Widget>[];
    final anime = d.kind == KitsuMediaKind.anime;

    if (d.description != null || d.categories.isNotEmpty) {
      out.add(KitsuSection(
        title: S.current.Kmp_Synopsis,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kitsuPagePadding + 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.description != null) KitsuExpandableText(d.description!),
              if (d.categories.isNotEmpty) ...[
                const SizedBox(height: 10),
                KitsuChips(
                  [for (final c in d.categories) c.title],
                  onTap: (i) => _openCategory(d, d.categories[i]),
                ),
              ],
            ],
          ),
        ),
      ));
    }

    final ratings = _ratings;
    if (ratings != null && ratings.total > 0) {
      out.add(KitsuSection(title: S.current.Kmp_Ratings, child: KitsuRatingHistogram(ratings)));
    } else if (_ratingsLoading) {
      out.add(const KitsuBlockSkeleton(height: 150));
    }

    if (d.streamingLinks.isNotEmpty) {
      out.add(KitsuSection(
        title: S.current.Kmp_Where_To_Watch,
        child: Column(children: [
          for (final link in d.streamingLinks)
            KitsuStreamingTile(link: link, onTap: () => launchWebView(link.url, context: context, external: true)),
        ]),
      ));
    }

    final trailer = d.youtubeTrailerVideoId;
    if (trailer != null) {
      out.add(KitsuSection(
        title: S.current.Kmp_Trailer,
        child: KitsuTrailerCard(
          videoId: trailer,
          onTap: () => launchWebView('https://www.youtube.com/watch?v=$trailer', context: context, external: true),
        ),
      ));
    }

    if (d.units.nodes.isNotEmpty) {
      out.add(KitsuSection(
        title: anime ? S.current.Kmp_Episodes : S.current.Kmp_Chapters,
        onViewAll: () => _push(KitsuPagedScreen<KitsuUnit>(
          title: anime ? S.current.Kmp_Episodes : S.current.Kmp_Chapters,
          first: d.units,
          load: (page) => _service.units(_kind, d.id, page),
          itemBuilder: (context, u) => KitsuUnitRow(unit: u, kind: _kind),
        )),
        child: KitsuStrip(
          height: KitsuUnitCard.heightFor(context),
          itemCount: d.units.nodes.length,
          itemBuilder: (context, i) => KitsuUnitCard(unit: d.units.nodes[i], kind: _kind),
        ),
      ));
    }
    if (d.volumes.isNotEmpty) {
      out.add(KitsuSection(
        title: S.current.Kmp_Volumes,
        child: KitsuStrip(
          height: KitsuUnitCard.heightFor(context),
          itemCount: d.volumes.length,
          itemBuilder: (context, i) => KitsuUnitCard(unit: d.volumes[i], kind: _kind, volume: true),
        ),
      ));
    }

    if (d.relations.isNotEmpty) {
      out.add(KitsuSection(
        title: S.current.Kmp_Related,
        child: KitsuStrip(
          height: KitsuPosterCard.heightFor(context, 116),
          itemCount: d.relations.length,
          itemBuilder: (context, i) {
            final r = d.relations[i];
            return KitsuPosterCard(
              media: r.media,
              caption: KitsuMediaFormat.relation(r.kind),
              onTap: () => _openTitle(r.media),
            );
          },
        ),
      ));
    }

    if (d.reactions.nodes.isNotEmpty) {
      final more = d.reactions.hasNextPage;
      out.add(KitsuSection(
        title: S.current.Kmp_Reactions,
        onViewAll: more
            ? () => _push(KitsuPagedScreen<KitsuReaction>(
                  title: S.current.Kmp_Reactions,
                  first: d.reactions,
                  load: (page) => _service.reactions(_kind, d.id, page),
                  itemBuilder: (context, r) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kitsuPagePadding, vertical: 5),
                    child: KitsuReactionCard(reaction: r, kind: _kind, width: null, compact: false),
                  ),
                ))
            : null,
        child: KitsuStrip(
          height: 200,
          itemCount: d.reactions.nodes.length,
          itemBuilder: (context, i) => KitsuReactionCard(reaction: d.reactions.nodes[i], kind: _kind),
        ),
      ));
    }

    if (d.posts.nodes.isNotEmpty) {
      out.add(KitsuSection(
        title: S.current.Kmp_Posts,
        child: Column(children: [
          for (final p in d.posts.nodes.take(3)) KitsuPostTile(post: p),
        ]),
      ));
    }

    if (d.characters.nodes.isNotEmpty) {
      out.add(KitsuSection(
        title: S.current.Kmp_Characters,
        onViewAll: d.characters.hasNextPage
            ? () => _push(KitsuPagedScreen<KitsuCharacterRole>(
                  title: S.current.Kmp_Characters,
                  first: d.characters,
                  load: (page) => _service.characters(_kind, d.id, page),
                  itemBuilder: (context, c) => _PersonRow(
                    name: c.name,
                    imageUrl: c.image?.url,
                    line: [KitsuMediaFormat.role(c.role), if (c.voice != null) S.current.Kmp_Voiced_By(c.voice!.name)].join(' · '),
                  ),
                ))
            : null,
        child: KitsuStrip(
          height: KitsuCharacterCard.heightFor(context),
          itemCount: d.characters.nodes.length,
          itemBuilder: (context, i) => KitsuCharacterCard(role: d.characters.nodes[i]),
        ),
      ));
    }

    if (d.staff.nodes.isNotEmpty) {
      out.add(KitsuSection(
        title: S.current.Kmp_Staff,
        onViewAll: d.staff.hasNextPage
            ? () => _push(KitsuPagedScreen<KitsuStaffMember>(
                  title: S.current.Kmp_Staff,
                  first: d.staff,
                  load: (page) => _service.staff(_kind, d.id, page),
                  itemBuilder: (context, s) => _PersonRow(name: s.name, imageUrl: s.image?.url, line: s.role),
                ))
            : null,
        child: KitsuStrip(
          height: KitsuStaffCard.heightFor(context),
          itemCount: d.staff.nodes.length,
          itemBuilder: (context, i) => KitsuStaffCard(member: d.staff.nodes[i]),
        ),
      ));
    }

    if (d.quotes.isNotEmpty) {
      out.add(KitsuSection(
        title: S.current.Kmp_Quotes,
        child: Column(children: [for (final q in d.quotes) KitsuQuoteTile(q)]),
      ));
    }

    out.add(_info(context, d));
    return out;
  }

  void _openCategory(KitsuMediaDetail d, KitsuCategory c) => _push(KitsuBrowseScreen(
        title: c.title,
        query: KitsuMediaQuery(
          isAnime: d.kind == KitsuMediaKind.anime,
          filters: {'categories': c.slug},
          sort: 'popularityRank',
        ),
      ));

  Widget _info(BuildContext context, KitsuMediaDetail d) {
    final anime = d.kind == KitsuMediaKind.anime;
    String? roles(String role) {
      final names = [for (final p in d.productions) if (p.role.toUpperCase() == role) p.name];
      return names.isEmpty ? null : names.join(', ');
    }

    String? positive(int? n) => n != null && n > 0 ? KitsuMediaFormat.count(n) : null;
    final alt = {
      for (final t in [d.titles.romanized, d.titles.translated, d.titles.original])
        if (t != null && t != d.titles.display) t,
    };
    final rows = <(String, String?)>[
      (S.current.Kmp_Type, d.subtype == null ? null : KitsuMediaFormat.subtype(d.subtype)),
      (anime ? S.current.Kmp_Episodes : S.current.Kmp_Chapters, positive(anime ? d.episodeCount : d.chapterCount)),
      (S.current.Kmp_Volumes, anime ? null : positive(d.volumeCount)),
      (S.current.Kmp_Status, KitsuMediaFormat.status(d.status, d.kind)),
      (anime ? S.current.Kmp_Aired : S.current.Kmp_Published, KitsuMediaFormat.span(d.startDate, d.endDate)),
      (S.current.Kmp_Season, anime && d.season != null ? KitsuMediaFormat.season(d.season, d.startDate) : null),
      (S.current.Kmp_Episode_Length, anime && d.episodeLength != null && d.episodeLength! > 0 ? KitsuMediaFormat.minutes(d.episodeLength!) : null),
      (S.current.Kmp_Total_Length, anime && d.totalLength != null && d.totalLength! > 0 ? KitsuMediaFormat.minutes(d.totalLength!) : null),
      (S.current.Kmp_Next_Release, KitsuMediaFormat.date(d.nextRelease)),
      (S.current.Kmp_Age_Rating, d.ageRating),
      (S.current.Kmp_Origin, d.originCountries.isEmpty ? null : d.originCountries.join(', ')),
      (S.current.Kmp_Studios, roles('STUDIO')),
      (S.current.Kmp_Producers, roles('PRODUCER')),
      (S.current.Kmp_Licensors, roles('LICENSOR')),
      (S.current.Kmp_Serialization, roles('SERIALIZATION')),
      (S.current.Kmp_Alt_Titles, alt.isEmpty ? null : alt.join('\n')),
    ];
    final sites = [for (final m in d.mappings) KitsuMediaFormat.externalSite(m)];
    return KitsuSection(
      title: S.current.Kmp_Info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in rows)
            if (value != null && value.isNotEmpty) KitsuInfoRow(label, value),
          if (d.mappings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(kitsuPagePadding + 10, 12, kitsuPagePadding + 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.current.Kmp_External_Ids,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  KitsuChips(
                    [for (final s in sites) s.name],
                    onTap: (i) => _openExternal(d.mappings[i], sites[i].url),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openExternal(KitsuMapping mapping, String? url) async {
    if (url != null) {
      await launchWebView(url, context: context);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: mapping.externalId));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(S.current.Kmp_Id_Copied)));
  }
}

/// A character or staff row of the full lists.
class _PersonRow extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String line;

  const _PersonRow({required this.name, required this.imageUrl, required this.line});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: kitsuPagePadding),
      leading: RoundAvatar(url: imageUrl, size: 48, semanticLabel: name),
      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: line.isEmpty
          ? null
          : Text(line, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

/// The title in the toolbar, shown once the header has collapsed.
class _CollapsedTitle extends StatelessWidget {
  final String text;

  const _CollapsedTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    var visible = true;
    if (settings != null) {
      final range = settings.maxExtent - settings.minExtent;
      visible = range <= 0 || (settings.currentExtent - settings.minExtent) / range < 0.15;
    }
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
