import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/forum/bbcode_widget.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

/// Builds a SliverList of forum posts with scroll-to-index support.
class PostWidgetBuilder extends StatefulWidget {
  final List<ForumTopicPost>? postList;
  final AutoScrollController controller;
  final bool reverse;
  final int offset;
  final int postLimit;
  final bool showOnlyPosts;
  final bool clearSelection;
  final Function(Set<ForumTopicPost>) onPostsSelected;

  const PostWidgetBuilder({
    super.key,
    required this.postList,
    required this.controller,
    this.reverse = false,
    required this.onPostsSelected,
    required this.offset,
    this.showOnlyPosts = false,
    this.clearSelection = false,
    required this.postLimit,
  });

  @override
  State<PostWidgetBuilder> createState() => _PostWidgetBuilderState();
}

class _PostWidgetBuilderState extends State<PostWidgetBuilder> {
  List<ForumTopicPost> _postList = [];
  Set<ForumTopicPost> selectedPosts = {};

  @override
  void initState() {
    super.initState();
    _postList = widget.postList ?? [];
    if (widget.reverse) _postList = _postList.reversed.toList();
  }

  @override
  void didUpdateWidget(covariant PostWidgetBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clearSelection && !oldWidget.clearSelection) {
      selectedPosts.clear();
    }
  }

  ForumTopicPost? _getForumPostFromPostId(int? postId) {
    if (widget.postList == null || widget.postList!.isEmpty || postId == null) {
      return null;
    }
    for (var post in widget.postList!) {
      if (post.id == postId) return post;
    }
    return null;
  }

  int? _getScrollIndexFromId(int? postId) {
    if (widget.postList == null || widget.postList!.isEmpty || postId == null) {
      return null;
    }
    for (var i = 0; i < widget.postList!.length; i++) {
      if (widget.postList![i].id == postId) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, index) => wrapScrollTag(
          index: index,
          controller: widget.controller,
          highlightColor: Theme.of(context).highlightColor,
          child: PostWidget(
            post: _postList[index],
            isShareStarted: selectedPosts.isNotEmpty,
            index: widget.reverse
                ? (widget.offset + (widget.postLimit - 1) - index)
                : (widget.offset + index),
            isSelected: selectedPosts.contains(_postList[index]),
            onQuoteTapped: (id) async {
              int? scrollIndex = _getScrollIndexFromId(id);
              if (scrollIndex != null) {
                await widget.controller.scrollToIndex(
                  scrollIndex,
                  preferPosition: AutoScrollPosition.middle,
                  duration: const Duration(milliseconds: 400),
                );
                widget.controller.highlight(scrollIndex);
                return null;
              } else {
                return id;
              }
            },
            onSelected: (post) {
              if (!widget.showOnlyPosts) {
                selectedPosts.add(post);
                widget.onPostsSelected(selectedPosts);
                setState(() {});
              }
            },
            onUnSelected: (post) {
              selectedPosts.remove(post);
              widget.onPostsSelected(selectedPosts);
              setState(() {});
            },
            getForumPostFromPostId: (id, callback) {
              callback(_getForumPostFromPostId(id));
            },
          ),
        ),
        childCount: _postList.length,
      ),
    );
  }
}

/// Renders a single forum post (matching DailyAL's PostWidget).
class PostWidget extends StatefulWidget {
  final ForumTopicPost post;
  final int index;
  final Future<int?> Function(int) onQuoteTapped;
  final void Function(int?, Function(ForumTopicPost?)) getForumPostFromPostId;
  final Function(ForumTopicPost) onSelected;
  final Function(ForumTopicPost) onUnSelected;
  final bool isSelected;
  final bool isShareStarted;

