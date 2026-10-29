import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show displayTimeAgo;
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_open.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart' show ListEntryStatus;
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Opens a Kitsu title from the profile on its native Kitsu page (`openKitsuTitle`): the
/// profile never goes through the MyAnimeList pages, each tracker is its own app. Tests replace
/// [opener].
class KitsuTitleLinks {
  const KitsuTitleLinks._();

  static void Function(BuildContext context, KitsuMediaKind kind, String id, String? slug) opener =
      _openNative;

  static void _openNative(BuildContext context, KitsuMediaKind kind, String id, String? slug) {
    openKitsuTitle(context, kind: kind, id: id, slug: slug);
  }

  static void open(BuildContext context, KitsuMediaRef ref) =>
      opener(context, ref.kind, ref.id, ref.slug);
}

/// A list status in Kitsu's own words ("Want to watch", "Currently reading").
String kitsuStatusLabel(ListEntryStatus status, {required bool isAnime}) {
  final s = S.current;
  return switch (status) {
    ListEntryStatus.current => isAnime ? s.Kitsu_Status_Current_Anime : s.Kitsu_Status_Current_Manga,
    ListEntryStatus.planned => isAnime ? s.Kitsu_Status_Planned_Anime : s.Kitsu_Status_Planned_Manga,
    ListEntryStatus.completed => s.Kitsu_Status_Completed,
    ListEntryStatus.onHold => s.Kitsu_Status_On_Hold,
    ListEntryStatus.dropped => s.Kitsu_Status_Dropped,
  };
}

/// "3 days ago" for [date], empty when unknown.
String kitsuTimeAgo(DateTime? date) => date == null ? '' : displayTimeAgo(date.toLocal());

/// A poster on the left, a title and up to two lines of text on the right: the row of the
/// activity, reactions and list tabs.
class KitsuMediaLine extends StatelessWidget {
  final KitsuMediaRef media;
  final String? headline;
  final String? detail;
  final Widget? trailing;
  final VoidCallback? onTap;

  const KitsuMediaLine({
    super.key,
    required this.media,
    this.headline,
    this.detail,
    this.trailing,
    this.onTap,
  });

  static const double _width = 52;
  static const double _height = 74;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap ?? () => KitsuTitleLinks.open(context, media),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            AppImage(
              url: media.poster?.url,
              width: _width,
              height: _height,
              borderRadius: BorderRadius.circular(6),
              placeholderColor: scheme.surfaceContainerHighest,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(media.titles.display,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall),
                  if (headline != null)
                    Text(headline!, style: theme.textTheme.bodyMedium),
                  if (detail != null)
                    Text(detail!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
