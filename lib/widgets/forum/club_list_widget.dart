import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/forum/club_screen.dart';
import 'package:mywatchlist/services/api/MAL/mal_clubs_api.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

/// Displays a paginated list of MAL clubs with load-more.
class ClubListWidget extends StatefulWidget {
  final ClubListHtml clubListHtml;

  const ClubListWidget({super.key, required this.clubListHtml});

  @override
  State<ClubListWidget> createState() => _ClubListWidgetState();
}

class _ClubListWidgetState extends State<ClubListWidget> {
  final _clubsApi = MalClubsApi();
  late List<ClubHtml> _clubs;
  int _pageIndex = 0;
  bool _loadingMore = false;
  bool _noMoreContent = false;

  @override
  void initState() {
    super.initState();
    _clubs = widget.clubListHtml.clubs ?? [];
    if (_clubs.isNotEmpty) _pageIndex = 1;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _noMoreContent) return;
    setState(() => _loadingMore = true);

    _pageIndex++;
    final result = await _clubsApi.getClubs(page: _pageIndex);

    if (result?.clubs != null && result!.clubs!.isNotEmpty) {
      _clubs.addAll(result.clubs!);
    } else {
      _noMoreContent = true;
    }

    _loadingMore = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_clubs.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No clubs found')),
      );
    }

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 90),
      shrinkWrap: true,
      children: [
        ListView.builder(
          itemCount: _clubs.length,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemBuilder: (_, index) => ClubHtmlTile(club: _clubs[index]),
        ),
        const SizedBox(height: 10),
        if (_noMoreContent)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text('No more clubs'),
            ),
          )
        else if (_loadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: OutlinedButton(
              onPressed: _loadMore,
              child: const Text('Load More'),
            ),
          ),
      ],
    );
  }
}

/// Individual club tile showing image, name, description, members, and last post.
class ClubHtmlTile extends StatelessWidget {
  final ClubHtml club;

  const ClubHtmlTile({super.key, required this.club});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        if (club.id != null) {
          gotoPage(
            context: context,
            newPage: ClubScreen(clubHtml: club),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Club image
            SizedBox(
              width: 60,
              child: AspectRatio(
                aspectRatio: 100 / 140,
                child: club.imgUrl != null && club.imgUrl!.isNotEmpty
                    ? AvatarWidget(
                        height: 84,
                        width: 60,
                        radius: BorderRadius.circular(4),
                        isNetworkImage: true,
                        url: club.imgUrl,
                        userRoundBorderforLoading: false,
                        borderWidth: 0,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.groups_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Club info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name ?? 'Club',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (club.desc != null && club.desc!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      club.desc!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (club.lastPostBy != null &&
                          club.lastPostTime != null) ...[
                        Expanded(
                          child: Text(
                            '${club.lastPostBy} · ${club.lastPostTime}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (club.members != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                club.members!,
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
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

/// Shimmer loading placeholder for clubs.
class ClubsShimmer extends StatelessWidget {
  const ClubsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerColor(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          children: List.generate(
            6,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: 160,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 10,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
