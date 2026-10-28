import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/web/profile_comments_api.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/widgets/user/profile/profile_comments.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// A comment-to-comment conversation (`comtocom.php`), with a reply field when the website
/// session is connected and the viewer is one of the two members.
class CommentConversationScreen extends StatefulWidget {
  const CommentConversationScreen({super.key, required this.url, this.api, this.session});

  final String url;
  final ProfileCommentsApi? api;
  final MalWebSession? session;

  @override
  State<CommentConversationScreen> createState() => _CommentConversationScreenState();
}

class _CommentConversationScreenState extends State<CommentConversationScreen> {
  late final ProfileCommentsApi _api = widget.api ?? ProfileCommentsApi();
  MalWebSession get _session => widget.session ?? MalWebSession.instance;
  late Future<CommentConversation> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.conversation(widget.url);
  }

  void _reload() => setState(() => _future = _api.conversation(widget.url));

  Future<bool> _reply(int memberId, String text) async {
    try {
      await _api.reply(memberId: memberId, text: text, referer: widget.url);
    } catch (e) {
      if (mounted) showCommentSnack(context, commentErrorText(e));
      return false;
    }
    if (mounted) {
      showCommentSnack(context, S.current.Ms_Comment_Posted);
      _reload();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.Ms_Comment_Conversation)),
      body: FutureBuilder<CommentConversation>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ProfileLoading();
          }
          if (snapshot.hasError) {
            return ProfileMessage(
              icon: Icons.cloud_off_outlined,
              title: s.Ms_Comments_Error,
              actionLabel: s.Ms_Retry,
              onAction: _reload,
            );
          }
          final conversation = snapshot.data!;
          final me = _session.username ?? UserMalV2.instance.username;
          final target = _session.isConnected ? conversation.otherMemberId(me) : null;
          return Column(
            children: [
              Expanded(
                child: conversation.comments.isEmpty
                    ? ProfileMessage(icon: Icons.forum_outlined, title: s.Ms_Comments_Empty)
                    : ListView.builder(
                        itemCount: conversation.comments.length,
                        itemBuilder: (context, i) => ProfileCommentTile(
                          key: ValueKey(conversation.comments[i].id),
                          comment: conversation.comments[i],
                        ),
                      ),
              ),
              if (target != null)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: ProfileCommentComposer(onSend: (text) => _reply(target, text)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
