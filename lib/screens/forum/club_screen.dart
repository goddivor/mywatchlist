import 'package:flutter/material.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/screens/forum/club_comments_screen.dart';
import 'package:mywatchlist/screens/forum/club_forum_screen.dart';
import 'package:mywatchlist/screens/forum/club_members_screen.dart';
import 'package:mywatchlist/services/api/MAL/mal_clubs_api.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_data.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_button.dart';
import 'package:mywatchlist/widgets/common/app_bar_menu.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';
import 'package:mywatchlist/widgets/forum/club_tiles.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';

/// A MyAnimeList club: description, comments, forum, staff, members and what it is about.
class ClubScreen extends StatefulWidget {
  final ClubHtml clubHtml;

  const ClubScreen({super.key, required this.clubHtml});

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _Section {
  final String title;
  final Widget Function() build;

  const _Section(this.title, this.build);
}

class _ClubScreenState extends State<ClubScreen> {
  final _clubsApi = MalClubsApi();
  ClubData? _clubData;
  bool _loading = true;
  bool _failed = false;
  Map<String, String> _staffPositions = const {};

  int get _id => widget.clubHtml.id!;

  @override
  void initState() {
    super.initState();
    _loadClubData();
  }

  Future<void> _loadClubData() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final data = await _clubsApi.getClubData(_id);
    if (!mounted) return;
    final positions = <String, String>{};
    for (final staff in data?.details?.staffs ?? const <ClubStaff>[]) {
      final position = staff.position?.replaceAll('(', '').replaceAll(')', '').trim();
      final username = staff.user?.username;
      if (username != null && position != null && position.isNotEmpty) {
        positions[username] = position;
      }
    }
    setState(() {
      _clubData = data;
      _staffPositions = positions;
      _loading = false;
      _failed = data == null;
    });
  }

  String get _clubTitle {
    final title = _clubData?.title ?? widget.clubHtml.name;
    return title == null || title.isEmpty ? S.current.Fc_Club_Fallback_Title : title;
  }

  String? get _imageUrl => _clubData?.details?.pictureUrl ?? widget.clubHtml.imgUrl;

  List<_Section> _sections() {
    final data = _clubData;
    if (data == null) return const [];
    final relations = data.details?.clubRelations;
    final staffs = data.details?.staffs ?? const <ClubStaff>[];
    return [
      _Section(S.current.Fc_Tab_General, _buildGeneral),
      if (data.comments?.isNotEmpty ?? false) _Section(S.current.Fc_Tab_Comments, _buildComments),
      if (data.forumTopics?.isNotEmpty ?? false) _Section(S.current.Fc_Tab_Forums, _buildForumTopics),
      if (staffs.isNotEmpty) _Section(S.current.Fc_Tab_Staff, _buildStaff),
      if (data.members?.isNotEmpty ?? false) _Section(S.current.Fc_Tab_Members, _buildMembers),
      if (relations?.anime?.isNotEmpty ?? false)
        _Section(S.current.Fc_Tab_Anime, () => _buildRelations(relations!.anime!, 'anime')),
      if (relations?.manga?.isNotEmpty ?? false)
        _Section(S.current.Fc_Tab_Manga, () => _buildRelations(relations!.manga!, 'manga')),
      if (relations?.character?.isNotEmpty ?? false)
        _Section(S.current.Fc_Tab_Characters, () => _buildRelations(relations!.character!, 'character')),
    ];
  }

  void _share() {
    final members = _clubData?.details?.members;
    showShareBuilder(
      context,
      subject: _clubTitle,
      fields: [
        ShareField(label: S.current.Fc_Field_Title, value: _clubTitle),
        if (members != null)
          ShareField(label: S.current.Fc_Tab_Members, value: S.current.Fc_Members_Count(members)),
        ShareField(label: S.current.Fc_Field_Link, value: ForumUrls.club(_id)),
      ],
    );
  }

  /// Shown once the club has loaded, so the saved title and picture are the club's own.
  Widget _bookmark() => _clubData == null
      ? const SizedBox.shrink()
      : BookmarkButton(
          tracker: 'myanimelist',
          kind: BookmarkKind.club,
          id: _id,
          title: _clubTitle,
          imageUrl: _imageUrl,
        );

