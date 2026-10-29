import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_settings_page.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart'
    show UserProfileUnavailable;
import 'package:mywatchlist/services/api/Anilist/anilist_follow_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_profile_service.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_favourites.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_find_user.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_header.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_overview.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_social.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_stats.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_activity_feed.dart';
import 'package:mywatchlist/widgets/common/app_bar_menu.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';
import 'package:mywatchlist/widgets/user/profile/profile_format.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// An AniList profile, as AniList's own apps draw it: the user's banner, avatar, name and
/// badges over five lazily built tabs, Overview, Activity, Favourites, Stats and Social.
/// [username] null = the signed-in user. Without a [Scaffold] of its own, so it sits in the
/// home shell as well as in a pushed page.
class AnilistProfileView extends StatefulWidget {
  final String? username;
  final bool showBack;
  final AnilistProfileService? service;
  final AnilistFollowService? follow;

  const AnilistProfileView({
    super.key,
    this.username,
    this.showBack = false,
    this.service,
    this.follow,
  });

  @override
  State<AnilistProfileView> createState() => _AnilistProfileViewState();
}

class _AnilistProfileViewState extends State<AnilistProfileView> {
  AnilistProfile? _profile;
  Object? _error;
  int _generation = 0;

  AnilistProfileService get _service => widget.service ?? AnilistProfileService.instance;

  @override
  void initState() {
    super.initState();
    // The profile of the last visit shows at once while the fresh one loads.
    _profile = _service.kept(widget.username);
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final generation = ++_generation;
    try {
      final profile = await _service.load(
        username: widget.username,
        force: force,
        maxAge: const Duration(minutes: 5),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _profile = profile;
        _error = null;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      // A refresh that fails keeps the profile already on screen.
      if (_profile == null) setState(() => _error = e);
    }
  }

  void _retry() {
    setState(() => _error = null);
    _load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      final s = S.of(context);
      final error = _error;
      return Column(
        children: [
          AppBar(
            automaticallyImplyLeading: widget.showBack,
            title: Text(widget.username ?? s.Prof_Title_Own),
          ),
          Expanded(
            child: error == null
                ? ProfileLoading(label: s.Prof_Loading)
                : error is AnilistSessionExpired
                    ? ProfileMessage(
                        icon: Icons.lock_outline,
                        title: s.Al_Session_Expired,
                        body: s.Al_Profile_Session_Expired_Body,
                        actionLabel: s.Al_Sign_In_Again,
                        onAction: () async {
                          await AppRoutes.signInAgain(context, AccountType.anilist);
                          if (mounted) _retry();
                        },
                      )
                    : ProfileMessage(
                        icon: error is UserProfileUnavailable
                            ? Icons.person_off_outlined
                            : Icons.cloud_off_outlined,
                        title: s.Prof_Error_Title,
                        body: error is UserProfileUnavailable
                            ? s.Prof_Not_Found_Body
                            : s.Prof_Error_Body,
                        actionLabel: s.Prof_Retry,
                        onAction: _retry,
                      ),
          ),
        ],
      );
    }
    final own = UserAnilistV2.instance.username;
    return _Body(
      key: ValueKey(profile.data.username.toLowerCase()),
      profile: profile,
      isSelf: widget.username == null ||
          (own != null && own.toLowerCase() == profile.data.username.toLowerCase()),
      showBack: widget.showBack,
      service: widget.service,
      follow: widget.follow,
    );
  }
}

class _Body extends StatefulWidget {
  final AnilistProfile profile;
  final bool isSelf;
  final bool showBack;
  final AnilistProfileService? service;
  final AnilistFollowService? follow;

