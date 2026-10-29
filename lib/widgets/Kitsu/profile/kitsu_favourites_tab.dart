import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart' show ProfileTabScroll;
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_profile.dart' show KitsuProfile;
import 'package:mywatchlist/services/api/Kitsu/kitsu_social.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_profile_rows.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

enum _Kind { anime, manga, character, person }

/// The "Favorites" tab: favourite anime and manga as posters, favourite characters and people as
/// portraits. Each kind loads the first time its chip is picked.
class KitsuFavouritesTab extends StatefulWidget {
  final KitsuProfile profile;
  final KitsuSocial? social;

  const KitsuFavouritesTab({super.key, required this.profile, this.social});

  @override
  State<KitsuFavouritesTab> createState() => _KitsuFavouritesTabState();
}

class _KitsuFavouritesTabState extends State<KitsuFavouritesTab>
    with AutomaticKeepAliveClientMixin {
  _Kind _kind = _Kind.anime;
  final Map<_Kind, Future<List<KitsuFavourite>>> _futures = {};

  @override
  bool get wantKeepAlive => true;

  Future<List<KitsuFavourite>> _future(_Kind kind) => _futures.putIfAbsent(
      kind,
      () => (widget.social ?? KitsuSocial.instance).favourites(
          widget.profile.handle,
          switch (kind) {
            _Kind.anime => 'Anime',
            _Kind.manga => 'Manga',
            _Kind.character => 'Character',
            _Kind.person => 'Person',
          }));

  String _label(S s, _Kind kind) => switch (kind) {
        _Kind.anime => s.Prof_Anime,
        _Kind.manga => s.Prof_Manga,
        _Kind.character => s.Kitsu_Fav_Characters,
        _Kind.person => s.Kitsu_Fav_People,
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    return ProfileTabScroll(
      storageKey: 'kitsu_favorites_${widget.profile.id}',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final kind in _Kind.values)
                  ChoiceChip(
                    label: Text(_label(s, kind)),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
          ),
        ),
        FutureBuilder<List<KitsuFavourite>>(
          key: ValueKey('kitsu_fav_${_kind.name}'),
          future: _future(_kind),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.all(32), child: ProfileLoading()),
              );
            }
            if (snapshot.hasError) {
              return SliverToBoxAdapter(
                child: SizedBox(
                  height: 260,
                  child: ProfileMessage(
                    icon: Icons.cloud_off_outlined,
                    title: s.Prof_Error_Title,
                    body: s.Prof_Error_Body,
                    actionLabel: s.Prof_Retry,
                    onAction: () => setState(() => _futures.remove(_kind)),
                  ),
                ),
              );
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(s.Kitsu_Favorites_Empty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              );
            }
            final people = items;
            return SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.58,
                ),
                itemCount: people.length,
                itemBuilder: (context, i) => _PortraitTile(
                    key: ValueKey(people[i].id), favourite: people[i]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PortraitTile extends StatelessWidget {
  final KitsuFavourite favourite;

  const _PortraitTile({super.key, required this.favourite});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isTitle = favourite.type == 'Anime' || favourite.type == 'Manga';
    final path = favourite.type == 'Character' ? 'characters' : 'people';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => isTitle
          ? KitsuTitleLinks.opener(
              context,
              favourite.type == 'Manga' ? KitsuMediaKind.manga : KitsuMediaKind.anime,
              favourite.itemId,
              favourite.slug)
          : launchWebView('https://kitsu.app/$path/${favourite.slug ?? favourite.itemId}',
              context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppImage(
              url: favourite.image?.url,
              width: double.infinity,
              borderRadius: BorderRadius.circular(8),
              placeholderColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Text(favourite.name,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
