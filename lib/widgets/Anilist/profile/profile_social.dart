import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_follow_service.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_actions.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart' show openAnilistUser;
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart'
    show AnilistPageFooter, anilistErrorText;
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// One row of a user list: picture, name, "follows you", and a Follow button for the other
/// users when the viewer is signed in.
class AnilistUserTile extends StatelessWidget {
  final AnilistUserRow user;
  final bool showFollow;
  final ValueChanged<bool>? onFollowChanged;
  final AnilistFollowService? service;

  const AnilistUserTile({
    super.key,
    required this.user,
    this.showFollow = true,
    this.onFollowChanged,
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return ListTile(
      leading: AnilistAvatar(name: user.name, url: user.avatarUrl, size: 44),
      title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: user.isFollower
          ? Text(user.isFollowing ? s.Alpp_Follow_Each_Other : s.Alpp_Follows_You,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          : null,
      trailing: showFollow
          ? AnilistFollowButton(
              userId: user.id,
              isFollowing: user.isFollowing,
              compact: true,
              service: service,
              onChanged: (state) => onFollowChanged?.call(state.isFollowing),
            )
          : null,
      onTap: () => openAnilistUser(context, user.name),
    );
  }
}

/// Social tab: Followers, Following and Mutual of a user, page by page.
class AnilistSocialTab extends StatefulWidget {
  final int userId;
  final String username;
  final bool isSelf;
  final AnilistSocialList initial;
  final AnilistFollowService? service;

  const AnilistSocialTab({
    super.key,
    required this.userId,
    required this.username,
    required this.isSelf,
    this.initial = AnilistSocialList.followers,
    this.service,
  });

  @override
  State<AnilistSocialTab> createState() => AnilistSocialTabState();
}

class AnilistSocialTabState extends State<AnilistSocialTab> with AutomaticKeepAliveClientMixin {
  late AnilistSocialList _list = widget.initial;
  final List<AnilistUserRow> _users = [];
  int _page = 0;
  int _generation = 0;
  bool _loading = false;
  bool _hasNext = true;
  Object? _error;

  AnilistFollowService get _service => widget.service ?? AnilistFollowService.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Switches to [list] (the Overview counters call this).
  void show(AnilistSocialList list) {
    if (list == _list) return;
    setState(() {
      _list = list;
      _reset();
    });
    _load();
  }

  void _reset() {
    _generation++;
    _users.clear();
    _page = 0;
    _hasNext = true;
    _loading = false;
    _error = null;
  }

  Future<void> _load() async {
    if (_loading || !_hasNext) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // A mutual page may come back empty while more pages exist: keep reading a few so
      // the tab does not look finished.
      var attempts = 0;
      while (true) {
        final page = await _service.users(widget.userId, _list,
            page: _page + 1, self: widget.isSelf);
        if (!mounted || generation != _generation) return;
        _page++;
        final known = {for (final u in _users) u.id};
        _users.addAll(page.users.where((u) => !known.contains(u.id)));
        _hasNext = page.hasNext;
        attempts++;
        if (_users.isNotEmpty || !_hasNext || attempts >= 4) break;
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final signedIn = _service.signedIn;
    final lists = [
      AnilistSocialList.followers,
      AnilistSocialList.following,
      if (signedIn) AnilistSocialList.mutual,
    ];
    String label(AnilistSocialList l) => switch (l) {
          AnilistSocialList.followers => s.Alpp_Followers,
          AnilistSocialList.following => s.Alpp_Following,
          AnilistSocialList.mutual => s.Alpp_Mutual,
        };
    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: SegmentedButton<AnilistSocialList>(
          showSelectedIcon: false,
          segments: [for (final l in lists) ButtonSegment(value: l, label: Text(label(l)))],
          selected: {lists.contains(_list) ? _list : lists.first},
          onSelectionChanged: (v) => show(v.first),
        ),
      ),
    );
    final Widget body;
    if (_users.isEmpty) {
      final Widget message;
      if (_loading) {
        message = ProfileLoading(label: s.Prof_Loading);
      } else if (_error != null) {
        message = ProfileMessage(
          icon: Icons.cloud_off_outlined,
          title: anilistErrorText(_error!),
          actionLabel: s.Prof_Retry,
          onAction: _load,
        );
      } else {
        message = ProfileMessage(icon: Icons.group_outlined, title: s.Alpp_Social_Empty);
      }
      body = SliverFillRemaining(hasScrollBody: false, child: message);
    } else {
      body = SliverList.builder(
        itemCount: _users.length + 1,
        itemBuilder: (context, i) {
          if (i == _users.length) {
            if (_hasNext && !_loading && _error == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _load();
              });
            }
            return _hasNext || _error != null
                ? AnilistPageFooter(loading: _loading, failed: _error != null, onRetry: _load)
                : const SizedBox.shrink();
          }
          final u = _users[i];
          return AnilistUserTile(
            key: ValueKey(u.id),
            user: u,
            showFollow: signedIn,
            service: widget.service,
            onFollowChanged: (following) {
              final at = _users.indexWhere((x) => x.id == u.id);
              if (at >= 0) _users[at] = _users[at].copyWith(isFollowing: following);
            },
          );
        },
      );
    }
    return ProfileTabScroll(
      storageKey: 'al_social_${widget.username}',
      slivers: [header, body],
    );
  }
}
