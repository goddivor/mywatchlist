import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_clubs_api.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_data.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

class ClubCommentsScreen extends StatefulWidget {
  final int clubId;
  final String? clubTitle;
  final Map<String, String> staffPositionMap;

  const ClubCommentsScreen({
    super.key,
    required this.clubId,
    this.clubTitle,
    this.staffPositionMap = const {},
  });

  @override
  State<ClubCommentsScreen> createState() => _ClubCommentsScreenState();
}

class _ClubCommentsScreenState extends State<ClubCommentsScreen> {
  final _clubsApi = MalClubsApi();
  final _scrollController = ScrollController();
  final List<ClubComment> _comments = [];
  final _regex = RegExp(r'font-size\s*:\s*[^;]+;');
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadComments();
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
      _loadComments();
    }
  }

  Future<void> _loadComments() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final result = await _clubsApi.getClubViewAll(
        widget.clubId,
        'comments',
        _currentOffset,
      );

      if (mounted) {
        final newComments = (result ?? []).whereType<ClubComment>().toList();
        setState(() {
          _comments.addAll(newComments);
          _currentOffset += newComments.length;
          _hasMore = newComments.length >= _pageSize;
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
          'Comments${widget.clubTitle != null ? ' - ${widget.clubTitle}' : ''}',
        ),
      ),
      body: _comments.isEmpty && _isLoading
          ? _buildLoading()
          : RefreshIndicator(
              onRefresh: () async {
                _comments.clear();
                _currentOffset = 0;
                _hasMore = true;
                await _loadComments();
              },
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _comments.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _comments.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _buildCommentTile(_comments[index]);
                },
              ),
            ),
    );
  }

  Widget _buildCommentTile(ClubComment comment) {
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
              Expanded(
                child: Text(
                  '$username · ${comment.longAgo ?? ''}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              if (widget.staffPositionMap.containsKey(username))
                SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: Text(widget.staffPositionMap[username]!),
                  ),
                ),
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
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
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
  }

  Widget _buildLoading() {
    return ShimmerColor(
      ListView.builder(
        itemCount: 6,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            height: 80,
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
