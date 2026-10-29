import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumAvatar, ForumSkeleton;
import 'package:mywatchlist/widgets/home/home_sections.dart' show HomeMessage;

/// Opens the sheet of the people who liked a thread, comment, activity or reply.
Future<void> showAnilistLikes(
  BuildContext context, {
  required AnilistLikeable type,
  required int id,
  AnilistSocialService? service,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, controller) =>
          AnilistLikesList(type: type, id: id, controller: controller, service: service),
    ),
  );
}

/// The likers, page by page.
class AnilistLikesList extends StatefulWidget {
  const AnilistLikesList({
    super.key,
    required this.type,
    required this.id,
    this.controller,
    this.service,
  });

  final AnilistLikeable type;
  final int id;
  final ScrollController? controller;
  final AnilistSocialService? service;

  @override
  State<AnilistLikesList> createState() => _AnilistLikesListState();
}

class _AnilistLikesListState extends State<AnilistLikesList> {
  final List<AnilistSocialUser> _users = [];
  int _page = 0;
  bool _hasNext = true;
  bool _loading = false;
  Object? _error;

  AnilistSocialService get _service => widget.service ?? AnilistSocialService.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasNext) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.likes(widget.type, widget.id, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _users.addAll(page.items);
        _hasNext = page.hasNext && page.items.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(s.Als_Liked_By, style: theme.textTheme.titleMedium),
    );
    if (_users.isEmpty) {
      return ListView(
        controller: widget.controller,
        children: [
          header,
          if (_loading)
            const ForumSkeleton(count: 4, round: true)
          else if (_error != null)
            HomeMessage(
              icon: Icons.cloud_off_outlined,
              text: s.Al_Load_Failed,
              actionLabel: s.Al_Retry,
              onAction: _load,
            )
          else
            HomeMessage(icon: Icons.favorite_border, text: s.Als_No_Likes),
        ],
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 300) _load();
        return false;
      },
      child: ListView.builder(
        controller: widget.controller,
        itemCount: _users.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) return header;
          if (i > _users.length) {
            return _loading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
                  )
                : const SizedBox(height: 16);
          }
          final user = _users[i - 1];
          return ListTile(
            leading: ForumAvatar(username: user.name, url: user.avatarUrl, tappable: false),
            title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => openAnilistUser(context, user.name),
          );
        },
      ),
    );
  }
}
