import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/screens/MAL/featured_screen.dart';
import 'package:mywatchlist/screens/MAL/interest_stack_detail_screen.dart';
import 'package:mywatchlist/screens/forum/club_screen.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart' show InterestStack;
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/services/api/MAL/models/mal_user_search.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_news_featured.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart' show userCountFormat, ratingFormat;
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/dub_icon.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';

/// Opens the detail screen of an anime or manga result.
void openMedia(BuildContext context, Anime item, String category) {
  gotoPage(
    context: context,
    newPage: ContentDetailedScreen(node: item, category: category),
  );
}

/// Icon of a category, for results that have no picture.
IconData iconForCategory(String category) {
  switch (category) {
    case SearchCategory.character:
      return Icons.face_rounded;
    case SearchCategory.person:
      return Icons.person_rounded;
    case SearchCategory.forum:
      return Icons.forum_rounded;
    case SearchCategory.club:
      return Icons.groups_rounded;
    case SearchCategory.news:
      return Icons.newspaper_rounded;
    case SearchCategory.featured:
      return Icons.article_rounded;
    case SearchCategory.interestStack:
      return Icons.layers_rounded;
    case SearchCategory.user:
      return Icons.person_rounded;
    default:
      return Icons.search_rounded;
  }
}

/// A picture of a fixed size with rounded corners painted by its decoration (one clip-free box,
/// no `ClipRRect` per result), a flat placeholder and an icon when the picture is missing.
class SearchThumb extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  final double radius;
  final IconData icon;

  const SearchThumb({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.radius = 8,
    this.icon = Icons.image_not_supported_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(radius);
    Widget flat(BuildContext context) => DecoratedBox(
          decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: borderRadius),
          child: SizedBox(
            width: width,
            height: height,
            child: Icon(icon, size: (width < height ? width : height) * 0.4, color: scheme.onSurfaceVariant),
          ),
        );
    if (url == null || url!.isEmpty) return flat(context);
    return AppImage(
      url: url,
      width: width,
      height: height,
      placeholder: (context) => DecoratedBox(
        decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: borderRadius),
        child: SizedBox(width: width, height: height),
      ),
      errorWidget: flat,
      imageBuilder: (context, provider) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          image: DecorationImage(image: provider, fit: BoxFit.cover),
        ),
        child: SizedBox(width: width, height: height),
      ),
    );
  }
}

/// How much an anime / manga list row shows.
enum MediaTileSize { compact, comfortable, spacious }

/// An anime or manga result row: cover, title, type and length, score and members (and status and
/// synopsis in the spacious size).
class MediaTile extends StatelessWidget {
  final Anime item;
  final String category;
  final MediaTileSize size;

