import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';

class ForumPostHeader extends StatelessWidget {
  final ForumTopicsData? forumTopic;
  final TextStyle? titleStyle;
  final SizedBox? sizedbox;

  const ForumPostHeader({
    super.key,
    this.forumTopic,
    this.titleStyle,
    this.sizedbox,
  });

  static final DateFormat _dateFormat = DateFormat('EEE, MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    String? formattedDate;
    if (forumTopic?.lastPostCreatedAt != null) {
      formattedDate = _dateFormat.format(forumTopic!.lastPostCreatedAt!);
    }
    final lastPostTime = formattedDate != null ? ' · $formattedDate' : '';

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
        sizedbox ?? const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: AutoSizeText(
                '${forumTopic?.createdBy?.name ?? ""}$lastPostTime',
                style: textTheme.bodySmall,
                textAlign: TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AutoSizeText(
              '${forumTopic?.numberOfPosts?.toString() ?? "0"} Posts',
              style: textTheme.bodySmall,
              textAlign: TextAlign.end,
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
