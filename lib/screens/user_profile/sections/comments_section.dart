import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show gotoPage, showConfirmationDialog;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/api/MAL/web/profile_comments_api.dart';
import 'package:mywatchlist/services/auth/mal_auth_v2.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/widgets/user/profile/profile_comments.dart';
import 'package:mywatchlist/widgets/user/profile/profile_comments_conversation.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// The comments of a MyAnimeList profile (MALClient's Comments tab): readable on every
/// profile without a website session; with it, MAL's own form and actions (post, reply,
/// delete, conversation).
class CommentsSection extends StatefulWidget {
  final String username;

  /// Overrides for tests.
  final ProfileCommentsApi? api;
  final MalWebSession? session;

  const CommentsSection({super.key, required this.username, this.api, this.session});

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> with AutomaticKeepAliveClientMixin {
  late final ProfileCommentsApi _api = widget.api ?? ProfileCommentsApi();
  MalWebSession get _session => widget.session ?? MalWebSession.instance;

  List<ProfileComment> _items = const [];
  int? _memberId;
  int? _total;
  bool _canPost = false;
  String? _profileName;
  bool _loading = true;
  Object? _error;
  bool _loadingMore = false;
  bool _moreFailed = false;
  bool _hasMore = false;
  int _nextOffset = 0;
  int _generation = 0;
  MalWebSessionState? _lastState;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
    _load();
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    super.dispose();
  }

