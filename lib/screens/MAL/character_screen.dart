import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/cache/top_characters.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_button.dart';
import 'package:mywatchlist/widgets/common/app_bar_menu.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';
import 'package:mywatchlist/widgets/common/translator.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

// =============================================================================
// Data (plain objects built in a background isolate)
// =============================================================================

enum _SectionId {
  animeography,
  mangaography,
  voiceActors,
  voiceRoles,
  animeStaff,
  publishedManga,
}

enum _VoiceSort { recent, favorites, title }

class _Entry {
  final int id;
  final String title;
  final String? image;
  final String? subtitle;

  const _Entry(this.id, this.title, this.image, this.subtitle);
}

class _Section {
  final _SectionId id;
  final String category;
  final List<_Entry> entries;

  const _Section(this.id, this.category, this.entries);
}

class _Profile {
  final String name;
  final String alternateName;
  final String about;
  final int? favorites;
  final String? image;
  final List<_Section> sections;

  const _Profile({
    required this.name,
    required this.alternateName,
    required this.about,
    required this.favorites,
    required this.image,
    required this.sections,
  });

  _Section? section(_SectionId id) {
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }
}

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;

String? _jpg(Object? images) {
  final url = _map(_map(images)?['jpg'])?['image_url'];
  return url is String && url.isNotEmpty ? url : null;
}

/// Entries of a Jikan relation list, one per MAL id (first one wins).
List<_Entry> _entries(
  Object? list, {
  required String key,
  required String titleKey,
  required String subtitleKey,
}) {
  if (list is! List) return const [];
  final seen = <int>{};
  final out = <_Entry>[];
  for (final raw in list) {
    final row = _map(raw);
    final item = _map(row?[key]);
    final id = item?['mal_id'];
    if (row == null || item == null || id is! int || !seen.add(id)) continue;
    final title = item[titleKey];
    final subtitle = row[subtitleKey];
    out.add(_Entry(
      id,
      title is String && title.isNotEmpty ? title : '?',
      _jpg(item['images']),
      subtitle is String && subtitle.isNotEmpty ? subtitle : null,
    ));
  }
  return out;
}

/// Parses a Jikan `characters/{id}/full` or `people/{id}/full` body. Runs in
/// a background isolate: the answer can be hundreds of kilobytes.
_Profile _parseProfile((String, bool) args) {
  final (body, isCharacter) = args;
  final data = _map(_map(jsonDecode(body))?['data']) ?? const {};
  final name = (data['name'] as String?) ?? '';
  String alternate;
  if (isCharacter) {
    alternate = (data['name_kanji'] as String?) ?? '';
  } else {
    final given = (data['given_name'] as String?) ?? '';
    final family = (data['family_name'] as String?) ?? '';
    alternate = [given, family].where((e) => e.isNotEmpty).join(', ');
  }
  final sections = isCharacter
      ? [
          _Section(
            _SectionId.animeography,
            'anime',
            _entries(data['anime'],
                key: 'anime', titleKey: 'title', subtitleKey: 'role'),
          ),
          _Section(
            _SectionId.mangaography,
            'manga',
            _entries(data['manga'],
                key: 'manga', titleKey: 'title', subtitleKey: 'role'),
          ),
          _Section(
            _SectionId.voiceActors,
            'person',
            _entries(data['voices'],
                key: 'person', titleKey: 'name', subtitleKey: 'language'),
          ),
        ]
      : [
          _Section(
            _SectionId.voiceRoles,
            'character',
            _entries(data['voices'],
                key: 'character', titleKey: 'name', subtitleKey: 'role'),
          ),
          _Section(
            _SectionId.animeStaff,
            'anime',
            _entries(data['anime'],
                key: 'anime', titleKey: 'title', subtitleKey: 'position'),
          ),
          _Section(
            _SectionId.publishedManga,
            'manga',
            _entries(data['manga'],
                key: 'manga', titleKey: 'title', subtitleKey: 'position'),
          ),
        ];
  return _Profile(
    name: name,
    alternateName: alternate,
    about: ((data['about'] as String?) ?? '').trim(),
    favorites: data['favorites'] as int?,
    image: _jpg(data['images']),
    sections: sections,
  );
}

List<String> _parsePictures(String body) {
  final data = _map(jsonDecode(body))?['data'];
  if (data is! List) return const [];
  return [
    for (final e in data)
      if (_jpg(e) case final String url) url,
  ];
}

/// Favorites of characters already looked up, kept for the session so a
/// second sort (or another person's page) does not ask Jikan again.
final Map<int, int> _favoritesCache = {};

// =============================================================================
// Screen
// =============================================================================

/// A screen that displays details for a MAL character or person (seiyuu/staff).
///
/// Pass [category] = `'character'` (default) for characters, or `'person'`
/// for voice actors / staff members. The page is a MyAnimeList screen whatever
/// tracker is active: the data comes from Jikan by MAL id.
class CharacterScreen extends StatefulWidget {
  final int id;
  final String category;

