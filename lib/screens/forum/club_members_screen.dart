import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_clubs_api.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_data.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final _scrollController = ScrollController();
  final List<ClubMember> _members = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  static const _pageSize = 36;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final result = await _clubsApi.getClubViewAll(
        widget.clubId,
        'members',
        _currentOffset,
      );

      if (mounted) {
        final newMembers = (result ?? []).whereType<ClubMember>().toList();
        setState(() {
          _members.addAll(newMembers);
          _currentOffset += newMembers.length;
          _hasMore = newMembers.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Members${widget.clubTitle != null ? ' - ${widget.clubTitle}' : ''}',
        ),
      ),
      body: _members.isEmpty && _isLoading
          ? _buildLoading()
          : RefreshIndicator(
              onRefresh: () async {
                _members.clear();
                _currentOffset = 0;
                _hasMore = true;
                await _loadMembers();
              },
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _members.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _members.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _buildMemberTile(_members[index]);
                },
              ),
            ),
    );
  }

  Widget _buildMemberTile(ClubMember member) {
    final username = member.username ?? '';
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Card(
        child: InkWell(
          onTap: () {
            launchUrl(
              Uri.parse('https://myanimelist.net/profile/$username'),
              mode: LaunchMode.externalApplication,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                AvatarWidget(
                  url: member.imageUrl,
                  height: 55,
                  width: 55,
                ),
                SB.w15,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username),
                    if (widget.staffPositionMap.containsKey(username)) ...[
                      SB.h10,
                      SizedBox(
                        height: 30,
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          child:
                              Text(widget.staffPositionMap[username]!),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ShimmerColor(
      ListView.builder(
        itemCount: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