  /// A session that appears (reconnect) or dies changes what MAL shows: read the page again.
  void _onSession() {
    final state = _session.state;
    final before = _lastState;
    _lastState = state;
    if (before == null || before == state || state == MalWebSessionState.loading) return;
    if (state == MalWebSessionState.connected || before == MalWebSessionState.connected) {
      _load();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _session.ensureLoaded();
      _lastState ??= _session.state;
      ProfileCommentsPage page;
      try {
        page = await _api.profile(widget.username);
      } on MalWebSessionExpired {
        // The session is marked expired; read the public page.
        page = await _api.profile(widget.username);
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = page.comments;
        _memberId = page.memberId;
        _total = page.total;
        _canPost = page.canPost;
        _profileName = page.profileUsername;
        _nextOffset = page.comments.length;
        _hasMore = _memberId != null && (_total ?? 0) > page.comments.length;
        _moreFailed = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final memberId = _memberId;
    if (_loadingMore || !_hasMore || memberId == null) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      final page = await _api.page(memberId, _nextOffset);
      if (!mounted || generation != _generation) return;
      final known = {for (final c in _items) c.id};
      final fresh = page.comments.where((c) => known.add(c.id)).toList();
      setState(() {
        _items = [..._items, ...fresh];
        _nextOffset += page.comments.length;
        _total = page.total ?? _total;
        _hasMore = page.comments.isNotEmpty && fresh.isNotEmpty && (_total == null || _items.length < _total!);
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _moreFailed = true;
      });
    }
  }

  String get _profileUrl => '${MalWebClient.base}/profile/${Uri.encodeComponent(widget.username)}';

  Future<bool> _post(String text) async {
    final memberId = _memberId;
    if (memberId == null) return false;
    try {
      await _api.post(memberId: memberId, username: _profileName ?? widget.username, text: text);
    } catch (e) {
      if (mounted) showCommentSnack(context, commentErrorText(e));
      return false;
    }
    if (mounted) showCommentSnack(context, S.current.Ms_Comment_Posted);
    await _load();
    return true;
  }

  Future<void> _delete(ProfileComment comment) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      alertTitle: S.current.Ms_Comment_Delete_Confirm,
    );
    if (!confirmed || !mounted) return;
    try {
      await _api.delete(comment.id, referer: _profileUrl);
    } catch (e) {
      if (mounted) showCommentSnack(context, commentErrorText(e));
      return;
    }
    if (!mounted) return;
    setState(() {
      _items = _items.where((c) => c.id != comment.id).toList();
      if (_total != null && _total! > 0) _total = _total! - 1;
    });
    showCommentSnack(context, S.current.Ms_Comment_Deleted);
    await _load();
  }

  void _reply(ProfileComment comment) {
    final memberId = comment.replyToMemberId;
    if (memberId == null) return;
    showCommentReplySheet(
      context,
      to: comment.author,
      onSend: (text) async {
        try {
          await _api.reply(memberId: memberId, text: text, referer: _profileUrl);
        } catch (e) {
          if (mounted) showCommentSnack(context, commentErrorText(e));
          return false;
        }
        if (mounted) showCommentSnack(context, S.current.Ms_Comment_Posted);
        return true;
      },
    );
  }

  void _openConversation(ProfileComment comment) {
    final url = comment.conversationUrl;
    if (url == null) return;
    gotoPage(context: context, newPage: CommentConversationScreen(url: url, api: _api));
  }

  /// A signed-in MAL account without a working website session may reconnect in one tap.
  bool get _offerConnect {
    final state = _session.state;
    if (state != MalWebSessionState.none && state != MalWebSessionState.expired) return false;
    final mal = UserMalV2.instance;
    return mal.accessToken != null || mal.needsReLogin;
  }

  Widget? _header(BuildContext context) {
    final s = S.of(context);
    if (_session.isConnected && _canPost && _memberId != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: ProfileCommentComposer(onSend: _post),
      );
    }
    if (_offerConnect) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: CommentConnectRow(
          label: _session.state == MalWebSessionState.expired
              ? s.Ms_Session_Expired
              : s.Ms_Connect_To_Comment,
          onConnect: () => MalAuthV2().handleSignIn(context: context),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final storageKey = 'comments_${widget.username}';
    if (_loading && _items.isEmpty) {
      return ProfileTabScroll(storageKey: storageKey, slivers: const [
        SliverFillRemaining(hasScrollBody: false, child: ProfileLoading()),
      ]);
    }
    if (_error != null && _items.isEmpty) {
      return ProfileTabScroll(storageKey: storageKey, slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ProfileMessage(
            icon: Icons.cloud_off_outlined,
            title: s.Ms_Comments_Error,
            actionLabel: s.Ms_Retry,
            onAction: _load,
          ),
        ),
      ]);
    }
    final header = _header(context);
    return ProfileTabScroll(
      storageKey: storageKey,
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        if (_items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ProfileMessage(icon: Icons.chat_bubble_outline, title: s.Ms_Comments_Empty),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                s.Ms_Comments_Count(_total ?? _items.length),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
          SliverList.builder(
            itemCount: _items.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _items.length) return _MoreRow(failed: _moreFailed, onLoad: _loadMore);
              final c = _items[i];
              final connected = _session.isConnected;
              return ProfileCommentTile(
                key: ValueKey(c.id),
                comment: c,
                onConversation: c.conversationUrl == null ? null : () => _openConversation(c),
                onReply: connected && c.replyToMemberId != null ? () => _reply(c) : null,
                onDelete: connected && c.canDelete ? () => _delete(c) : null,
              );
            },
          ),
        ],
      ],
    );
  }
}

/// The last row of a list with more pages: loads the next page when it is built, or offers
/// Retry after a failure.
class _MoreRow extends StatefulWidget {
  const _MoreRow({required this.failed, required this.onLoad});

  final bool failed;
  final VoidCallback onLoad;

  @override
  State<_MoreRow> createState() => _MoreRowState();
}

class _MoreRowState extends State<_MoreRow> {
  @override
  void initState() {
    super.initState();
    if (!widget.failed) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onLoad());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: widget.failed
            ? TextButton.icon(
                onPressed: widget.onLoad,
                icon: const Icon(Icons.refresh),
                label: Text(S.of(context).Ms_Retry),
              )
            : const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
      ),
    );
  }
}
