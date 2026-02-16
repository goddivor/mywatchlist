import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

/// Displays a list of forum topics with optional "View All" button.
class ForumTopicsList extends StatelessWidget {
  final List<ForumTopicsData>? topics;
  final bool showViewAllButton;
  final Function? onPressed;
  final bool shrinkWrap;
  final EdgeInsets? padding;
  final VoidCallback? onUiChange;
  final int shimmerItemCount;
  final int? showMax;

  const ForumTopicsList({
    super.key,
    this.topics,
    this.onPressed,
    this.padding,
    this.shrinkWrap = true,
    this.onUiChange,
    this.shimmerItemCount = 6,
    this.showViewAllButton = false,
    this.showMax,
  });

  static const complexForums = [1885985, 1886113, 1983768];

  @override
  Widget build(BuildContext context) {
    if (topics == null) {
      return _buildShimmer();
    }

    if (topics!.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text('No topics found')),
      );
    }

    return ListView(
      shrinkWrap: shrinkWrap,
      padding: EdgeInsets.zero,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      children: [
        _forumList(),
        if (showViewAllButton) SB.h20,
        if (showViewAllButton)
          Container(
            width: double.infinity,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: OutlinedButton(
              onPressed: () {
                if (onPressed != null) onPressed!();
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text('View All'),
            ),
          ),
      ],
    );
  }

  Widget _forumList() {
    var list =
        topics?.where((data) => !complexForums.contains(data.id)) ?? [];
    if (showMax != null && showMax! < list.length) {
      list = list.toList().getRange(0, showMax!);
    }
    return ListView(
      shrinkWrap: true,
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      children: list
          .map((topic) => ForumTopicWidget(
                topic: topic,
                onUiChange: onUiChange,
              ))
          .toList(),
    );
  }

  Widget _buildShimmer() {
    return ShimmerColor(
      Column(
        children: List.generate(
          shimmerItemCount,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single forum topic item (matching DailyAL's ForumTopicWidget).
class ForumTopicWidget extends StatelessWidget {
  final ForumTopicsData topic;
  final VoidCallback? onUiChange;
  final Function(ForumTopicsData)? onTopicSelect;
  final bool isSelected;

  ForumTopicWidget({
    super.key,
    required this.topic,
    this.onUiChange,
    this.onTopicSelect,
    this.isSelected = false,
  });

  final DateFormat dateFormat = DateFormat('EEE, MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: isSelected
          ? Theme.of(context).highlightColor.withValues(alpha: 0.1)
          : null,
      child: InkWell(
        onTap: () {
          if (onTopicSelect != null) {
            onTopicSelect!(topic);
          } else {
            gotoPage(
              context: context,
              newPage: ForumPostsScreen(
                topic: topic,
                onUiChange: onUiChange,
              ),
            );
          }
        },
        onLongPress: () {
          if (topic.lastPostCreatedAt != null) {
            showToast(
                "Last Post by ${topic.lastPostCreatedBy?.name ?? 'User'} - ${dateFormat.format(topic.lastPostCreatedAt!)}");
          } else if (topic.lastPostTimeText != null) {
            showToast(
                "Last Post by ${topic.lastPostCreatedBy?.name ?? 'User'} - ${topic.lastPostTimeText}");
          }
        },
        child: Padding(
          padding: const EdgeInsets.only(top: 7.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12),
                child: ForumPostHeader(
                  forumTopic: topic,
                  dateFormat: dateFormat,
                  titleStyle: textTheme.titleMedium,
                ),
              ),
              const Divider(thickness: 1.0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays forum topic metadata: title, author, date, post count.
/// Matching DailyAL's ForumPostHeader exactly.
class ForumPostHeader extends StatelessWidget {
  const ForumPostHeader({
    super.key,
    required this.dateFormat,
    this.forumTopic,
    this.titleStyle,
    this.sizedbox,
  });

  final ForumTopicsData? forumTopic;
  final DateFormat dateFormat;
  final TextStyle? titleStyle;
  final SizedBox? sizedbox;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    String? formattedDate;
    if (forumTopic?.lastPostCreatedAt != null) {
      formattedDate = dateFormat.format(forumTopic!.lastPostCreatedAt!);
    } else if (forumTopic?.lastPostTimeText != null) {
      formattedDate = forumTopic!.lastPostTimeText!;
    }

    final lastPostTime =
        '${formattedDate != null ? ' · $formattedDate' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 75.0),
          child: AutoSizeText(
            forumTopic?.title ?? '',
            style: titleStyle ?? textTheme.titleLarge,
          ),
        ),
        sizedbox ?? SB.h30,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AutoSizeText(
              '${forumTopic?.createdBy?.name ?? ""}$lastPostTime',
              style: textTheme.bodySmall,
              textAlign: TextAlign.start,
            ),
            AutoSizeText(
              '${forumTopic?.numberOfPosts?.toString() ?? "0"} Posts',
              style: textTheme.bodySmall,
              textAlign: TextAlign.end,
            ),
          ],
        ),
        SB.h10,
      ],
    );
  }
}
