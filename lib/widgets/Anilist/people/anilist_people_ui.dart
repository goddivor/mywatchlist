import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_people_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_html.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumMessage, ForumSkeleton;

/// A date AniList may know in part: "Jan 5, 1999", "Jan 5" or "1999".
String formatAnilistFuzzyDate(AnilistFuzzyDate date) {
  final locale = Intl.getCurrentLocale();
  final year = date.year, month = date.month, day = date.day;
  if (month != null && day != null) {
    // 2000 is a leap year, so February 29 formats.
    return year != null
        ? DateFormat.yMMMd(locale).format(DateTime(year, month, day))
        : DateFormat.MMMd(locale).format(DateTime(2000, month, day));
  }
  if (month != null && year != null) return DateFormat.yMMM(locale).format(DateTime(year, month));
  if (month != null) return DateFormat.MMMM(locale).format(DateTime(2000, month));
  return year?.toString() ?? '';
}

/// The label of a `CharacterRole` (`MAIN`, `SUPPORTING`, `BACKGROUND`).
String? anilistRoleLabel(String? role) {
  final s = S.current;
  switch (role) {
    case 'MAIN':
      return s.Alp_Role_Main;
    case 'SUPPORTING':
      return s.Alp_Role_Supporting;
    case 'BACKGROUND':
      return s.Alp_Role_Background;
  }
  return null;
}

/// The voice actor languages AniList stores (`StaffLanguage`) the language picker offers.
const List<String> anilistVoiceLanguages = [
  'JAPANESE',
  'ENGLISH',
  'KOREAN',
  'FRENCH',
  'GERMAN',
  'ITALIAN',
  'SPANISH',
  'PORTUGUESE',
  'HEBREW',
  'HUNGARIAN',
];

String anilistLanguageLabel(String language) {
  final s = S.current;
  switch (language.toUpperCase()) {
    case 'JAPANESE':
      return s.Alp_Lang_Japanese;
    case 'ENGLISH':
      return s.Alp_Lang_English;
    case 'KOREAN':
      return s.Alp_Lang_Korean;
    case 'FRENCH':
      return s.Alp_Lang_French;
    case 'GERMAN':
      return s.Alp_Lang_German;
    case 'ITALIAN':
      return s.Alp_Lang_Italian;
    case 'SPANISH':
      return s.Alp_Lang_Spanish;
    case 'PORTUGUESE':
      return s.Alp_Lang_Portuguese;
    case 'HEBREW':
      return s.Alp_Lang_Hebrew;
    case 'HUNGARIAN':
      return s.Alp_Lang_Hungarian;
  }
  return language;
}

String anilistPeopleSortLabel(AnilistPeopleSort sort) {
  final s = S.current;
  switch (sort) {
    case AnilistPeopleSort.popularity:
      return s.Alp_Sort_Popularity;
    case AnilistPeopleSort.startDate:
      return s.Alp_Sort_Start_Date;
    case AnilistPeopleSort.score:
      return s.Alp_Sort_Score;
  }
}

/// A title format such as `TV_SHORT` as "TV Short".
String anilistFormatLabel(String format) => format
    .split('_')
    .map((w) => w.length <= 3 ? w : '${w[0]}${w.substring(1).toLowerCase()}')
    .join(' ');

/// Adds the item to the favourites or removes it; true when AniList took it. Without an
/// account it offers to sign in; a failure shows its message in a snackbar.
Future<bool> toggleAnilistPersonFavourite(
  BuildContext context,
  AnilistPeopleService service,
  AnilistFavouriteKind kind,
  int id,
) async {
  final done = await runAnilistWrite<bool>(
    context,
    () async {
      await service.toggleFavourite(kind, id);
      return true;
    },
    service: AnilistSocialService(signedIn: service.signedIn),
  );
  return done ?? false;
}

/// The heart of a page's app bar.
class AnilistFavouriteAction extends StatelessWidget {
  const AnilistFavouriteAction({super.key, required this.isFavourite, required this.onPressed});

  final bool isFavourite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return IconButton(
      tooltip: isFavourite ? s.Alp_Remove_Favourite : s.Alp_Add_Favourite,
      icon: Icon(isFavourite ? Icons.favorite : Icons.favorite_border),
      color: isFavourite ? Theme.of(context).colorScheme.error : null,
      onPressed: onPressed,
    );
  }
}

