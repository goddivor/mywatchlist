import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_clubs_api.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_data.dart';
import 'package:mywatchlist/widgets/forum/club_tiles.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/forum/forum_paged_list.dart';

/// Every comment of a club, newest first, 20 per page.
class ClubCommentsScreen extends StatefulWidget {
  final int clubId;
  final String? clubTitle;
  final Map<String, String> staffPositionMap;

  const ClubCommentsScreen({
    super.key,
    required this.clubId,
    this.clubTitle,
    this.staffPositionMap = const {},
  });

  @override
  State<ClubCommentsScreen> createState() => _ClubCommentsScreenState();
}

class _ClubCommentsScreenState extends State<ClubCommentsScreen> {
  final _clubsApi = MalClubsApi();

  Future<List<ClubComment>> _fetch(int offset) async =>
      (await _clubsApi.getClubViewAll(widget.clubId, 'comments', offset))
          .whereType<ClubComment>()
          .toList();

  @override
  Widget build(BuildContext context) {
    final club = widget.clubTitle;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          club == null ? S.current.Fc_Tab_Comments : S.current.Fc_Comments_Title(club),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ForumPagedList<ClubComment>(
        fetch: _fetch,
        pageSize: 20,
        emptyTitle: S.current.Fc_Comments_Empty,
        emptyIcon: Icons.chat_bubble_outline,
        skeleton: const ForumSkeleton(count: 5, rowHeight: 96, round: true),
        itemBuilder: (context, comment) =>
            ClubCommentTile(comment: comment, position: widget.staffPositionMap[comment.by?.username]),
      ),
    );
  }
}