  const MediaTile({
    super.key,
    required this.item,
    required this.category,
    this.size = MediaTileSize.comfortable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final (double w, double h) = switch (size) {
      MediaTileSize.compact => (40.0, 56.0),
      MediaTileSize.comfortable => (80.0, 112.0),
      MediaTileSize.spacious => (100.0, 140.0),
    };
    final length = _lengthText(item, category);
    final typeLine = [
      if (item.mediaType != null && item.mediaType!.isNotEmpty) item.mediaType!.toUpperCase(),
      if (length != null) length,
      if (size == MediaTileSize.spacious && item.status != null) item.status!.replaceAll('_', ' '),
    ].join(' · ');

    final meta = Row(
      children: [
        if (item.score > 0) ...[
          Icon(Icons.star_rounded, size: 16, color: AppColors.of(context).score.color),
          const SizedBox(width: 2),
          Text(
            ratingFormat.format(item.score),
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
        if (item.score > 0 && item.members > 0) Text('  ·  ', style: theme.textTheme.bodySmall),
        if (item.members > 0)
          Flexible(
            child: Text(
              S.current.Srch_Members(userCountFormat.format(item.members)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
    );

    return InkWell(
      onTap: () => openMedia(context, item, category),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: size == MediaTileSize.compact ? 4 : 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SearchThumb(url: item.imageUrl, width: w, height: h),
                if (category == SearchCategory.anime && size != MediaTileSize.compact)
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: DubStatusBadge(animeId: item.id, radius: 5),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: h,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: size == MediaTileSize.compact ? 2 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: (size == MediaTileSize.spacious
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleSmall)
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (typeLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        typeLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                    const Spacer(),
                    if (size == MediaTileSize.spacious &&
                        item.synopsis != null &&
                        item.synopsis!.isNotEmpty) ...[
                      Text(
                        item.synopsis!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                      const SizedBox(height: 6),
                    ],
                    meta,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _lengthText(Anime item, String category) {
    if (category == SearchCategory.manga) {
      if (item.numVolumes != null && item.numVolumes! > 0) {
        return S.current.Srch_Volumes_Short(item.numVolumes!);
      }
      return null;
    }
    if (item.numEpisodes != null && item.numEpisodes! > 0) {
      return S.current.Srch_Episodes_Short(item.numEpisodes!);
    }
    return null;
  }
}

/// A row with a picture (or icon), a title, up to two secondary lines and a trailing widget; the
/// shape of every non anime / manga result.
class EntityTile extends StatelessWidget {
  final Widget leading;
  final double leadingHeight;
  final String title;
  final String? subtitle;
  final String? meta;
  final IconData? metaIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final int titleLines;

  const EntityTile({
    super.key,
    required this.leading,
    required this.leadingHeight,
    required this.title,
    this.subtitle,
    this.meta,
    this.metaIcon,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.titleLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: leadingHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: titleLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                    if (meta != null && meta!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (metaIcon != null) ...[
                            Icon(metaIcon, size: 14, color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              meta!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// A character or a person (Jikan result: the score field carries the number of favorites).
class PersonTile extends StatelessWidget {
  final Anime item;
  final bool isCharacter;

  const PersonTile({super.key, required this.item, required this.isCharacter});

  @override
  Widget build(BuildContext context) {
    return EntityTile(
      leading: SearchThumb(
        url: item.imageUrl,
        width: 64,
        height: 90,
        icon: isCharacter ? Icons.face_rounded : Icons.person_rounded,
      ),
      leadingHeight: 90,
      title: item.title,
      meta: item.members > 0 ? S.current.Srch_Favorites_Count(userCountFormat.format(item.members)) : null,
      metaIcon: Icons.favorite_rounded,
      onTap: () => gotoPage(
        context: context,
        newPage: CharacterScreen(
          id: item.id,
          category: isCharacter ? SearchCategory.character : SearchCategory.person,
        ),
      ),
    );
  }
}

/// A forum topic from the forum search.
class ForumTopicTile extends StatelessWidget {
  final ForumTopicsData topic;

  const ForumTopicTile({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = topic.lastPostCreatedAt;
    final by = topic.createdBy?.name ?? '';
    final subtitle = [
      if (by.isNotEmpty) by,
      if (date != null) MaterialLocalizations.of(context).formatShortDate(date),
    ].join('  ·  ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        topic.title ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Text(
              S.current.Srch_Posts_Count(topic.numberOfPosts ?? 0),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
      onTap: topic.id == null
          ? null
          : () => gotoPage(context: context, newPage: ForumPostsScreen(topic: topic)),
    );
  }
}

/// A forum topic, club, article or other result of the "all" view, which MyAnimeList gives as
/// the shared [Anime] shape (`status` carries the author, `startDate` the date).
class AllItemTile extends StatelessWidget {
  final Anime item;
  final String category;

  const AllItemTile({super.key, required this.item, required this.category});

  @override
  Widget build(BuildContext context) {
    final byLine = [
      if (item.status != null && item.status!.isNotEmpty) S.current.Srch_By(item.status!),
      if (item.startDate != null && item.startDate!.isNotEmpty) item.startDate!,
    ].join('  ·  ');
    final isClub = category == SearchCategory.club;
    return EntityTile(
      leading: SearchThumb(
        url: item.imageUrl,
        width: 80,
        height: 100,
        icon: iconForCategory(category),
      ),
      leadingHeight: 100,
      title: item.title,
      titleLines: 3,
      subtitle: isClub || byLine.isEmpty ? null : byLine,
      meta: isClub && item.members > 0 ? S.current.Srch_Members(userCountFormat.format(item.members)) : null,
      metaIcon: isClub ? Icons.people_rounded : null,
      onTap: () => _open(context),
    );
  }

  void _open(BuildContext context) {
    switch (category) {
      case SearchCategory.forum:
        gotoPage(
          context: context,
          newPage: ForumPostsScreen(topic: ForumTopicsData(id: item.id, title: item.title)),
        );
      case SearchCategory.club:
        gotoPage(
          context: context,
          newPage: ClubScreen(
            clubHtml: ClubHtml(
              id: item.id,
              name: item.title,
              imgUrl: item.imageUrl.isNotEmpty ? item.imageUrl : null,
            ),
          ),
        );
      case SearchCategory.news:
      case SearchCategory.featured:
        gotoPage(
          context: context,
          newPage: FeaturedScreen(
            id: item.id,
            featureTitle: item.title,
            imgUrl: item.imageUrl,
            category: category,
          ),
        );
      case SearchCategory.anime:
      case SearchCategory.manga:
        openMedia(context, item, category);
    }
  }
}

/// A MyAnimeList user: a tap opens the profile, a long press the quick sheet.
class UserTile extends StatelessWidget {
  final MalUserNode user;

  const UserTile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EntityTile(
      leading: SearchThumb(url: user.imageUrl, width: 48, height: 48, radius: 24, icon: Icons.person_rounded),
      leadingHeight: 48,
      title: user.username,
      subtitle: user.lastOnline,
      trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
      onTap: () => openUserProfile(context, user.username),
      onLongPress: () => AppRoutes.openUserPop(context, tracker: AccountType.myanimelist, username: user.username),
    );
  }
}

/// Opens the MyAnimeList profile of [username]; search users are MyAnimeList users whatever the
/// active account is.
void openUserProfile(BuildContext context, String username) {
  AppRoutes.openUserProfile(context, tracker: AccountType.myanimelist, username: username);
}

/// A club from the club search (a map of the scraped fields).
class ClubTile extends StatelessWidget {
  final Map<String, dynamic> club;

  const ClubTile({super.key, required this.club});

  @override
  Widget build(BuildContext context) {
    final name = club['name'] as String? ?? '';
    final desc = club['desc'] as String? ?? '';
    final members = club['members'] as String? ?? '';
    final imgUrl = club['imgUrl'] as String?;
    final lastPostBy = club['lastPostBy'] as String?;
    final lastPostTime = club['lastPostTime'] as String?;
    final clubId = club['id'] as int?;
    final last = lastPostBy != null && lastPostTime != null ? '$lastPostBy · $lastPostTime' : null;
    return EntityTile(
      leading: SearchThumb(url: imgUrl, width: 70, height: 98, radius: 6, icon: Icons.groups_rounded),
      leadingHeight: 98,
      title: name,
      subtitle: desc.isEmpty ? null : desc,
      meta: [if (members.isNotEmpty) members, if (last != null) last].join('  ·  '),
      metaIcon: members.isNotEmpty ? Icons.people_rounded : null,
      onTap: clubId == null
          ? null
          : () => gotoPage(
                context: context,
                newPage: ClubScreen(
                  clubHtml: ClubHtml(id: clubId, name: name, imgUrl: imgUrl, desc: desc, members: members),
                ),
              ),
    );
  }
}

/// A news or featured article from the article search.
class ArticleTile extends StatelessWidget {
  final AnimeNewsOrFeaturedItem item;
  final bool isNews;

  const ArticleTile({super.key, required this.item, required this.isNews});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = item.tags.isEmpty
        ? const <String>[]
        : item.tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    return InkWell(
      onTap: () => gotoPage(
        context: context,
        newPage: FeaturedScreen(
          id: item.id,
          featureTitle: item.title,
          imgUrl: item.imageUrl,
          category: isNews ? SearchCategory.news : SearchCategory.featured,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchThumb(
              url: item.imageUrl,
              width: 100,
              height: 130,
              icon: isNews ? Icons.newspaper_rounded : Icons.article_rounded,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (item.text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          item.text,
                          overflow: TextOverflow.fade,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (tags.isNotEmpty)
                      Text(
                        tags.take(4).join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An interest stack (a map of the scraped fields); the stacked covers open the image viewer.
class StackTile extends StatelessWidget {
  final Map<String, dynamic> stack;

  const StackTile({super.key, required this.stack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = stack['title'] as String? ?? '';
    final username = stack['username'] as String?;
    final description = stack['description'] as String?;
    final entries = stack['entries'] as int?;
    final reStacks = stack['reStacks'] as int?;
    final imageUrls = (stack['imageUrls'] as List<dynamic>?)?.cast<String>() ?? const <String>[];
    final counts = [
      if (entries != null) S.current.Srch_Entries_Count(entries),
      if (reStacks != null) S.current.Srch_Restacks_Count(reStacks),
    ].join('  ·  ');

    return EntityTile(
      leading: GestureDetector(
        onTap: imageUrls.isEmpty ? null : () => zoomInImageList(context, imageUrls),
        child: SizedBox(
          width: 80,
          height: 100,
          child: imageUrls.isEmpty
              ? const SearchThumb(url: null, width: 50, height: 70, radius: 4, icon: Icons.layers_rounded)
              : Stack(
                  children: [
                    for (var i = (imageUrls.length > 3 ? 2 : imageUrls.length - 1); i >= 0; i--)
                      Positioned(
                        left: i * 12.0,
                        top: i * 6.0,
                        child: SearchThumb(url: imageUrls[i], width: 50, height: 70, radius: 4),
                      ),
                  ],
                ),
        ),
      ),
      leadingHeight: 100,
      title: title,
      subtitle: [
        if (username != null) S.current.Srch_By(username),
        if (description != null && description.isNotEmpty) description,
      ].join('\n'),
      meta: counts,
      onTap: () => gotoPage(
        context: context,
        newPage: InterestStackDetailScreen(stack: InterestStack.fromJson(stack)),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
