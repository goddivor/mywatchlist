import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_forum_api.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/app_bar_menu.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/forum/forum_paged_list.dart';
import 'package:mywatchlist/widgets/forum/forum_topic_widget.dart';

/// The topics of a board, a sub-board or a series, page after page, with a search.
class ForumTopicsScreen extends StatefulWidget {
  final int? boardId;
  final int? subBoardId;
  final int? animeId;
  final int? mangaId;
  final String? title;
  final String? query;
  final int offset;

  const ForumTopicsScreen({
    super.key,
    this.boardId,
    this.subBoardId,
    this.animeId,
    this.mangaId,
    this.title,
    this.query,
    this.offset = 0,
  });

  @override
  State<ForumTopicsScreen> createState() => _ForumTopicsScreenState();
}

class _ForumTopicsScreenState extends State<ForumTopicsScreen> {
  static const _pageSize = 40;

  final _forumApi = MalForumApi();
  String? _searchQuery;

  String get _url => ForumUrls.board(
        boardId: widget.boardId,
        subBoardId: widget.subBoardId,
        animeId: widget.animeId,
        mangaId: widget.mangaId,
      );

  Future<List<ForumTopicsData>> _fetch(int offset) async {
    final result = await _forumApi.getForumTopics(
      boardId: widget.boardId,
      subboardId: widget.subBoardId,
      animeId: widget.animeId,
      mangaId: widget.mangaId,
      q: _searchQuery ?? widget.query,
      offset: offset,
      limit: _pageSize,
      fromHtml: true,
    );
    // null = the request failed: the list shows its error state with Retry.
    if (result == null) throw StateError('forum topics unavailable');
    return result.data ?? const [];
  }

  Future<void> _search() async {
    final query = await showSearch<String?>(
      context: context,
      delegate: _ForumSearchDelegate(),
    );
    if (query != null && query.trim().isNotEmpty && mounted) {
      setState(() => _searchQuery = query.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? S.current.Fc_Tab_Forums;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _searchQuery != null ? S.current.Fc_Search_Result_Title(_searchQuery!) : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_searchQuery != null)
            IconButton(
              tooltip: S.current.Fc_Clear_Search,
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _searchQuery = null),
            ),
          IconButton(
            tooltip: S.current.Fc_Search_Topics,
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
          AppBarMenu(
            onShare: () => showShareBuilder(
              context,
              subject: title,
              fields: [
                ShareField(label: S.current.Fc_Field_Title, value: title),
                ShareField(label: S.current.Fc_Field_Link, value: _url),
              ],
            ),
            onOpenInBrowser: () => launchWebView(_url, context: context),
          ),
        ],
      ),
      body: ForumPagedList<ForumTopicsData>(
        key: ValueKey(_searchQuery),
        fetch: _fetch,
        pageSize: _pageSize,
        startOffset: _searchQuery == null ? widget.offset : 0,
        emptyTitle: S.current.Fc_Topics_Empty_Title,
        emptyBody: S.current.Fc_Topics_Empty_Body,
        emptyIcon: Icons.forum_outlined,
        itemBuilder: (context, topic) => ForumTopicWidget(topic: topic),
      ),
    );
  }
}

class _ForumSearchDelegate extends SearchDelegate<String?> {
  _ForumSearchDelegate() : super(searchFieldLabel: S.current.Fc_Search_Topics);

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: S.current.Fc_Clear_Search,
            icon: const Icon(Icons.close),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) {
    // The results are the topic list itself: hand the query back and close.
    WidgetsBinding.instance.addPostFrameCallback((_) => close(context, query));
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return ForumMessage(
        icon: Icons.search,
        title: S.current.Fc_Search_Hint_Empty,
        scrollable: false,
      );
    }
    return ListTile(
      leading: const Icon(Icons.search),
      title: Text(S.current.Fc_Search_For(query.trim())),
      onTap: () => close(context, query),
    );
  }
}
