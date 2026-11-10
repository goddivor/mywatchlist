import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType, gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/screens/forum/club_screen.dart';
import 'package:mywatchlist/screens/forum/forum_topics_screen.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/title_clubs.dart';
import 'package:mywatchlist/widgets/MAL/content/show_forum.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Latest forum topics, then the clubs of the title; the arrow opens the full topic list.
DetailSection? forumsSection(DetailData data) {
  if (!data.hasContent) return null;
  return DetailSection(
    TabType.Forums,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShowAnimeForum(animeId: data.id, category: data.category),
        TitleClubsRow(id: data.id, category: data.category),
      ],
    ),
    onViewAll: (context) => gotoPage(
      context: context,
      newPage: ForumTopicsScreen(
        animeId: data.isAnime ? data.id : null,
        mangaId: data.isManga ? data.id : null,
        title: S.current.Forums,
      ),
    ),
  );
}

/// The clubs of a title (MAL's `/<category>/<id>/_/clubs` page): a "Clubs" label and a
/// horizontal strip of cards that open the club. Nothing is drawn while loading, when the
/// title has no club or when the page cannot be read (no caption, no error line).
class TitleClubsRow extends StatefulWidget {
  const TitleClubsRow({super.key, required this.id, this.category = 'anime', this.fetch});

  final int id;
  final String category;

  /// Test hook: replaces [TitleClubs.fetch].
  final Future<List<ClubHtml>> Function(int id, String category)? fetch;

  @override
  State<TitleClubsRow> createState() => _TitleClubsRowState();
}

class _TitleClubsRowState extends State<TitleClubsRow> {
  List<ClubHtml> _clubs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final clubs = await (widget.fetch?.call(widget.id, widget.category) ??
          TitleClubs.fetch(widget.id, category: widget.category));
      if (!mounted) return;
      setState(() => _clubs = [
            for (final c in clubs)
              if (c.id != null && (c.name?.isNotEmpty ?? false)) c,
          ]);
    } catch (_) {
      // The row is optional: a page MAL does not answer simply adds nothing.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_clubs.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(S.current.Clubs,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _clubs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _ClubCard(club: _clubs[i]),
          ),
        ),
      ],
    );
  }
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({required this.club});

  final ClubHtml club;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final members = club.members;
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: () => gotoPage(context: context, newPage: ClubScreen(clubHtml: club)),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: club.imgUrl == null
                    ? ColoredBox(
                        color: colors.surfaceContainerHighest,
                        child: Icon(Icons.groups_rounded, color: colors.onSurfaceVariant),
                      )
                    : AppImage(url: club.imgUrl, width: 64, height: 64),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(club.name ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (members != null && members.isNotEmpty)
                        Text('$members ${S.current.Members}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant)),
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