  const CharacterScreen({
    super.key,
    required this.id,
    this.category = 'character',
  });

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  _Profile? _profile;
  bool _failed = false;
  int _tab = 0;
  _VoiceSort _sort = _VoiceSort.recent;
  List<_Entry> _voices = const [];
  final ValueNotifier<List<String>> _pictures = ValueNotifier(const []);
  final ValueNotifier<(int, int)?> _sortProgress = ValueNotifier(null);

  /// Incremented to cancel a running favorites lookup.
  int _run = 0;

  bool get _isCharacter => widget.category == 'character';
  String get _path => _isCharacter ? 'characters' : 'people';
  String get _url => 'https://myanimelist.net/'
      '${_isCharacter ? 'character' : 'people'}/${widget.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _run++;
    _pictures.dispose();
    _sortProgress.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    if (_failed || _profile != null) {
      setState(() {
        _failed = false;
        _profile = null;
      });
    }
    try {
      final res = await JikanClient.instance
          .get(Uri.parse('${Constants.jikanV4}/$_path/${widget.id}/full'));
      if (res.statusCode != 200) throw StateError('HTTP ${res.statusCode}');
      final profile = await compute(_parseProfile, (res.body, _isCharacter));
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _voices = List.of(profile.section(_SectionId.voiceRoles)?.entries ??
            const <_Entry>[]);
      });
      _loadPictures(profile.image);
    } catch (e) {
      debugPrint('Character page failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Extra pictures are a bonus: a failure leaves the main picture alone.
  Future<void> _loadPictures(String? main) async {
    if (main != null) _pictures.value = [main];
    try {
      final res = await JikanClient.instance
          .get(Uri.parse('${Constants.jikanV4}/$_path/${widget.id}/pictures'));
      if (res.statusCode != 200 || !mounted) return;
      final extra = await compute(_parsePictures, res.body);
      if (!mounted) return;
      final all = <String>[
        if (main != null) main,
        ...extra.where((u) => u != main),
      ];
      if (all.isNotEmpty) _pictures.value = all;
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Voice roles sorting
  // ---------------------------------------------------------------------------

  void _applySort() {
    final base = List.of(
        _profile?.section(_SectionId.voiceRoles)?.entries ?? const <_Entry>[]);
    switch (_sort) {
      case _VoiceSort.recent:
        break;
      case _VoiceSort.title:
        base.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _VoiceSort.favorites:
        // List.sort is not stable: the original position breaks ties.
        final position = {for (var i = 0; i < base.length; i++) base[i].id: i};
        base.sort((a, b) {
          final byFav =
              (_favoritesCache[b.id] ?? 0).compareTo(_favoritesCache[a.id] ?? 0);
          return byFav != 0 ? byFav : position[a.id]!.compareTo(position[b.id]!);
        });
    }
    setState(() => _voices = base);
  }

  Future<void> _setSort(_VoiceSort sort) async {
    if (sort == _sort) return;
    _run++;
    _sortProgress.value = null;
    _sort = sort;
    _applySort();
    if (sort == _VoiceSort.favorites) await _loadFavorites();
  }

  /// Looks up the favorites of every voiced character not yet known, one at a
  /// time (Jikan allows about 3 requests per second; the client spaces them),
  /// then sorts. A rate limit stops the lookup and sorts with what is known.
  Future<void> _loadFavorites() async {
    final token = ++_run;
    // The shared top-characters list answers most popular roles at once.
    try {
      await TopCharacters.instance.ensureLoaded();
      for (final e in _voices) {
        final fav = TopCharacters.instance.favoritesOf(e.id);
        if (fav != null) _favoritesCache[e.id] = fav;
      }
    } catch (_) {}
    if (!mounted || token != _run) return;
    final missing = [
      for (final e in _voices)
        if (!_favoritesCache.containsKey(e.id)) e.id,
    ];
    if (missing.isEmpty) {
      _applySort();
      return;
    }
    var done = 0;
    _sortProgress.value = (0, missing.length);
    var complete = true;
    String? problem;
    for (final id in missing) {
      if (!mounted || token != _run) return;
      try {
        final res = await JikanClient.instance
            .get(Uri.parse('${Constants.jikanV4}/characters/$id'));
        if (res.statusCode == 429) {
          complete = false;
          problem = S.current.Fc_Rate_Limit;
          break;
        }
        if (res.statusCode == 200) {
          final fav = _map(_map(jsonDecode(res.body))?['data'])?['favorites'];
          _favoritesCache[id] = fav is int ? fav : 0;
        } else if (res.statusCode == 404) {
          _favoritesCache[id] = 0;
        } else {
          complete = false;
        }
      } on JikanUnavailable {
        complete = false;
        problem = S.current.Fc_Sort_Failed;
        break;
      } catch (_) {
        complete = false;
      }
      done++;
      if (mounted && token == _run) _sortProgress.value = (done, missing.length);
    }
    if (!mounted || token != _run) return;
    _sortProgress.value = null;
    _applySort();
    if (problem != null) {
      showToast(problem);
    } else if (complete) {
      showToast(S.current.Fc_Sorting_Done);
    } else {
      showToast(S.current.Fc_Sort_Failed);
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _share(_Profile profile) {
    showShareBuilder(
      context,
      subject: profile.name,
      title: _isCharacter
          ? S.current.Fc_Share_Character
          : S.current.Fc_Share_Person,
      fields: personShareFields(
        url: _url,
        name: profile.name,
        favorites: profile.favorites,
        about: profile.about,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final title = profile?.name.isNotEmpty == true
        ? profile!.name
        : (_isCharacter ? S.current.Fc_Character : S.current.Fc_Person);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (profile != null && profile.name.isNotEmpty)
                BookmarkButton(
                  tracker: AccountType.myanimelist.name,
                  kind: _isCharacter ? BookmarkKind.character : BookmarkKind.person,
                  id: widget.id,
                  title: profile.name,
                  imageUrl: profile.image,
                  subtitle: profile.alternateName.isEmpty
                      ? null
                      : profile.alternateName,
                  malId: widget.id,
                ),
              if (profile != null)
                AppBarMenu(
                  onShare: () => _share(profile),
                  onOpenInBrowser: () => openLink(context, _url),
                ),
            ],
          ),
          ..._bodySlivers(profile),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  List<Widget> _bodySlivers(_Profile? profile) {
    if (_failed) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: SectionMessage.error(
            message: S.current.Fc_Load_Failed,
            height: 240,
            onRetry: _load,
          ),
        ),
      ];
    }
    if (profile == null) return [const SliverToBoxAdapter(child: _Skeleton())];
    return [
      SliverToBoxAdapter(
        child: _Header(profile: profile, pictures: _pictures),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0, label: Text(S.current.Fc_About)),
              ButtonSegment(value: 1, label: Text(S.current.Fc_Details)),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
      ),
      if (_tab == 0) ..._aboutSlivers(profile) else ..._detailSlivers(profile),
    ];
  }

  List<Widget> _aboutSlivers(_Profile profile) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverToBoxAdapter(
          child: profile.about.isEmpty
              ? Text(
                  S.current.Fc_No_About,
                  style: style?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : TranslatorWidget(
                  content: profile.about,
                  reversed: true,
                  builder: (context, text) => SelectableText(text, style: style),
                ),
        ),
      ),
    ];
  }

  List<Widget> _detailSlivers(_Profile profile) {
    final slivers = <Widget>[];
    for (final section in profile.sections) {
      final isVoices = section.id == _SectionId.voiceRoles;
      final entries = isVoices ? _voices : section.entries;
      if (entries.isEmpty) continue;
      slivers.add(SliverToBoxAdapter(
        child: _SectionHeader(
          title: _sectionTitle(section.id),
          count: entries.length,
          trailing: isVoices ? _sortButton() : null,
          progress: isVoices ? _sortProgress : null,
        ),
      ));
      if (isVoices) {
        // Possibly hundreds of roles: a lazy grid, not a row.
        slivers.add(SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              mainAxisExtent: 148,
            ),
            itemCount: entries.length,
            itemBuilder: (_, i) => _EntryCard(
              key: ValueKey(entries[i].id),
              entry: entries[i],
              category: section.category,
              favorites: _sort == _VoiceSort.favorites
                  ? _favoritesCache[entries[i].id]
                  : null,
            ),
          ),
        ));
      } else {
        slivers.add(SliverToBoxAdapter(
          child: SizedBox(
            height: section.category == 'person' ? 148 : 218,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemExtent: 112,
              itemCount: entries.length,
              itemBuilder: (_, i) => _EntryCard(
                key: ValueKey(entries[i].id),
                entry: entries[i],
                category: section.category,
              ),
            ),
          ),
        ));
      }
    }
    if (slivers.isEmpty) {
      slivers.add(SliverToBoxAdapter(child: showNoContent()));
    }
    return slivers;
  }

  String _sectionTitle(_SectionId id) => switch (id) {
        _SectionId.animeography => S.current.Fc_Animeography,
        _SectionId.mangaography => S.current.Fc_Mangaography,
        _SectionId.voiceActors => S.current.Fc_Voice_Actors,
        _SectionId.voiceRoles => S.current.Fc_Voice_Roles,
        _SectionId.animeStaff => S.current.Fc_Anime_Staff,
        _SectionId.publishedManga => S.current.Fc_Published_Manga,
      };

  Widget _sortButton() {
    String label(_VoiceSort s) => switch (s) {
          _VoiceSort.recent => S.current.Fc_Sort_Recent,
          _VoiceSort.favorites => S.current.Fc_Sort_Favorites,
          _VoiceSort.title => S.current.Fc_Sort_Title,
        };
    return PopupMenuButton<_VoiceSort>(
      tooltip: S.current.Fc_Sort,
      icon: const Icon(Icons.sort),
      initialValue: _sort,
      onSelected: _setSort,
      itemBuilder: (_) => [
        for (final s in _VoiceSort.values)
          CheckedPopupMenuItem(
            value: s,
            checked: s == _sort,
            child: Text(label(s)),
          ),
      ],
    );
  }
}

