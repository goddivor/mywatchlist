import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_catalog.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_browse_screen.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart' show HomeMessage;

/// Opens the titles of AniList's tag [name] (most popular first), with the tag's description
/// behind the app bar's info button. Entry point for tag chips (title page, explorer).
void openAnilistTag(BuildContext context, String name, {String category = 'anime'}) {
  AppRoutes.push<void>(
    context,
    AnilistBrowseScreen(
      title: name,
      query: AnilistMediaQuery(category: category, sort: 'POPULARITY_DESC', tag: name),
    ),
  );
}

/// Opens the tag explorer: every AniList tag by category, searchable; a tap opens its titles,
/// a long press its description.
void openAnilistTagExplorer(BuildContext context, {String category = 'anime'}) {
  AppRoutes.push<void>(context, AnilistTagExplorer(category: category));
}

/// Shows the description of [tag] in a sheet, with a button to its titles when [onBrowse].
Future<void> showAnilistTagInfo(BuildContext context, AnilistTag tag, {VoidCallback? onBrowse}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tag.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(tag.category,
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (tag.description != null) ...[
              const SizedBox(height: 12),
              Text(tag.description!, style: theme.textTheme.bodyMedium),
            ],
            if (onBrowse != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  Navigator.of(sheet).pop();
                  onBrowse();
                },
                child: Text(S.of(sheet).Als_Tag_Browse),
              ),
            ],
          ],
        ),
      );
    },
  );
}

/// The tags to include and exclude, picked from the whole list. Null when dismissed.
Future<({List<String> included, List<String> excluded})?> pickAnilistTags(
  BuildContext context, {
  required AnilistCatalogData catalog,
  required bool adultAllowed,
  required List<String> included,
  required List<String> excluded,
}) {
  return Navigator.of(context).push<({List<String> included, List<String> excluded})>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _TagList(
        catalog: catalog,
        adultAllowed: adultAllowed,
        picking: true,
        included: included,
        excluded: excluded,
      ),
    ),
  );
}

/// The tag explorer screen.
class AnilistTagExplorer extends StatefulWidget {
  final String category;
  final AnilistCatalog? catalog;
  final AnilistDiscoverService? service;

  const AnilistTagExplorer({super.key, this.category = 'anime', this.catalog, this.service});

  @override
  State<AnilistTagExplorer> createState() => _AnilistTagExplorerState();
}

class _AnilistTagExplorerState extends State<AnilistTagExplorer> {
  late Future<(AnilistCatalogData, bool)> _load = _fetch();

  Future<(AnilistCatalogData, bool)> _fetch({bool force = false}) async {
    final catalog = await (widget.catalog ?? AnilistCatalog.instance).load(force: force);
    final adult = await (widget.service ?? AnilistDiscoverService.instance).adultAllowed();
    return (catalog, adult);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(AnilistCatalogData, bool)>(
      future: _load,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(S.of(context).Als_Tags_Title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final (catalog, adult) = data;
        if (catalog.tags.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(S.of(context).Als_Tags_Title)),
            body: Center(
              child: HomeMessage(
                icon: Icons.cloud_off_outlined,
                text: S.of(context).Al_Load_Failed,
                actionLabel: S.of(context).Al_Retry,
                onAction: () => setState(() => _load = _fetch(force: true)),
              ),
            ),
          );
        }
        return _TagList(catalog: catalog, adultAllowed: adult, category: widget.category);
      },
    );
  }
}

/// The tag list, by category, with a search field. Explorer mode opens tags; picking mode
/// cycles each tag none → included → excluded and answers both lists.
class _TagList extends StatefulWidget {
  final AnilistCatalogData catalog;
  final bool adultAllowed;
  final bool picking;
  final String category;
  final List<String> included;
  final List<String> excluded;

  const _TagList({
    required this.catalog,
    required this.adultAllowed,
    this.picking = false,
    this.category = 'anime',
    this.included = const [],
    this.excluded = const [],
  });

  @override
  State<_TagList> createState() => _TagListState();
}

class _TagListState extends State<_TagList> {
  final TextEditingController _search = TextEditingController();
  String _text = '';
  late final List<String> _included = [...widget.included];
  late final List<String> _excluded = [...widget.excluded];

  /// Spoiler tags the user chose to see.
  final Set<int> _revealed = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Category headers (String) and tags (AnilistTag), filtered by the search text.
  List<Object> _rows() {
    final tags = widget.catalog.tagsFor(adult: widget.adultAllowed);
    final byCategory = <String, List<AnilistTag>>{};
    for (final t in tags) {
      if (_text.isNotEmpty && !t.name.toLowerCase().contains(_text)) continue;
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }
    final rows = <Object>[];
    for (final c in byCategory.keys.toList()..sort()) {
      rows.add(c);
      rows.addAll(byCategory[c]!..sort((a, b) => a.name.compareTo(b.name)));
    }
    return rows;
  }

  void _cycle(AnilistTag t) {
    setState(() {
      if (_included.remove(t.name)) {
        _excluded.add(t.name);
      } else if (!_excluded.remove(t.name)) {
        _included.add(t.name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rows = _rows();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _search,
          decoration: InputDecoration(hintText: s.Als_Tag_Search_Hint, border: InputBorder.none),
          onChanged: (v) => setState(() => _text = v.trim().toLowerCase()),
        ),
        actions: [
          if (widget.picking)
            TextButton(
              onPressed: () => Navigator.of(context).pop((included: _included, excluded: _excluded)),
              child: Text(s.Als_Apply),
            ),
        ],
      ),
      body: rows.isEmpty
          ? HomeMessage(icon: Icons.sell_outlined, text: s.Al_No_Results)
          : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                if (row is String) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(row, style: theme.textTheme.titleSmall?.copyWith(color: cs.primary)),
                  );
                }
                final tag = row as AnilistTag;
                final hidden = tag.isGeneralSpoiler && !_revealed.contains(tag.id);
                final included = _included.contains(tag.name);
                final excluded = _excluded.contains(tag.name);
                return ListTile(
                  dense: true,
                  title: Text(
                    hidden ? s.Asf_Spoiler : tag.name,
                    style: hidden ? TextStyle(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic) : null,
                  ),
                  leading: widget.picking
                      ? Icon(
                          included
                              ? Icons.check_box_rounded
                              : excluded
                                  ? Icons.indeterminate_check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                          color: included ? cs.primary : excluded ? cs.error : cs.onSurfaceVariant,
                        )
                      : null,
                  trailing: hidden ? Icon(Icons.visibility_outlined, color: cs.onSurfaceVariant) : null,
                  onTap: () {
                    if (hidden) {
                      setState(() => _revealed.add(tag.id));
                    } else if (widget.picking) {
                      _cycle(tag);
                    } else {
                      openAnilistTag(context, tag.name, category: widget.category);
                    }
                  },
                  onLongPress: hidden
                      ? null
                      : () => showAnilistTagInfo(
                            context,
                            tag,
                            onBrowse: widget.picking
                                ? null
                                : () => openAnilistTag(context, tag.name, category: widget.category),
                          ),
                );
              },
            ),
    );
  }
}
