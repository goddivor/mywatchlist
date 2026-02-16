import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/forum/club_comments_screen.dart';
import 'package:mywatchlist/screens/forum/club_forum_screen.dart';
import 'package:mywatchlist/screens/forum/club_members_screen.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/services/api/MAL/mal_clubs_api.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_data.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:url_launcher/url_launcher.dart';

/// Club detail screen matching DailyAL's ClubScreen.
class ClubScreen extends StatefulWidget {
  final ClubHtml clubHtml;

  const ClubScreen({super.key, required this.clubHtml});

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  final _clubsApi = MalClubsApi();
  ClubData? _clubData;
  final Map<String, String> _staffPositionMap = {};
  List<_VisibleSection> _visibleSections = [];
  final _regex = RegExp(r'font-size\s*:\s*[^;]+;');

  int get _id => widget.clubHtml.id!;

  @override
  void initState() {
    super.initState();
    _loadClubData();
  }

  Future<void> _loadClubData() async {
    _clubData = await _clubsApi.getClubData(_id);
    if (_clubData?.details?.staffs != null) {
      for (final staff in _clubData!.details!.staffs!) {
        final position = staff.position;
        final username = staff.user?.username;
        if (username != null && position != null) {
          _staffPositionMap[username] =
              position.replaceAll('(', '').replaceAll(')', '');
        }
      }
    }
    _visibleSections = _buildSections();
    if (mounted) setState(() {});
  }

  List<_VisibleSection> _buildSections() {
    if (_clubData == null) return [];
    final sections = <_VisibleSection>[];

    // General info
    if (_clubData!.information != null &&
        _clubData!.information!.isNotEmpty) {
      sections.add(_VisibleSection(
        'General',
        SingleChildScrollView(
          padding: const EdgeInsets.only(top: 20, bottom: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: HtmlWidget(
              (_clubData!.information ?? '').replaceAll(_regex, ''),
              textStyle: Theme.of(context).textTheme.bodyMedium,
              customWidgetBuilder: (element) {
                if (element.localName == 'img') {
                  final src = element.attributes['src'] ??
                      element.attributes['data-src'];
                  if (src != null && src.isNotEmpty) {
                    return GestureDetector(
                      onTap: () => zoomInImage(context, src),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: CachedNetworkImage(
                          imageUrl: src,
                          errorWidget: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    );
                  }
                }
                return null;
              },
            ),
          ),
        ),
      ));
    }

    // Comments
    if (_clubData!.comments != null && _clubData!.comments!.isNotEmpty) {
      sections.add(_VisibleSection('Comments', _buildComments()));
    }

    // Forum topics
    if (_clubData!.forumTopics != null &&
        _clubData!.forumTopics!.isNotEmpty) {
      sections.add(_VisibleSection('Forums', _buildForumTopics()));
    }

    // Staff
    if (_clubData!.details?.staffs != null &&
        _clubData!.details!.staffs!.isNotEmpty) {
      sections.add(_VisibleSection('Staff', _buildStaff()));
    }

    // Members
    if (_clubData!.members != null && _clubData!.members!.isNotEmpty) {
      sections.add(_VisibleSection('Members', _buildMembers()));
    }

    // Relations
    if (_clubData!.details?.clubRelations?.anime != null &&
        _clubData!.details!.clubRelations!.anime!.isNotEmpty) {
      sections.add(_VisibleSection(
        'Anime',
        _buildRelations(_clubData!.details!.clubRelations!.anime!, 'anime'),
      ));
    }
    if (_clubData!.details?.clubRelations?.manga != null &&
        _clubData!.details!.clubRelations!.manga!.isNotEmpty) {
      sections.add(_VisibleSection(
        'Manga',
        _buildRelations(_clubData!.details!.clubRelations!.manga!, 'manga'),
      ));
    }
    if (_clubData!.details?.clubRelations?.character != null &&
        _clubData!.details!.clubRelations!.character!.isNotEmpty) {
      sections.add(_VisibleSection(
        'Character',
        _buildRelations(
            _clubData!.details!.clubRelations!.character!, 'character'),
      ));
    }

    return sections;
  }

  String get _clubTitle =>
      _clubData?.title ?? widget.clubHtml.name ?? 'Club';

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_visibleSections.isNotEmpty) {
      child = DefaultTabController(
        length: _visibleSections.length,
        child: _nestedScrollView(),
      );
    } else {
      child = _nestedScrollView();
    }

