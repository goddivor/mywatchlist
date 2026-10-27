import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_clubs_api.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_data.dart';
import 'package:mywatchlist/widgets/forum/club_tiles.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/forum/forum_paged_list.dart';

/// Every member of a club, 36 per page. A tap opens the member's quick profile.
class ClubMembersScreen extends StatefulWidget {
  final int clubId;
  final String? clubTitle;
  final Map<String, String> staffPositionMap;

  const ClubMembersScreen({
    super.key,
    required this.clubId,
    this.clubTitle,
    this.staffPositionMap = const {},
  });

  @override
  State<ClubMembersScreen> createState() => _ClubMembersScreenState();
}

class _ClubMembersScreenState extends State<ClubMembersScreen> {
  final _clubsApi = MalClubsApi();

  Future<List<ClubMember>> _fetch(int offset) async =>
      (await _clubsApi.getClubViewAll(widget.clubId, 'members', offset))
          .whereType<ClubMember>()
          .toList();

  @override
  Widget build(BuildContext context) {
    final club = widget.clubTitle;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          club == null ? S.current.Fc_Tab_Members : S.current.Fc_Members_Title(club),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ForumPagedList<ClubMember>(
        fetch: _fetch,
        pageSize: 36,
        emptyTitle: S.current.Fc_Members_Empty,
        emptyIcon: Icons.groups_outlined,
        skeleton: const ForumSkeleton(count: 8, rowHeight: 64, round: true),
        itemBuilder: (context, member) =>
            ClubMemberTile(member: member, position: widget.staffPositionMap[member.username]),
      ),
    );
  }
}
