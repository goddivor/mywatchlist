import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// Favorite anime, manga, characters and people: one horizontal shelf per non-empty list.
/// The data comes with the profile (Jikan part): while Jikan is still being asked the tab
/// says so, and when it failed it offers Retry instead of claiming "no favorites".
class FavoritesSection extends StatelessWidget {
  final ProfileFavorites favorites;
  final String username;
  final ProfileExtras extras;
  final VoidCallback? onRetry;

  const FavoritesSection({
    super.key,
    required this.favorites,
    required this.username,
    this.extras = ProfileExtras.ready,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (favorites.isEmpty) {
      final Widget state = switch (extras) {
        ProfileExtras.loading => ProfileLoading(label: s.Pp_Extras_Loading),
        ProfileExtras.unavailable => ProfileMessage(
            icon: Icons.cloud_off_outlined,
            title: s.Pp_Extras_Unavailable,
            actionLabel: onRetry == null ? null : s.Prof_Retry,
            onAction: onRetry,
          ),
        ProfileExtras.ready =>
          ProfileMessage(icon: Icons.favorite_border, title: s.Prof_Fav_Empty),
      };
      return ProfileTabScroll(
        storageKey: 'favorites_$username',
        slivers: [SliverFillRemaining(hasScrollBody: false, child: state)],
      );
    }
    final shelves = <(String, List<ProfileFavorite>, void Function(BuildContext, ProfileFavorite))>[
      if (favorites.anime.isNotEmpty)
        (s.Prof_Fav_Anime, favorites.anime, (c, f) => AppRoutes.openContent(c, id: f.id)),
      if (favorites.manga.isNotEmpty)
        (
          s.Prof_Fav_Manga,
          favorites.manga,
          (c, f) => AppRoutes.openContent(c, id: f.id, category: 'manga')
        ),
      if (favorites.characters.isNotEmpty)
        (
          s.Prof_Fav_Characters,
          favorites.characters,
          (c, f) => gotoPage(context: c, newPage: CharacterScreen(id: f.id))
        ),
      if (favorites.people.isNotEmpty)
        (
          s.Prof_Fav_People,
          favorites.people,
          (c, f) => gotoPage(context: c, newPage: CharacterScreen(id: f.id, category: 'person'))
        ),
    ];
    return ProfileTabScroll(
      storageKey: 'favorites_$username',
      slivers: [
        SliverList.builder(
          itemCount: shelves.length,
          itemBuilder: (context, i) => _Shelf(
            title: shelves[i].$1,
            items: shelves[i].$2,
            onTap: shelves[i].$3,
          ),
        ),
      ],
    );
  }
}

class _Shelf extends StatelessWidget {
  final String title;
  final List<ProfileFavorite> items;
  final void Function(BuildContext, ProfileFavorite) onTap;

  static const double _cardWidth = 100;
  static const double _imageHeight = 142;

  const _Shelf({required this.title, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Text(
                '${items.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: _imageHeight + 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return SizedBox(
                width: _cardWidth + 8,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onTap(context, item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppImage(
                          url: item.imageUrl,
                          width: _cardWidth,
                          height: _imageHeight,
                          borderRadius: BorderRadius.circular(10),
                          placeholderColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