    return Scaffold(
      body: child,
      floatingActionButton: _clubData == null
          ? null
          : FloatingActionButton(
              onPressed: () {
                final url =
                    'https://myanimelist.net/clubs.php?action=join&id=$_id';
                launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication);
              },
              child: const Icon(Icons.add),
            ),
    );
  }

  NestedScrollView _nestedScrollView() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        _appBar(innerBoxIsScrolled),
      ],
      body: _clubData == null
          ? _buildLoadingState()
          : TabBarView(
              children: _visibleSections
                  .map((e) => _KeepAliveWrapper(child: e.child))
                  .toList(),
            ),
    );
  }

  SliverAppBar _appBar(bool innerBoxIsScrolled) {
    return SliverAppBar(
      expandedHeight: 240.0,
      pinned: true,
      title: innerBoxIsScrolled ? Text(_clubTitle) : null,
      bottom: _visibleSections.isEmpty
          ? null
          : TabBar(
              tabs: _visibleSections
                  .map((e) => Tab(text: e.title))
                  .toList(),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
            ),
      flexibleSpace: FlexibleSpaceBar(
        background: _headerWidget(),
      ),
    );
  }

  Widget _headerWidget() {
    final imageUrl = _clubData?.details?.pictureUrl ?? widget.clubHtml.imgUrl;

    return Stack(
      children: [
        if (imageUrl != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => zoomInImage(context, imageUrl),
              child: Opacity(
                opacity: 0.3,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          _clubTitle,
                          textAlign: TextAlign.start,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (widget.clubHtml.desc != null) ...[
                        SB.h5,
                        Expanded(
                          flex: 4,
                          child: Text(
                            widget.clubHtml.desc ?? '',
                            textAlign: TextAlign.start,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ],
                      SB.h15,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembers() {
    final members = _clubData?.members ?? [];
    return CustomScrollView(
      slivers: [
        SB.lh20,
        SliverList.builder(
          itemCount: members.length,
          itemBuilder: (context, index) =>
              _buildMemberTile(members[index]),
        ),
        SB.lh10,
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton(
              onPressed: () => _openViewAllMembers(),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text('View All Members'),
            ),
          ),
        ),
        SB.lh30,
      ],
    );
  }

  void _openViewAllMembers() {
    gotoPage(
      context: context,
      newPage: ClubMembersScreen(
        clubId: _id,
        clubTitle: _clubTitle,
        staffPositionMap: _staffPositionMap,
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
            // Open MAL profile
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
                    if (_staffPositionMap.containsKey(username)) ...[
                      SB.h10,
                      _buildStaffBadge(username),
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

  Widget _buildStaff() {
    final staffs = _clubData?.details?.staffs ?? [];
    return ListView.builder(
      itemCount: staffs.length,
      itemBuilder: (context, index) {
        final staff = staffs[index];
        final username = staff.user?.username ?? '';
        return Padding(
          padding: const EdgeInsets.all(8.0),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(username),
                    if (_staffPositionMap.containsKey(username))
                      _buildStaffBadge(username),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaffBadge(String username) {
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          textStyle: const TextStyle(fontSize: 11),
        ),
        child: Text(_staffPositionMap[username]!),
      ),
    );
  }

  int _extractPostCount(String? replies) {
    if (replies == null) return 0;
    final match = RegExp(r'\d+').firstMatch(replies);
    if (match != null) {
      return (int.tryParse(match.group(0)!) ?? 0) + 1;
    }
    return 0;
  }

  Widget _buildForumTopics() {
    final topics = _clubData?.forumTopics ?? [];
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          sliver: SliverList.builder(
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topic = topics[index];
              final postCount = _extractPostCount(topic.replies);
              return ListTile(
                title: Text(
                  topic.title ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (topic.createdBy != null) topic.createdBy,
                    if (postCount > 0) '$postCount posts',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                trailing: topic.lastPostTime != null
                    ? Text(
                        topic.lastPostTime!,
                        style: Theme.of(context).textTheme.labelSmall,
                      )
                    : null,
                onTap: () {
                  if (topic.id != null) {
                    gotoPage(
                      context: context,
                      newPage: ForumPostsScreen(
                        topic: ForumTopicsData(
                          id: topic.id,
                          title: topic.title,
                          createdBy: ForumUser(name: topic.createdBy),
                          numberOfPosts: postCount > 0 ? postCount : null,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
        SB.lh10,
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton(
              onPressed: () => _openViewAllForumTopics(),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text('View All Topics'),
            ),
          ),
        ),
        SB.lh30,
      ],
    );
  }

  void _openViewAllForumTopics() {
    gotoPage(
      context: context,
      newPage: ClubForumScreen(
        clubId: _id,
        clubTitle: _clubTitle,
      ),
    );
  }

  Widget _buildComments() {
    final comments = _clubData?.comments ?? [];
    return CustomScrollView(
      slivers: [
        SB.lh20,
        SliverList.builder(
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            final username = comment.by?.username ?? '';
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      AvatarWidget(
                        url: comment.by?.imageUrl,
                        height: 40,
                        width: 40,
                      ),
                      SB.w10,
                      Text(
                        '$username · ${comment.longAgo ?? ''}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      SB.w10,
                      const Expanded(child: SizedBox()),
                      if (_staffPositionMap.containsKey(username))
                        _buildStaffBadge(username),
                    ],
                  ),
                  SB.h10,
                  if (comment.content != null)
                    HtmlWidget(
                      (comment.content ?? '').replaceAll(_regex, ''),
                      textStyle: Theme.of(context).textTheme.bodySmall,
                      customWidgetBuilder: (element) {
                        if (element.localName == 'img') {
                          final src = element.attributes['src'] ??
                              element.attributes['data-src'];
                          if (src != null && src.isNotEmpty) {
                            return GestureDetector(
                              onTap: () => zoomInImage(context, src),
                              child: CachedNetworkImage(
                                imageUrl: src,
                                errorWidget: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            );
                          }
                        }
                        return null;
                      },
                    ),
                  const Divider(),
                ],
              ),
            );
          },
        ),
        // View All button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton(
              onPressed: () => _openViewAllComments(),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text('View All Comments'),
            ),
          ),
        ),
        SB.lh40,
      ],
    );
  }

  void _openViewAllComments() {
    gotoPage(
      context: context,
      newPage: ClubCommentsScreen(
        clubId: _id,
        clubTitle: _clubTitle,
        staffPositionMap: _staffPositionMap,
      ),
    );
  }

  Widget _buildRelations(List<ClubRelation> relations, String category) {
    return CustomScrollView(
      slivers: [
        SB.lh20,
        SliverList.builder(
          itemCount: relations.length,
          itemBuilder: (context, index) {
            final relation = relations[index];
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListTile(
                title: Text(relation.title ?? '?'),
                onTap: () {
                  if (relation.id != null) {
                    if (category == 'character') {
                      launchUrl(
                        Uri.parse(
                            'https://myanimelist.net/character/${relation.id}'),
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      gotoPage(
                        context: context,
                        newPage: ContentDetailedScreen(
                          node: null,
                          id: relation.id,
                          category: category,
                        ),
                      );
                    }
                  }
                },
              ),
            );
          },
        ),
        SB.lh40,
      ],
    );
  }

  Widget _buildLoadingState() {
    return ShimmerColor(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Column(
          children: List.generate(
            6,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisibleSection {
  final String title;
  final Widget child;

  _VisibleSection(this.title, this.child);
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