// =============================================================================
// Widgets
// =============================================================================

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return ShimmerColor(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            bar(200, 24),
            const SizedBox(height: 10),
            bar(120, 16),
            const SizedBox(height: 24),
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < 5; i++) ...[
              bar(double.infinity, 14),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Name, alternate name, picture carousel and favorites.
class _Header extends StatelessWidget {
  final _Profile profile;
  final ValueNotifier<List<String>> pictures;

  const _Header({required this.profile, required this.pictures});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        _Gallery(pictures: pictures),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              Text(
                profile.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              if (profile.alternateName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  profile.alternateName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (profile.favorites != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite, size: 20, color: scheme.error),
                    const SizedBox(width: 8),
                    Text(
                      S.current.Fc_Favorites(profile.favorites!),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Circular picture carousel (auto-plays, tap to zoom). It owns its page
/// controller and timer, so a page change repaints only this widget.
class _Gallery extends StatefulWidget {
  final ValueNotifier<List<String>> pictures;

  const _Gallery({required this.pictures});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final PageController _controller = PageController(viewportFraction: 0.55);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.pictures.addListener(_restart);
    _restart();
  }

  @override
  void dispose() {
    widget.pictures.removeListener(_restart);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    final count = widget.pictures.value.length;
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_index + 1) % count,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<String>>(
      valueListenable: widget.pictures,
      builder: (context, pictures, _) {
        if (pictures.isEmpty) return const SizedBox(height: 16);
        return GestureDetector(
          onTap: () => zoomInImageList(context, pictures, _index),
          child: SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _controller,
              itemCount: pictures.length,
              onPageChanged: (i) => _index = i,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipOval(
                      child: AppImage(
                        url: pictures[i],
                        width: 196,
                        height: 196,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        placeholderColor: scheme.surfaceContainerHighest,
                        errorWidget: (_) => ColoredBox(
                          color: scheme.secondaryContainer,
                          child: Icon(
                            Icons.person,
                            size: 64,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Widget? trailing;
  final ValueListenable<(int, int)?>? progress;

  const _SectionHeader({
    required this.title,
    required this.count,
    this.trailing,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: title,
                    children: [
                      TextSpan(
                        text: '  ${NumberFormat.decimalPattern().format(count)}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing case final t?) t,
            ],
          ),
          if (progress != null)
            ValueListenableBuilder<(int, int)?>(
              valueListenable: progress!,
              builder: (context, value, _) {
                if (value == null) return const SizedBox.shrink();
                final (done, total) = value;
                return Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.current.Fc_Sorting_Progress(done, total),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: total == 0 ? null : done / total),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// One related title or person: a round picture for people, a poster for
/// anime and manga.
class _EntryCard extends StatelessWidget {
  final _Entry entry;
  final String category;
  final int? favorites;

  const _EntryCard({
    super.key,
    required this.entry,
    required this.category,
    this.favorites,
  });

  bool get _isPerson => category == 'character' || category == 'person';

  void _open(BuildContext context) {
    if (_isPerson) {
      gotoPage(
        context: context,
        newPage: CharacterScreen(id: entry.id, category: category),
      );
    } else {
      gotoPage(
        context: context,
        newPage: ContentDetailedScreen(
          category: category,
          id: entry.id,
          node: Anime(
            id: entry.id,
            title: entry.title,
            imageUrl: entry.image ?? '',
            score: 0,
            members: 0,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final Widget picture = _isPerson
        ? RoundAvatar(url: entry.image, size: 84)
        : ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AppImage(
              url: entry.image,
              width: 96,
              height: 136,
              fit: BoxFit.cover,
              placeholderColor: scheme.surfaceContainerHighest,
              errorWidget: (_) => ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(Icons.image_not_supported_outlined, color: muted),
              ),
            ),
          );
    final subtitle = favorites != null
        ? NumberFormat.compact().format(favorites)
        : entry.subtitle;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            picture,
            const SizedBox(height: 6),
            Text(
              entry.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (favorites != null) ...[
                    Icon(Icons.favorite, size: 10, color: scheme.error),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