  const PostWidget({
    super.key,
    required this.post,
    required this.index,
    required this.onQuoteTapped,
    required this.getForumPostFromPostId,
    required this.onSelected,
    required this.onUnSelected,
    this.isSelected = false,
    this.isShareStarted = false,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget>
    with AutomaticKeepAliveClientMixin {
  late String body;
  String? signature;
  List<String> quoteBodyList = [];
  List<ForumTopicPost> quotedPostList = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    body = widget.post.body ?? '';
    signature = widget.post.signature;
    _parseContent();
  }

  void _parseContent() {
    // Convert BBCode brackets
    if (signature != null) {
      signature = signature!
          .replaceAll("[", "<")
          .replaceAll("]", ">")
          .replaceAll("[\'", "<\'");
    }

    body = body
        .replaceAll("[", "<")
        .replaceAll("]", ">")
        .replaceAll("[\'", "<\'");

    // Extract quotes
    try {
      if (body.contains("<quote")) {
        var quote = body.substring(0, body.lastIndexOf("</quote>") + 8);
        int index = 0;
        var quoteIndexList = <int>[];
        while (index < (quote.length - 7)) {
          var oq = quote.substring(index, index + 6);
          var cq = quote.substring(index, index + 8);
          if (oq == "<quote") {
            quoteIndexList.add(index);
          }
          if (cq == "</quote>") {
            int startIndex = quoteIndexList.removeLast();
            var quoteBody = quote.substring(startIndex, index);
            int quoteIndex = quoteBody.lastIndexOf("</quote>");
            if (quoteIndex == -1) {
              quoteIndex = quoteBody.lastIndexOf("message=") + 17;
            } else {
              quoteIndex += 8;
            }

            var qid = int.tryParse(quoteBody.substring(
                quoteBody.indexOf("message=") + 8,
                quoteBody.indexOf("message=") + 16));
            ForumTopicPost? quotePost;
            widget.getForumPostFromPostId(qid, (post) {
              quotePost = post;
            });
            String? forumUsername;
            if (quoteBody.indexOf("<quote=") != -1 &&
                quoteBody.indexOf("message=") != -1) {
              forumUsername = quoteBody.substring(
                  quoteBody.indexOf("<quote=") + 7,
                  quoteBody.indexOf("message="));
            }
            if (quotePost == null && qid != null && forumUsername != null) {
              quotePost = ForumTopicPost(
                  id: qid, createdBy: ForumUser(name: forumUsername));
            }
            if (forumUsername != null) {
              quotedPostList.add(quotePost!);
              quoteBodyList.add(
                  quoteBody.substring(quoteIndex).replaceAll("<br />", ""));
              var qq = quote.substring(startIndex, index);
              if (quoteIndexList.isEmpty) {
                body = body.replaceAll(qq, "");
              }
            }
          }
          index++;
        }
      }
    } catch (e) {
      debugPrint('Quote parsing error: $e');
    }

    body = "<div> $body </div>";
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      type: widget.isSelected ? MaterialType.canvas : MaterialType.transparency,
      color: widget.isSelected ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      child: InkWell(
        onTap: widget.isSelected
            ? () => widget.onUnSelected(widget.post)
            : widget.isShareStarted
                ? () => widget.onSelected(widget.post)
                : null,
        onLongPress:
            widget.isSelected ? null : () => widget.onSelected(widget.post),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _forumUserLeading()),
                  _buildPopupMenu(),
                ],
              ),
              // Quotes
              Padding(
                padding: const EdgeInsets.only(left: 48, right: 8),
                child: _buildQuoteWidgets(),
              ),
              // Post body
              Padding(
                padding: const EdgeInsets.only(left: 48, right: 8, top: 4),
                child: BbcodeWidget(body: body),
              ),
              const SizedBox(height: 6),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _forumUserLeading({bool disableTap = false}) {
    final theme = Theme.of(context);
    final name = widget.post.createdBy?.name;
    return Row(
      children: [
        ForumAvatar(
          username: name,
          url: widget.post.createdBy?.id == null
              ? null
              : getUserImage(widget.post.createdBy!.id!),
          selected: widget.isSelected,
          tappable: !disableTap && !widget.isShareStarted && !widget.isSelected,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: GestureDetector(
            onTap: disableTap || widget.isShareStarted || widget.isSelected
                ? null
                : () => openForumUser(context, name),
            child: Text(
              name ?? S.current.Fc_User_Default,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (!disableTap && widget.post.createdAt != null)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              displayTimeAgo(widget.post.createdAt!),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  PopupMenuButton<_PostMenuItem> _buildPopupMenu() {
    final popupItems = <_PostMenuItem>[
      if (signature != null && signature!.isNotEmpty)
        _PostMenuItem(_PostMenuItemType.signature, S.current.Fc_Menu_Signature,
            Icons.design_services),
      _PostMenuItem(_PostMenuItemType.reportPost, S.current.Fc_Menu_Report_Post,
          Icons.flag_outlined),
      _PostMenuItem(_PostMenuItemType.reportUser, S.current.Fc_Menu_Report_User,
          Icons.person_off_outlined),
    ];
    return PopupMenuButton<_PostMenuItem>(
      tooltip: S.current.Fc_Post_Options,
      icon: const Icon(Icons.more_horiz, size: 20),
      onSelected: (value) {
        switch (value.itemType) {
          case _PostMenuItemType.signature:
            _showBbCodePopup(signature);
            break;
          case _PostMenuItemType.reportPost:
            _reportWithConfirmation(
              title: S.current.Fc_Menu_Report_Post,
              type: 'forummessage',
              content: _forumUserLeading(disableTap: true),
              queryParams: {
                'id': '${widget.index + 1}',
                'id2': '${widget.post.id}',
              },
            );
            break;
          case _PostMenuItemType.reportUser:
            _reportWithConfirmation(
              title: S.current.Fc_Menu_Report_User,
              type: 'profile',
              content: _forumUserLeading(disableTap: true),
              queryParams: {
                'id': '${widget.post.createdBy?.id}',
              },
            );
            break;
        }
      },
      itemBuilder: (context) => [
        ...popupItems.map(
          (i) => PopupMenuItem(
            value: i,
            child: iconAndText(i.icon, i.title),
          ),
        ),
      ],
    );
  }

  void _reportWithConfirmation({
    required String title,
    required String type,
    required Widget content,
    required Map<String, String> queryParams,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content,
            const SizedBox(height: 16),
            Text(S.current.Fc_Report_Body),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.current.Fc_Cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              launchWebView(ForumUrls.report(type, queryParams), context: context);
            },
            child: Text(S.current.Fc_Report),
          ),
        ],
      ),
    );
  }

  void _showBbCodePopup(String? content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ConstrainedBox(
        constraints:
            const BoxConstraints(minHeight: 150, minWidth: double.infinity),
        child: Material(
          child: SingleChildScrollView(
            child: BbcodeWidget(
              body: "<div> $content </div>",
              shrinkWrap: false,
              alignCenter: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuoteWidgets() {
    if (quoteBodyList.isEmpty) return const SizedBox.shrink();
    if (Preferences.general.showOnlyLastQuote) {
      return _quoteWidget(quoteBodyList.last.trim(), quotedPostList.last);
    }
    return Column(
      children: [
        for (var i = 0; i < quotedPostList.length; i++)
          _quoteWidget(quoteBodyList[i].trim(), quotedPostList[i]),
      ],
    );
  }

  Widget _quoteWidget(String quoteBody, ForumTopicPost quotedPost) {
    final constrainedHeight = quoteBody.length > 300 ? 120.0 : 80.0;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: constrainedHeight),
      padding: const EdgeInsets.fromLTRB(20, 0, 0, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: constrainedHeight,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              ForumAvatar(
                size: 30,
                username: quotedPost.createdBy?.name,
                url: quotedPost.createdBy?.id == null
                    ? null
                    : getUserImage(quotedPost.createdBy!.id!),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: 40,
                child: Text(
                  quotedPost.createdBy?.name ?? S.current.Fc_User_Default,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                      ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () async {
                final result = await widget.onQuoteTapped(quotedPost.id!);
                if (result != null) {
                  _showBbCodePopup(quoteBody);
                }
              },
              onLongPress: () {
                showToast(S.current.Fc_Post_By(
                    quotedPost.createdBy?.name ?? S.current.Fc_User_Default));
              },
              borderRadius: BorderRadius.circular(16),
              child: ClipRect(
                child: BbcodeWidget(
                  body: quoteBody,
                  minimize: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PostMenuItemType { signature, reportPost, reportUser }

class _PostMenuItem {
  final _PostMenuItemType itemType;
  final String title;
  final IconData icon;

  _PostMenuItem(this.itemType, this.title, this.icon);
}
