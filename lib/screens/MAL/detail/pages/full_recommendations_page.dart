import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_screen.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';

/// Full recommendation page with selector tabs and user comments.
///
/// Matches DailyAL's `ContentFullRecommendation`.
class ContentFullRecommendation extends StatefulWidget {
  final int id;
  final String category;
  const ContentFullRecommendation({
    super.key,
    required this.id,
    required this.category,
  });

  @override
  State<ContentFullRecommendation> createState() =>
      _ContentFullRecommendationState();
}

class _ContentFullRecommendationState extends State<ContentFullRecommendation>
    with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _future;
  TabController? _controller;

  @override
  void initState() {
    super.initState();
    _future = MwlApi.i.getRecommendationData(
      id: widget.id,
      category: widget.category,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              loadingCenter(),
              SB.h20,
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: title(S.current.Recommendation_Loading),
              ),
            ],
          );
        }
        final data = snapshot.data;
        if (data == null || data.isEmpty) return showNoContent();
        return _buildContent(data);
      },
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> data) {
    _controller ??= TabController(length: data.length, vsync: this);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: _RecommSelectorNodes(
              data: data,
              category: widget.category,
              controller: _controller!,
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _controller,
        physics: const BouncingScrollPhysics(),
        children: data.map((e) => _RecomTabView(recomBase: e)).toList(),
      ),
    );
  }
}

/// A single tab view showing recommendation comments for one anime.
/// Uses AutomaticKeepAliveClientMixin to preserve scroll state.
class _RecomTabView extends StatefulWidget {
  final Map<String, dynamic> recomBase;
  const _RecomTabView({required this.recomBase});

  @override
  State<_RecomTabView> createState() => _RecomTabViewState();
}

class _RecomTabViewState extends State<_RecomTabView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final recommendations =
        (widget.recomBase['recommendations'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: title(
                '${recommendations.length} ${S.current.Recommendations}',
              ),
            ),
          ),
        ),
        if (recommendations.isEmpty)
          SliverToBoxAdapter(child: showNoContent())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((_, index) {
                final item = recommendations[index];
                final username = item['username'] as String?;
                final commentText = item['text'] as String? ?? '';
                return RepaintBoundary(
                  child: Card(
                    child: Column(
                      children: [
                        SB.h10,
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                height: 40,
                                width: 40,
                                child: userImage(
                                  BorderRadius.circular(20),
                                  null,
                                  username: username,
                                ),
                              ),
                              SB.w20,
                              Expanded(child: title(username)),
                            ],
                          ),
                        ),
                        SB.h10,
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: title(commentText),
                        ),
                        SB.h10,
                      ],
                    ),
                  ),
                );
              }, childCount: recommendations.length),
            ),
          ),
        const SliverToBoxAdapter(child: SB.h80),
      ],
    );
  }
}

/// Horizontal tab selector showing recommended anime/manga covers.
///
/// Matches DailyAL's `SelectorNodesWidget`.
class _RecommSelectorNodes extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final String category;
  final TabController controller;

  const _RecommSelectorNodes({
    required this.data,
    required this.category,
    required this.controller,
  });

  @override
  State<_RecommSelectorNodes> createState() => _RecommSelectorNodesState();
}

class _RecommSelectorNodesState extends State<_RecommSelectorNodes> {
  static const double tabWidth = 240.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(covariant _RecommSelectorNodes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTabChanged);
      widget.controller.addListener(_onTabChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double sidePadding = (screenWidth - tabWidth) / 2;

    return SizedBox(
      height: 80,
      child: TabBar(
        isScrollable: true,
        controller: widget.controller,
        indicatorColor: Colors.transparent,
        dividerColor: Colors.transparent,
        physics: const BouncingScrollPhysics(),
        labelPadding: EdgeInsets.zero,
        tabAlignment: TabAlignment.start,
        tabs: List.generate(
          widget.data.length,
          (i) => Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? sidePadding : 8,
              right: i == widget.data.length - 1 ? sidePadding : 8,
            ),
            child: _buildSelectorNode(widget.data[i], i),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorNode(Map<String, dynamic> recomBase, int index) {
    final node = recomBase['relatedNode'] as Map<String, dynamic>? ?? {};
    final mainPic = node['mainPicture'] as Map<String, dynamic>? ?? {};
    final imageUrl =
        mainPic['large'] as String? ?? mainPic['medium'] as String? ?? '';
    final nodeTitle = node['title'] as String? ?? '';
    final nodeId = node['id'] as int?;
    final isSelected = widget.controller.index == index;

    return SizedBox(
      width: tabWidth,
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: () {
            if (mounted) {
              setState(() {
                widget.controller.index = index;
              });
            }
          },
          child: Card(
            elevation: isSelected ? 4 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isSelected
                  ? BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  RepaintBoundary(
                    child: AvatarWidget(
                      url: imageUrl,
                      height: 50,
                      width: 50,
                      onTap: nodeId != null
                          ? () => gotoPage(
                                context: context,
                                newPage: ContentDetailedScreen(
                                  category: widget.category,
                                  id: nodeId,
                                  node: null,
                                ),
                              )
                          : null,
                    ),
                  ),
                  SB.w10,
                  Expanded(
                    child: title(
                      nodeTitle,
                      textOverflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
