import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/widgets/MAL/content/intereststackwidget.dart';

/// Fetches and displays all interest stacks for an anime/manga.
class InterestStacksAllBody extends StatefulWidget {
  final String category;
  final int categoryId;
  final List<InterestStack> initialStacks;

  const InterestStacksAllBody({
    super.key,
    required this.category,
    required this.categoryId,
    required this.initialStacks,
  });

  @override
  State<InterestStacksAllBody> createState() => InterestStacksAllBodyState();
}

class InterestStacksAllBodyState extends State<InterestStacksAllBody> {
  List<InterestStack>? _stacks;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final result = await MwlApi.i.getInterestStacksForContent(
        category: widget.category,
        categoryId: widget.categoryId,
      );
      if (mounted) {
        setState(() {
          _stacks = result.isNotEmpty ? result : widget.initialStacks;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stacks = widget.initialStacks;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return loadingCenter();
    return InterestStackContentList(
      horizPadding: 0,
      interestStacks: _stacks ?? widget.initialStacks,
      type: DisplayType.list_vert,
    );
  }
}