  Widget _menu() => AppBarMenu(
        onShare: _share,
        onOpenInBrowser: () => launchWebView(ForumUrls.club(_id), context: context),
      );

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Scaffold(
        appBar: AppBar(title: Text(_clubTitle, maxLines: 1, overflow: TextOverflow.ellipsis), actions: [_menu()]),
        body: ForumMessage.error(onRetry: _loadClubData),
      );
    }

    final sections = _sections();
    final scaffold = Scaffold(
      floatingActionButton: _clubData == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => launchWebView(ForumUrls.joinClub(_id), context: context),
              icon: const Icon(Icons.group_add_outlined),
              label: Text(S.current.Fc_Join_Club),
            ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [_appBar(sections)],
        body: _loading
            ? const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: ForumSkeleton(count: 6, round: true),
              )
            : TabBarView(
                children: [for (final section in sections) _KeepAlive(child: section.build())],
              ),
      ),
    );
    if (sections.isEmpty) return scaffold;
    return DefaultTabController(
      key: ValueKey(sections.length),
      length: sections.length,
      child: scaffold,
    );
  }

  SliverAppBar _appBar(List<_Section> sections) {
    final scheme = Theme.of(context).colorScheme;
    final image = _imageUrl;
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      actions: [_bookmark(), _menu()],
      bottom: sections.isEmpty
          ? null
          : TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final section in sections) Tab(text: section.title)],
            ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 56, end: 56, bottom: 62),
        title: Text(
          _clubTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: scheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null && image.isNotEmpty)
              GestureDetector(
                onTap: () => zoomInImage(context, image),
                child: AppImage(url: image, errorWidget: (_) => const SizedBox.shrink()),
              ),
            // A plain gradient (no blur, no Opacity) keeps the title readable over any picture.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.surface.withValues(alpha: 0.55),
                    scheme.surface.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewAllButton(String label, Widget Function() page) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: OutlinedButton(
          onPressed: () => gotoPage(context: context, newPage: page()),
          child: Text(label),
        ),
      );

  Widget _buildGeneral() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = _clubData?.details;
    final info = _clubData?.information;
    final desc = widget.clubHtml.desc;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (details?.members != null)
              ForumStatChip(
                icon: Icons.people_outline,
                label: S.current.Fc_Members_Count(details!.members!),
              ),
            if (details?.category != null && details!.category!.isNotEmpty)
              ForumStatChip(icon: Icons.category_outlined, label: details.category!),
            if (details?.created != null && details!.created!.isNotEmpty)
              ForumStatChip(icon: Icons.event_outlined, label: details.created!),
          ],
        ),
        const SizedBox(height: 16),
        if (info != null && info.isNotEmpty)
          MalHtmlBody(info, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface))
        else
          Text(
            desc != null && desc.isNotEmpty ? desc : S.current.Fc_Club_Info_Empty,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _buildComments() {
    final comments = _clubData?.comments ?? const <ClubComment>[];
    return ListView.builder(
      itemCount: comments.length + 1,
      itemBuilder: (context, index) {
        if (index == comments.length) {
          return _viewAllButton(
            S.current.Fc_View_All_Comments,
            () => ClubCommentsScreen(
              clubId: _id,
              clubTitle: _clubTitle,
              staffPositionMap: _staffPositions,
            ),
          );
        }
        final comment = comments[index];
        return ClubCommentTile(comment: comment, position: _staffPositions[comment.by?.username]);
      },
    );
  }

  Widget _buildForumTopics() {
    final topics = _clubData?.forumTopics ?? const <ClubForumTopic>[];
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: topics.length + 1,
      itemBuilder: (context, index) {
        if (index == topics.length) {
          return _viewAllButton(
            S.current.Fc_View_All_Topics,
            () => ClubForumScreen(clubId: _id, clubTitle: _clubTitle),
          );
        }
        return ClubTopicTile(topic: topics[index]);
      },
    );
  }

  Widget _buildStaff() {
    final staffs = _clubData?.details?.staffs ?? const <ClubStaff>[];
    if (staffs.isEmpty) {
      return ForumMessage(
        icon: Icons.badge_outlined,
        title: S.current.Fc_Staff_Empty,
        scrollable: false,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: staffs.length,
      itemBuilder: (context, index) {
        final staff = staffs[index];
        final member = staff.user ?? ClubMember();
        return ClubMemberTile(member: member, position: _staffPositions[member.username]);
      },
    );
  }

  Widget _buildMembers() {
    final members = _clubData?.members ?? const <ClubMember>[];
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: members.length + 1,
      itemBuilder: (context, index) {
        if (index == members.length) {
          return _viewAllButton(
            S.current.Fc_View_All_Members,
            () => ClubMembersScreen(
              clubId: _id,
              clubTitle: _clubTitle,
              staffPositionMap: _staffPositions,
            ),
          );
        }
        final member = members[index];
        return ClubMemberTile(member: member, position: _staffPositions[member.username]);
      },
    );
  }

  Widget _buildRelations(List<ClubRelation> relations, String category) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: relations.length,
      itemBuilder: (context, index) {
        final relation = relations[index];
        return ListTile(
          title: Text(
            relation.title ?? '?',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurface),
          ),
          trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          onTap: relation.id == null
              ? null
              : () => gotoPage(
                    context: context,
                    newPage: category == 'character'
                        ? CharacterScreen(id: relation.id!, category: 'character')
                        : ContentDetailedScreen(node: null, id: relation.id, category: category),
                  ),
        );
      },
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
