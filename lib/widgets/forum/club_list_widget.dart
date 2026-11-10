import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/forum/club_screen.dart';
import 'package:mywatchlist/services/api/MAL/mal_clubs_api.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/forum/forum_paged_list.dart';

/// MAL's club list, page after page, with a skeleton, an error state with Retry and pull to
/// refresh.
class ClubsTab extends StatefulWidget {
  const ClubsTab({super.key});

  @override
  State<ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends State<ClubsTab> {
  final _clubsApi = MalClubsApi();
  int _nextPage = 1;

  Future<List<ClubHtml>> _fetch(int loaded) async {
    final result = await _clubsApi.getClubs(page: _nextPage);
    // null = the request failed: the list shows its error state with Retry.
    if (result == null) throw StateError('clubs unavailable');
    _nextPage++;
    return result.clubs ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    return ForumPagedList<ClubHtml>(
      fetch: _fetch,
      // MAL's page size is not fixed: any page with clubs may have a next one.
      pageSize: 1,
      onRestart: () => _nextPage = 1,
      emptyTitle: S.current.Fc_Clubs_Empty,
      emptyIcon: Icons.groups_outlined,
      skeleton: const ForumSkeleton(count: 6, rowHeight: 92),
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemBuilder: (context, club) => ClubHtmlTile(club: club),
    );
  }
}

/// A club in a list: picture, name, description, last post and number of members.
class ClubHtmlTile extends StatelessWidget {
  final ClubHtml club;

  const ClubHtmlTile({super.key, required this.club});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lastPost = club.lastPostBy != null && club.lastPostTime != null
        ? '${club.lastPostBy} · ${club.lastPostTime}'
        : null;

    return InkWell(
      onTap: () {
        if (club.id != null) {
          gotoPage(context: context, newPage: ClubScreen(clubHtml: club));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClubPicture(url: club.imgUrl, width: 60, height: 84),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name ?? S.current.Fc_Club_Fallback_Title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (club.desc != null && club.desc!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      club.desc!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: lastPost == null
                            ? const SizedBox.shrink()
                            : Text(
                                lastPost,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                      ),
                      if (club.members != null) ...[
                        const SizedBox(width: 8),
                        ForumStatChip(icon: Icons.people_outline, label: club.members!),
                      ],
                    ],
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

/// A club's picture in a rounded rectangle, or a group icon when it has none.
class ClubPicture extends StatelessWidget {
  const ClubPicture({super.key, required this.url, required this.width, required this.height});

  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(child: Icon(Icons.groups_outlined, color: scheme.onSurfaceVariant)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null || url!.isEmpty
            ? fallback
            : AppImage(
                url: url,
                width: width,
                height: height,
                errorWidget: (_) => fallback,
              ),
      ),
    );
  }
}
