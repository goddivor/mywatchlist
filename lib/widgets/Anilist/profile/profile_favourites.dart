import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart' show AnilistFavouriteKind;
import 'package:mywatchlist/services/api/Anilist/anilist_profile_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart'
    show AnilistSocialService;
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart'
    show openAnilistLink, openAnilistTitle;
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart'
    show anilistErrorText, runAnilistWrite;
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

String _kindTitle(S s, AnilistFavouriteKind kind) => switch (kind) {
      AnilistFavouriteKind.anime => s.Prof_Fav_Anime,
      AnilistFavouriteKind.manga => s.Prof_Fav_Manga,
      AnilistFavouriteKind.character => s.Prof_Fav_Characters,
      AnilistFavouriteKind.staff => s.Prof_Fav_People,
      AnilistFavouriteKind.studio => s.Al_Fav_Studios,
    };

/// A favourite opens its AniList page: titles the AniList title, characters, staff and studios
/// their native screen.
void openAnilistFavourite(BuildContext context, AnilistFavouriteKind kind, AnilistFavorite f) {
  if (kind == AnilistFavouriteKind.anime || kind == AnilistFavouriteKind.manga) {
    openAnilistTitle(context,
        category: kind == AnilistFavouriteKind.manga ? 'manga' : 'anime', id: f.id);
  } else {
    openAnilistLink(context, f.url);
  }
}

/// Favourites tab: the five kinds as grids, each with "View all" past the first twelve.
class AnilistFavouritesTab extends StatefulWidget {
  final AnilistProfile profile;
  final bool isSelf;
  final AnilistProfileService? service;

  const AnilistFavouritesTab({super.key, required this.profile, required this.isSelf, this.service});

  @override
  State<AnilistFavouritesTab> createState() => _AnilistFavouritesTabState();
}

class _AnilistFavouritesTabState extends State<AnilistFavouritesTab>
    with AutomaticKeepAliveClientMixin {
  /// How many of each kind the profile read (a full first page means there may be more).
  static const int _preview = 12;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final fav = widget.profile.favorites;
    final key = 'al_fav_${widget.profile.data.username}';
    if (fav.isEmpty) {
      return ProfileTabScroll(
        storageKey: key,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ProfileMessage(icon: Icons.favorite_border, title: s.Prof_Fav_Empty),
          ),
        ],
      );
    }
    final groups = <(AnilistFavouriteKind, List<AnilistFavorite>)>[
      (AnilistFavouriteKind.anime, fav.anime),
      (AnilistFavouriteKind.manga, fav.manga),
      (AnilistFavouriteKind.character, fav.characters),
      (AnilistFavouriteKind.staff, fav.staff),
      (AnilistFavouriteKind.studio, fav.studios),
    ];
    return ProfileTabScroll(
      storageKey: key,
      slivers: [
        for (final (kind, items) in groups)
          if (items.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_kindTitle(s, kind),
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (items.length >= _preview || widget.isSelf)
                      TextButton(
                        onPressed: () => AppRoutes.push<void>(
                          context,
                          AnilistFavouritesPage(
                            username: widget.profile.data.username,
                            kind: kind,
                            isSelf: widget.isSelf,
                            service: widget.service,
                          ),
                        ),
                        child: Text(widget.isSelf ? s.Alpp_View_Reorder : s.Alpp_View_All),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  childAspectRatio: 0.5,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => FavouriteTile(
                  favorite: items[i],
                  onTap: () => openAnilistFavourite(context, kind, items[i]),
                ),
              ),
            ),
          ],
      ],
    );
  }
}

/// One favourite as a cover (or an initial for a studio) with its name under it.
class FavouriteTile extends StatelessWidget {
  final AnilistFavorite favorite;
  final VoidCallback onTap;

