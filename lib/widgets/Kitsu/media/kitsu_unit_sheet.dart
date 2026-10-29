import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_post_page.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_feed.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_feed_list.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_library_box.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_media_format.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_my_library.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Kitsune's episode sheet: thumbnail, number, title, date and length, description, then
/// "Discussion" (the episode's own feed) and, for a title in the user's library, "Watched up to
/// here" (sets the progress; going back asks first).
Future<void> showKitsuUnitSheet(
  BuildContext context, {
  required KitsuUnit unit,
  required KitsuMediaKind kind,
  required String mediaTitle,
  KitsuMyTitle? my,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => _UnitSheet(unit: unit, kind: kind, mediaTitle: mediaTitle, my: my, pageContext: context),
  );
}

class _UnitSheet extends StatelessWidget {
  final KitsuUnit unit;
  final KitsuMediaKind kind;
  final String mediaTitle;
  final KitsuMyTitle? my;
  final BuildContext pageContext;

  const _UnitSheet({
    required this.unit,
    required this.kind,
    required this.mediaTitle,
    required this.my,
    required this.pageContext,
  });

  Future<void> _markWatched(BuildContext context) async {
    final my = this.my!;
    final s = S.current;
    final back = unit.number < my.progress;
    if (back) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(s.Kr_Progress_Back(unit.number)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s.Kr_Confirm)),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (!await my.setProgress(unit.number)) {
      if (pageContext.mounted) kitsuWriteFailed(pageContext);
      return;
    }
    if (pageContext.mounted) await kitsuAskRatingOnComplete(pageContext, my);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.current;
    final details = [
      if (unit.releasedAt != null) KitsuMediaFormat.date(unit.releasedAt),
      if (unit.length != null && unit.length! > 0) KitsuMediaFormat.minutes(unit.length!),
    ].join(' · ');
    final inLibrary = my?.entry != null;
    final watched = inLibrary && my!.progress >= unit.number;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (unit.thumbnail != null) ...[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: AppImage(
                url: unit.thumbnail!.url,
                borderRadius: BorderRadius.circular(12),
                placeholderColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(KitsuMediaFormat.unitName(kind, unit.number), style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
          if (unit.title != null) Text(unit.title!, style: theme.textTheme.titleLarge),
          if (details.isNotEmpty)
            Text(details, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          if (unit.description != null) ...[
            const SizedBox(height: 10),
            Text(unit.description!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(pageContext).push(MaterialPageRoute<void>(
                      builder: (_) => KitsuUnitDiscussionPage(unit: unit, kind: kind, mediaTitle: mediaTitle),
                    ));
                  },
                  icon: const Icon(Icons.forum_outlined),
                  label: Text(s.Kr_Discussion),
                ),
              ),
              if (inLibrary && !watched) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: my!.busy ? null : () => _markWatched(context),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(kind == KitsuMediaKind.anime ? s.Kr_Watched_Up_To : s.Kr_Read_Up_To),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The posts about one episode or chapter (`feeds/episode_aggr`, `feeds/chapter_aggr`).
class KitsuUnitDiscussionPage extends StatefulWidget {
  final KitsuUnit unit;
  final KitsuMediaKind kind;
  final String mediaTitle;
  final KitsuMyLibrary? service;
  final KitsuFeed? feed;

  const KitsuUnitDiscussionPage({
    super.key,
    required this.unit,
    required this.kind,
    required this.mediaTitle,
    this.service,
    this.feed,
  });

  @override
  State<KitsuUnitDiscussionPage> createState() => _KitsuUnitDiscussionPageState();
}

class _KitsuUnitDiscussionPageState extends State<KitsuUnitDiscussionPage> {
  late final KitsuFeedController _controller =
      (widget.service ?? KitsuMyLibrary.instance).unitFeed(widget.kind, widget.unit.id);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(KitsuMediaFormat.unitName(widget.kind, widget.unit.number)),
            Text(widget.mediaTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      body: KitsuFeedList(
        controller: _controller,
        emptyLabel: S.current.Kr_Unit_Discussion_Empty,
        onOpenPost: (post) => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => KitsuPostPage(postId: post.id, feed: widget.feed),
        )),
      ),
    );
  }
}
