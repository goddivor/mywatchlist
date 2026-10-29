import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_group_page.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart' show ProfileTabScroll;
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuGroup;
import 'package:mywatchlist/services/api/Kitsu/kitsu_profile.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// The "Groups" tab: the groups the user belongs to; a tap opens the group's feed. A failed load
/// reads as no groups (no tracker error reporting).
class KitsuGroupsTab extends StatefulWidget {
  final String userId;
  final KitsuProfiles? profiles;

  const KitsuGroupsTab({super.key, required this.userId, this.profiles});

  @override
  State<KitsuGroupsTab> createState() => _KitsuGroupsTabState();
}

class _KitsuGroupsTabState extends State<KitsuGroupsTab> with AutomaticKeepAliveClientMixin {
  late final Future<List<KitsuGroup>> _groups = _load();

  @override
  bool get wantKeepAlive => true;

  Future<List<KitsuGroup>> _load() async {
    try {
      return await (widget.profiles ?? KitsuProfiles.instance).groups(widget.userId);
    } catch (_) {
      return const <KitsuGroup>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ProfileTabScroll(
      storageKey: 'kitsu_groups_${widget.userId}',
      slivers: [
        FutureBuilder<List<KitsuGroup>>(
          future: _groups,
          builder: (context, snapshot) {
            final groups = snapshot.data;
            if (groups == null) {
              return const SliverToBoxAdapter(
                child: Padding(
                    padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
              );
            }
            if (groups.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(S.of(context).Kf_Groups_Empty,
                      textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                ),
              );
            }
            return SliverList.builder(
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final g = groups[i];
                return ListTile(
                  leading: AppImage(
                    url: g.avatarUrl,
                    width: 44,
                    height: 44,
                    borderRadius: BorderRadius.circular(8),
                    placeholderColor: scheme.surfaceContainerHighest,
                    errorWidget: (_) => Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.groups_outlined, color: scheme.onSecondaryContainer),
                    ),
                  ),
                  title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      S.of(context).Kc_Member_Count(g.membersCount),
                      if (g.tagline != null && g.tagline!.trim().isNotEmpty) g.tagline!.trim(),
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => gotoPage(context: context, newPage: KitsuGroupScreen(group: g)),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