  const _Body({
    super.key,
    required this.profile,
    required this.isSelf,
    required this.showBack,
    this.service,
    this.follow,
  });

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with SingleTickerProviderStateMixin {
  static const double _tabBarHeight = 48;
  static const int _socialTab = 4;
  late final TabController _tabs = TabController(length: 5, vsync: this);
  AnilistSocialList _socialList = AnilistSocialList.followers;
  int _socialNonce = 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openSocial(AnilistSocialList list) {
    setState(() {
      _socialList = list;
      _socialNonce++;
    });
    _tabs.animateTo(_socialTab);
  }

  void _share() {
    final p = widget.profile;
    final s = S.current;
    String line(String label, int entries, double? mean) =>
        '$label: ${s.Prof_Entry_Count(entries)}${(mean ?? 0) > 0 ? ' · ${profileMean(mean)}' : ''}';
    final summary = [
      if (p.data.anime.totalEntries > 0)
        line(s.Prof_Anime, p.data.anime.totalEntries, p.data.anime.meanScore),
      if (p.data.manga.totalEntries > 0)
        line(s.Prof_Manga, p.data.manga.totalEntries, p.data.manga.meanScore),
    ].join('\n');
    showShareBuilder(
      context,
      subject: p.data.username,
      fields: [
        ShareField(label: s.Prof_Share_Name, value: p.data.username, labelled: false),
        ShareField(label: s.Prof_Share_Link, value: p.url, labelled: false),
        if (summary.isNotEmpty)
          ShareField(label: s.Prof_Share_Stats, value: summary, labelled: false),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    final profile = widget.profile;
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverOverlapAbsorber(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          sliver: SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: widget.showBack,
            forceElevated: innerBoxIsScrolled,
            expandedHeight: kToolbarHeight + AnilistProfileBanner.bandHeight + _tabBarHeight,
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            title: _CollapsedTitle(profile.data.username),
            actions: [
              AppBarMenu(
                onShare: _share,
                onOpenInBrowser: () => openLink(context, profile.url),
                items: [
                  AppBarMenuItem(
                    label: s.Alpp_Find_User,
                    icon: Icons.person_search_outlined,
                    onTap: () => AppRoutes.push<void>(
                        context, AnilistFindUserPage(service: widget.follow)),
                  ),
                  if (widget.isSelf)
                    AppBarMenuItem(
                      label: s.Als_Title,
                      icon: Icons.settings_outlined,
                      onTap: () => AppRoutes.push<void>(context, const AnilistSettingsPage()),
                    ),
                ],
              ),
            ],
            flexibleSpace:
                AnilistProfileBanner(profile: profile, bottomInset: _tabBarHeight),
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: s.Alpp_Tab_Overview),
                Tab(text: s.Alpp_Tab_Activity),
                Tab(text: s.Prof_Tab_Favorites),
                Tab(text: s.Prof_Tab_Stats),
                Tab(text: s.Alpp_Tab_Social),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabs,
        children: [
          AnilistOverviewTab(
            profile: profile,
            isSelf: widget.isSelf,
            onOpenSocial: _openSocial,
            follow: widget.follow,
            service: widget.service,
          ),
          _ActivityTab(profile: profile, isSelf: widget.isSelf),
          AnilistFavouritesTab(profile: profile, isSelf: widget.isSelf, service: widget.service),
          AnilistStatsTab(profile: profile, service: widget.service),
          AnilistSocialTab(
            key: ValueKey((_socialList, _socialNonce)),
            userId: profile.data.id,
            username: profile.data.username,
            isSelf: widget.isSelf,
            initial: _socialList,
            service: widget.follow,
          ),
        ],
      ),
    );
  }
}

/// The user's activity (statuses, list updates, messages) with likes and replies, from the
/// shared feed. The feed scrolls by itself, so it starts under the pinned bar by a spacer as
/// tall as the overlap the bar absorbs.
class _ActivityTab extends StatefulWidget {
  final AnilistProfile profile;
  final bool isSelf;

  const _ActivityTab({required this.profile, required this.isSelf});

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.profile.data.id <= 0) {
      return const SizedBox.shrink();
    }
    final handle = NestedScrollView.sliverOverlapAbsorberHandleFor(context);
    return Column(
      children: [
        ListenableBuilder(
          listenable: handle,
          builder: (context, _) => SizedBox(height: handle.layoutExtent ?? 0),
        ),
        Expanded(
          child: AnilistActivityFeed(
            userId: widget.profile.data.id,
            showComposer: widget.isSelf,
          ),
        ),
      ],
    );
  }
}

/// The user name in the toolbar, shown once the header has scrolled away (a text colour
/// alpha, not an opacity layer).
class _CollapsedTitle extends StatelessWidget {
  final String username;

  const _CollapsedTitle(this.username);

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final style = DefaultTextStyle.of(context).style;
    var visible = 1.0;
    if (settings != null && settings.maxExtent > settings.minExtent) {
      final expanded = ((settings.currentExtent - settings.minExtent) /
              (settings.maxExtent - settings.minExtent))
          .clamp(0.0, 1.0);
      visible = ((1 - expanded) * 3 - 2).clamp(0.0, 1.0);
    }
    final color = style.color ?? Theme.of(context).colorScheme.onSurface;
    return Text(
      username,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(color: color.withValues(alpha: color.a * visible)),
    );
  }
}
