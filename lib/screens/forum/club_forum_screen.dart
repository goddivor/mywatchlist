import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_clubs_api.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_data.dart';
import 'package:mywatchlist/widgets/forum/club_tiles.dart';
import 'package:mywatchlist/widgets/forum/forum_paged_list.dart';

/// Every forum topic of a club, 50 per page.
class ClubForumScreen extends StatefulWidget {
  final int clubId;
  final String? clubTitle;

  const ClubForumScreen({
    super.key,
    required this.clubId,
    this.clubTitle,
  });

  @override
  State<ClubForumScreen> createState() => _ClubForumScreenState();
}

class _ClubForumScreenState extends State<ClubForumScreen> {
  final _clubsApi = MalClubsApi();

  Future<List<ClubForumTopic>> _fetch(int offset) async =>
      (await _clubsApi.getClubViewAll(widget.clubId, 'forum', offset))
          .whereType<ClubForumTopic>()
          .toList();

  @override
  Widget build(BuildContext context) {
    final club = widget.clubTitle;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          club == null ? S.current.Fc_Tab_Forums : S.current.Fc_Forums_Title(club),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ForumPagedList<ClubForumTopic>(
        fetch: _fetch,
        pageSize: 50,
        emptyTitle: S.current.Fc_Topics_Empty_Title,
        emptyBody: S.current.Fc_Topics_Empty_Body,
        emptyIcon: Icons.forum_outlined,
        itemBuilder: (context, topic) => ClubTopicTile(topic: topic),
      ),
    );
  }
}
