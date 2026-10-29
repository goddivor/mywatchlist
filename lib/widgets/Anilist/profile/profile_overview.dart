import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_other_list_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_settings_page.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_follow_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_profile_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_actions.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_colors.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_find_user.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_heatmap.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_html.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_reviews_feed.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/user/profile/profile_format.dart';

/// Overview tab: the actions (follow, message, lists, reviews), followers and following, the
/// three headline numbers, the top genres, the activity heatmap, the about text.
class AnilistOverviewTab extends StatefulWidget {
  final AnilistProfile profile;
  final bool isSelf;

  /// Opens the Social tab on [list].
  final ValueChanged<AnilistSocialList> onOpenSocial;
  final AnilistFollowService? follow;
  final AnilistProfileService? service;

  /// Replaces the heatmap request (tests).
  final Future<List<AnilistActivityDay>> Function(int userId)? heatmap;

  const AnilistOverviewTab({
    super.key,
    required this.profile,
    required this.isSelf,
    required this.onOpenSocial,
    this.follow,
    this.service,
    this.heatmap,
  });

  @override
  State<AnilistOverviewTab> createState() => _AnilistOverviewTabState();
}

class _AnilistOverviewTabState extends State<AnilistOverviewTab>
    with AutomaticKeepAliveClientMixin {
  ({int? followers, int? following})? _counts;
  List<AnilistActivityDay>? _days;
  late bool _following = widget.profile.isFollowing;

  @override
  bool get wantKeepAlive => true;

  AnilistFollowService get _follow => widget.follow ?? AnilistFollowService.instance;
  AnilistProfileService get _service => widget.service ?? AnilistProfileService.instance;

  @override
  void initState() {
    super.initState();
    final id = widget.profile.data.id;
    if (id <= 0) return;
    // Both are decoration: a failure leaves them out, nothing to retry.
    _follow.counts(id).then((c) {
      if (mounted) setState(() => _counts = c);
    }).catchError((Object _) {});
    (widget.heatmap ?? _service.loadActivityHistory)(id).then((d) {
      if (mounted) setState(() => _days = d);
    }).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profile = widget.profile;
    final accent = anilistReadableAccent(
        anilistProfileColor(profile.profileColor) ?? cs.primary, cs);
    final anime = profile.anime.list;
    final manga = profile.manga.list;
    final tiles = <(String, String, Color?)>[
      (s.Alpp_Days_Watched, anime.days == null ? s.Pp_No_Value : profileNumber(anime.days!, digits: 1), null),
      (s.Alpp_Chapters_Read, profileNumber(manga.progress), null),
      (
        s.Prof_Mean_Score,
        profileMean(anime.meanScore ?? manga.meanScore),
        (anime.meanScore ?? manga.meanScore ?? 0) > 0 ? AppColors.of(context).score.color : null
      ),
    ];
    final genres = profile.anime.genres.take(5).toList();
    final names = profile.previousNames;
    return ProfileTabScroll(
      storageKey: 'al_overview_${profile.data.username}',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!widget.isSelf && profile.data.id > 0) ...[
                  AnilistFollowButton(
                    userId: profile.data.id,
                    isFollowing: _following,
                    service: widget.follow,
                    onChanged: (state) => setState(() => _following = state.isFollowing),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showAnilistMessage(context,
                        recipientId: profile.data.id,
                        name: profile.data.username,
                        service: widget.follow),
                    icon: const Icon(Icons.mail_outline),
                    label: Text(s.Alpp_Message),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => AppRoutes.push<void>(
                        context, AnilistOtherListPage(username: profile.data.username)),
                    icon: const Icon(Icons.format_list_bulleted),
                    label: Text(s.Alpp_Lists),
                  ),
                ] else if (widget.isSelf) ...[
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        AppRoutes.push<void>(context, const AnilistSettingsPage()),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(s.Prof_Edit_Profile),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => AppRoutes.push<void>(context, const AnilistFindUserPage()),
                    icon: const Icon(Icons.person_search_outlined),
                    label: Text(s.Alpp_Find_User),
                  ),
                ],
                if (profile.data.id > 0)
                  OutlinedButton.icon(
                    onPressed: () => openAnilistReviews(context,
                        userId: profile.data.id, title: profile.data.username),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text(s.Reviews),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                _Counter(
                  value: _counts?.followers,
                  label: s.Alpp_Followers,
                  onTap: () => widget.onOpenSocial(AnilistSocialList.followers),
                ),
                _Counter(
                  value: _counts?.following,
                  label: s.Alpp_Following,
                  onTap: () => widget.onOpenSocial(AnilistSocialList.following),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Row(
                children: [
                  for (final (label, value, color) in tiles)
                    Expanded(
                      child: Column(
                        children: [
                          Text(value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700, color: color ?? cs.onSurface)),
                          const SizedBox(height: 2),
                          Text(label,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (genres.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final g in genres)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${g.label} · ${profileNumber(g.count)}'),
                    ),
                ],
              ),
            ),
          ),
        if (_days != null && _days!.isNotEmpty)
          SliverToBoxAdapter(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.Alpp_Activity_History, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    AnilistHeatmap(days: _days!, color: accent),
                  ],
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: profile.about == null
                ? Text(widget.isSelf ? s.Prof_About_Empty_Self : s.Prof_About_Empty,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
                : AnilistHtml(profile.about!),
          ),
        ),
        if (names.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(s.Alpp_Previous_Names(names.join(', ')),
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
          ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  final int? value;
  final String label;
  final VoidCallback onTap;

  const _Counter({required this.value, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Text(value == null ? '-' : profileNumber(value!),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