/// Picture, names and favourites count at the top of an Info tab.
class AnilistPersonHeader extends StatelessWidget {
  const AnilistPersonHeader({
    super.key,
    required this.imageUrl,
    required this.name,
    this.native,
    this.favourites = 0,
    this.subtitle,
  });

  final String? imageUrl;
  final String name;
  final String? native;
  final int favourites;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(
            url: imageUrl,
            width: 110,
            height: 160,
            borderRadius: BorderRadius.circular(10),
            placeholderColor: scheme.surfaceContainerHighest,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleLarge),
                if (native != null && native != name)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      native!,
                      style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(subtitle!, style: theme.textTheme.bodyMedium),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.favorite, size: 16, color: scheme.error),
                    const SizedBox(width: 6),
                    Text(
                      S.of(context).Alp_Favourites_Count(favourites),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A label and its value; rows with an empty value are not built by the callers.
class AnilistInfoRow extends StatelessWidget {
  const AnilistInfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// The names under the header: alternative names, and the spoiler ones behind a tap.
class AnilistAlternativeNames extends StatefulWidget {
  const AnilistAlternativeNames({super.key, required this.names});

  final AnilistPersonNames names;

  @override
  State<AnilistAlternativeNames> createState() => _AnilistAlternativeNamesState();
}

class _AnilistAlternativeNamesState extends State<AnilistAlternativeNames> {
  bool _spoilers = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final names = widget.names;
    final shown = [...names.alternative, if (_spoilers) ...names.spoiler];
    if (shown.isEmpty && names.spoiler.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shown.isNotEmpty) AnilistInfoRow(s.Alp_Alt_Names, shown.join(', ')),
        if (names.spoiler.isNotEmpty && !_spoilers)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              onPressed: () => setState(() => _spoilers = true),
              child: Text(s.Alp_Show_Spoiler_Names),
            ),
          ),
      ],
    );
  }
}

/// The description of a person (AniList HTML, spoilers hidden).
class AnilistPersonDescription extends StatelessWidget {
  const AnilistPersonDescription(this.html, {super.key});

  final String? html;

  @override
  Widget build(BuildContext context) {
    final text = html;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: AnilistHtml(text),
    );
  }
}

/// A small round picture with a name: a voice actor, a character.
class AnilistPersonChip extends StatelessWidget {
  const AnilistPersonChip({super.key, required this.person, required this.onTap, this.showLanguage = false});

  final AnilistPersonRef person;
  final VoidCallback onTap;
  final bool showLanguage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = showLanguage && person.language != null ? anilistLanguageLabel(person.language!) : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: AppImage(
                url: person.imageUrl,
                width: 36,
                height: 36,
                placeholderColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (language != null)
                    Text(
                      language,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A title row: cover, title, "Format · year", and a [detail] line (role) plus [trailing].
class AnilistMediaTile extends StatelessWidget {
  const AnilistMediaTile({
    super.key,
    required this.media,
    required this.onTap,
    this.detail,
    this.below,
  });

  final AnilistPeopleMedia media;
  final VoidCallback onTap;

  /// The role badge or text under the title.
  final String? detail;

  /// Extra content under the text (voice actors, characters).
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meta = [
      if (media.format != null) anilistFormatLabel(media.format!),
      if (media.year != null) '${media.year}',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppImage(
              url: media.coverUrl,
              width: 56,
              height: 80,
              borderRadius: BorderRadius.circular(6),
              placeholderColor: scheme.surfaceContainerHighest,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  if (detail != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        detail!,
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary),
                      ),
                    ),
                  if (below != null) Padding(padding: const EdgeInsets.only(top: 4), child: below),
                ],
              ),
            ),
            if (media.listStatus != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.bookmark, size: 18, color: scheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}

/// A row of filter controls above a paged list: the "on my list" chip (when signed in) and
/// any [extra] controls.
class AnilistFilterBar extends StatelessWidget {
  const AnilistFilterBar({
    super.key,
    this.onList,
    this.onListChanged,
    this.sort,
    this.onSort,
    this.extra = const [],
  });