  const FavouriteTile({super.key, required this.favorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: FavouriteImage(favorite: favorite)),
            const SizedBox(height: 6),
            Text(favorite.title,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class FavouriteImage extends StatelessWidget {
  final AnilistFavorite favorite;
  final double? width;

  const FavouriteImage({super.key, required this.favorite, this.width});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (favorite.imageUrl == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
            color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
        child: SizedBox(
          width: width ?? double.infinity,
          child: Center(child: Icon(Icons.business_outlined, color: cs.onSurfaceVariant)),
        ),
      );
    }
    return AppImage(
      url: favorite.imageUrl,
      width: width ?? double.infinity,
      borderRadius: BorderRadius.circular(10),
      placeholderColor: cs.surfaceContainerHighest,
    );
  }
}

/// Every favourite of one kind of a user, in their order. On the own profile "Reorder" turns
/// the grid into a draggable list; Save sends the new order to AniList (only on that tap).
class AnilistFavouritesPage extends StatefulWidget {
  final String username;
  final AnilistFavouriteKind kind;
  final bool isSelf;
  final AnilistProfileService? service;

  const AnilistFavouritesPage({
    super.key,
    required this.username,
    required this.kind,
    required this.isSelf,
    this.service,
  });

  @override
  State<AnilistFavouritesPage> createState() => _AnilistFavouritesPageState();
}

class _AnilistFavouritesPageState extends State<AnilistFavouritesPage> {
  final List<AnilistFavorite> _items = [];
  int _page = 0;
  bool _loading = false;
  bool _hasNext = true;
  Object? _error;
  bool _reordering = false;
  bool _saving = false;
  List<AnilistFavorite> _before = const [];

  AnilistProfileService get _service => widget.service ?? AnilistProfileService.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasNext) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.loadFavourites(widget.username, widget.kind, page: _page + 1);
      if (!mounted) return;
      final known = {for (final f in _items) f.id};
      setState(() {
        _page++;
        _items.addAll(page.items.where((f) => !known.contains(f.id)));
        _hasNext = page.hasNext && page.items.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final done = await runAnilistWrite<bool>(context, () async {
      await _service.saveFavouriteOrder(widget.kind, [for (final f in _items) f.id]);
      return true;
    }, service: AnilistSocialService(signedIn: _service.signedIn));
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (done == true) _reordering = false;
    });
  }

  void _cancelReorder() => setState(() {
        _items
          ..clear()
          ..addAll(_before);
        _reordering = false;
      });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final canReorder = widget.isSelf && !_hasNext && _items.length > 1 && _error == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(_kindTitle(s, widget.kind)),
        actions: [
          if (_reordering) ...[
            IconButton(
              tooltip: s.Cancel,
              icon: const Icon(Icons.close),
              onPressed: _saving ? null : _cancelReorder,
            ),
            IconButton(
              tooltip: s.Alpp_Save_Order,
              icon: const Icon(Icons.check),
              onPressed: _saving ? null : _save,
            ),
          ] else if (canReorder)
            IconButton(
              tooltip: s.Alpp_Reorder,
              icon: const Icon(Icons.swap_vert),
              onPressed: () => setState(() {
                _before = List.of(_items);
                _reordering = true;
              }),
            ),
        ],
      ),
      body: _body(context, s),
    );
  }

  Widget _body(BuildContext context, S s) {
    if (_items.isEmpty) {
      if (_loading) return ProfileLoading(label: s.Prof_Loading);
      if (_error != null) {
        return ProfileMessage(
          icon: Icons.cloud_off_outlined,
          title: anilistErrorText(_error!),
          actionLabel: s.Prof_Retry,
          onAction: _load,
        );
      }
      return ProfileMessage(icon: Icons.favorite_border, title: s.Prof_Fav_Empty);
    }
    if (_reordering) {
      return ReorderableListView.builder(
        itemCount: _items.length,
        onReorder: (from, to) => setState(() {
          if (to > from) to--;
          _items.insert(to, _items.removeAt(from));
        }),
        itemBuilder: (context, i) {
          final f = _items[i];
          return ListTile(
            key: ValueKey(f.id),
            leading: SizedBox(width: 40, height: 56, child: FavouriteImage(favorite: f, width: 40)),
            title: Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: ReorderableDragStartListener(
              index: i,
              child: const Icon(Icons.drag_handle),
            ),
          );
        },
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600) _load();
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120,
          childAspectRatio: 0.5,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: _items.length,
        itemBuilder: (context, i) => FavouriteTile(
          favorite: _items[i],
          onTap: () => openAnilistFavourite(context, widget.kind, _items[i]),
        ),
      ),
    );
  }
}
