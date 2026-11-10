import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_social.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_paged_tab.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_profile_rows.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart' show ListEntryStatus;

/// The "List" tab of another user's profile: their public anime or manga list by status.
class KitsuListTab extends StatefulWidget {
  final String slug;
  final KitsuSocial? social;

  const KitsuListTab({super.key, required this.slug, this.social});

  @override
  State<KitsuListTab> createState() => _KitsuListTabState();
}

class _KitsuListTabState extends State<KitsuListTab> with AutomaticKeepAliveClientMixin {
  KitsuMediaKind _kind = KitsuMediaKind.anime;

  /// `null` is every status.
  ListEntryStatus? _status;

  @override
  bool get wantKeepAlive => true;

  static String _graphqlStatus(ListEntryStatus status) => switch (status) {
        ListEntryStatus.current => 'CURRENT',
        ListEntryStatus.completed => 'COMPLETED',
        ListEntryStatus.onHold => 'ON_HOLD',
        ListEntryStatus.dropped => 'DROPPED',
        ListEntryStatus.planned => 'PLANNED',
      };

  static ListEntryStatus? _statusOf(String value) => switch (value) {
        'CURRENT' => ListEntryStatus.current,
        'COMPLETED' => ListEntryStatus.completed,
        'ON_HOLD' => ListEntryStatus.onHold,
        'DROPPED' => ListEntryStatus.dropped,
        'PLANNED' => ListEntryStatus.planned,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final api = widget.social ?? KitsuSocial.instance;
    final isAnime = _kind == KitsuMediaKind.anime;
    final status = _status;
    return KitsuPagedList<KitsuLibraryItem>(
      // A new filter is a new list.
      key: ValueKey('${_kind.name}:${status?.name}'),
      storageKey: 'kitsu_list_${widget.slug}_${_kind.name}_${status?.name}',
      createPager: () => KitsuPager(
        (page) => api.library(widget.slug,
            kind: _kind, status: status == null ? null : _graphqlStatus(status), page: page),
      ),
      emptyText: s.Kitsu_List_Empty,
      header: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<KitsuMediaKind>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: KitsuMediaKind.anime, label: Text(s.Prof_Anime)),
                    ButtonSegment(value: KitsuMediaKind.manga, label: Text(s.Prof_Manga)),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (v) => setState(() => _kind = v.first),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(s.Kitsu_List_All),
                        selected: status == null,
                        onSelected: (_) => setState(() => _status = null),
                      ),
                      for (final value in ListEntryStatus.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: ChoiceChip(
                            label: Text(kitsuStatusLabel(value, isAnime: isAnime)),
                            selected: status == value,
                            onSelected: (_) => setState(() => _status = value),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      itemBuilder: (context, item) {
        final itemStatus = _statusOf(item.status);
        final total = item.progress;
        final detail = [
          if (itemStatus != null) kitsuStatusLabel(itemStatus, isAnime: isAnime),
          if (total > 0)
            isAnime
                ? s.Kitsu_Activity_Progress_Anime(total)
                : s.Kitsu_Activity_Progress_Manga(total),
        ].join(' · ');
        final rating = item.rating;
        return KitsuMediaLine(
          key: ValueKey(item.id),
          media: item.media,
          detail: detail,
          trailing: rating == null
              ? null
              : Text(
                  rating % 2 == 0 ? '${rating ~/ 2}' : (rating / 2).toStringAsFixed(1),
                  style: Theme.of(context).textTheme.titleMedium),
        );
      },
    );
  }
}