  final bool? onList;
  final ValueChanged<bool>? onListChanged;
  final AnilistPeopleSort? sort;
  final ValueChanged<AnilistPeopleSort>? onSort;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          if (onList != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(s.Alp_On_My_List),
                selected: onList!,
                onSelected: onListChanged,
              ),
            ),
          if (sort != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: PopupMenuButton<AnilistPeopleSort>(
                initialValue: sort,
                onSelected: onSort,
                itemBuilder: (_) => [
                  for (final value in AnilistPeopleSort.values)
                    PopupMenuItem(value: value, child: Text(anilistPeopleSortLabel(value))),
                ],
                child: Chip(
                  avatar: const Icon(Icons.sort, size: 18),
                  label: Text(anilistPeopleSortLabel(sort!)),
                ),
              ),
            ),
          ...extra,
        ],
      ),
    );
  }
}

/// A paged list that loads its next page near the end. Changing [reloadKey] starts again at
/// page 1 (a filter changed). [header] is the first row (the filter bar).
class AnilistPagedList<T> extends StatefulWidget {
  const AnilistPagedList({
    super.key,
    required this.loader,
    required this.itemBuilder,
    this.header,
    this.reloadKey,
    this.groupLabel,
  });

  final Future<AnilistPeoplePage<T>> Function(int page) loader;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget? header;
  final Object? reloadKey;

  /// When given, a heading is shown above the first item of each new label.
  final String Function(T item)? groupLabel;

  @override
  State<AnilistPagedList<T>> createState() => _AnilistPagedListState<T>();
}

class _AnilistPagedListState<T> extends State<AnilistPagedList<T>> with AutomaticKeepAliveClientMixin {
  final ScrollController _controller = ScrollController();
  final List<T> _items = [];
  int _page = 0;
  bool _hasNext = true;
  bool _loading = false;
  Object? _error;
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _loadMore();
  }

  @override
  void didUpdateWidget(AnilistPagedList<T> old) {
    super.didUpdateWidget(old);
    if (old.reloadKey != widget.reloadKey) _reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _controller.position;
    if (position.pixels > position.maxScrollExtent - 600) _loadMore();
  }

  void _reset() {
    _generation++;
    setState(() {
      _items.clear();
      _page = 0;
      _hasNext = true;
      _loading = false;
      _error = null;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasNext) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.loader(_page + 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _page++;
        _items.addAll(result.items);
        _hasNext = result.hasNext;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final empty = _items.isEmpty;
    if (empty && _error != null) {
      return ListView(
        children: [
          if (widget.header != null) widget.header!,
          SizedBox(
            height: 320,
            child: ForumMessage(
              icon: Icons.cloud_off_outlined,
              title: anilistErrorText(_error!),
              onRetry: _loadMore,
              scrollable: false,
            ),
          ),
        ],
      );
    }
    if (empty && _loading) {
      return ListView(
        children: [
          if (widget.header != null) widget.header!,
          const SizedBox(height: 480, child: ForumSkeleton(count: 5, rowHeight: 80)),
        ],
      );
    }
    final headerCount = widget.header == null ? 0 : 1;
    final rows = _items;
    return ListView.builder(
      controller: _controller,
      itemCount: headerCount + (empty ? 1 : _items.length + 1),
      itemBuilder: (context, index) {
        if (index < headerCount) return widget.header!;
        final i = index - headerCount;
        if (empty) {
          return Padding(
            padding: const EdgeInsets.all(48),
            child: Center(
              child: Text(
                S.of(context).Alp_Nothing_Found,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }
        if (i == rows.length) {
          if (_error != null) {
            return Center(
              child: TextButton(onPressed: _loadMore, child: Text(S.of(context).Alp_Retry)),
            );
          }
          return SizedBox(
            height: 56,
            child: _hasNext ? const Center(child: CircularProgressIndicator()) : null,
          );
        }
        final item = rows[i];
        final label = widget.groupLabel?.call(item);
        final previous = i > 0 ? widget.groupLabel?.call(rows[i - 1]) : null;
        final tile = widget.itemBuilder(context, item);
        if (label == null || label == previous) return tile;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(label, style: theme.textTheme.titleMedium),
            ),
            tile,
          ],
        );
      },
    );
  }
}
