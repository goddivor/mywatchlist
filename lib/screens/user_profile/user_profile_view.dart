import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mwl_commons/mwl_commons.dart' show UserAboutHtml;
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/about_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/clubs_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/favorites_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/friends_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/history_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/stats_section.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/app_bar_menu.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';
import 'package:mywatchlist/widgets/user/profile/profile_format.dart';
import 'package:mywatchlist/widgets/user/profile/profile_header.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';
import 'package:mywatchlist/widgets/user/profile/report_user.dart';

/// The tabs of a profile, in display order.
enum UserProfileTab { stats, friends, clubs, about, favorites, history }

/// A MyAnimeList profile: pinned header (background, avatar, name) over six lazily built
/// tabs. [username] null = the signed-in user. Without a [Scaffold] of its own so it can sit
/// in the home shell as well as in [UserProfileScreen].
class UserProfileView extends StatefulWidget {
  final String? username;
  final bool showBack;
  final UserProfileTab initialTab;

  const UserProfileView({
    super.key,
    this.username,
    this.showBack = false,
    this.initialTab = UserProfileTab.stats,
  });

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  StreamSubscription<UserProfileData>? _sub;
  UserProfileData? _data;
  Object? _error;

  bool get _isSelf => widget.username == null;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Shows each value as it comes: the official MAL data first, Jikan merged afterwards.
  void _listen({bool force = false}) {
    _sub?.cancel();
    _sub = UserProfileRepository.instance.watch(widget.username, forceRefresh: force).listen(
      (data) {
        if (mounted)
          setState(() {
            _data = data;
            _error = null;
          });
      },
      onError: (Object e) {
        // A refresh that fails keeps the profile already on screen.
        if (mounted && _data == null) setState(() => _error = e);
      },
    );
  }

  void _reload({bool force = false}) {
    setState(() => _error = null);
    _listen(force: force);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final error = _error;
    if (data == null) {
      final s = S.of(context);
      return _Frame(
        title: widget.username ?? s.Prof_Title_Own,
        showBack: widget.showBack,
        child: error == null
            ? ProfileLoading(label: s.Prof_Loading)
            : ProfileErrorView(
                error: error,
                onRetry: () => _reload(force: true),
                onSignIn: () async {
                  await AppRoutes.signInAgain(context, AccountType.myanimelist);
                  if (mounted) _reload(force: true);
                },
              ),
      );
    }
    return _ProfileBody(
      key: ValueKey(data.username.toLowerCase()),
      data: data,
      isSelf: _isSelf,
      showBack: widget.showBack,
      initialTab: widget.initialTab,
      onRetryExtras: () => _reload(force: true),
    );
  }
}

/// Title bar over a centered state (loading or error).
class _Frame extends StatelessWidget {
  final String title;
  final bool showBack;
  final Widget child;

  const _Frame({required this.title, required this.showBack, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          automaticallyImplyLeading: showBack,
          title: Text(title),
          // No automatic ☰ for the home shell's end drawer (an empty list keeps it).
          actions: const [SizedBox.shrink()],
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ProfileBody extends StatefulWidget {
  final UserProfileData data;
  final bool isSelf;
  final bool showBack;
  final UserProfileTab initialTab;

  const _ProfileBody({
    super.key,
    required this.data,
    required this.isSelf,
    required this.showBack,
    required this.initialTab,
    required this.onRetryExtras,
  });

  /// Asks again for the Jikan part (manga numbers, favorites) when it failed.
  final VoidCallback onRetryExtras;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> with SingleTickerProviderStateMixin {
  static const double _tabBarHeight = 48;

  late final TabController _tabs = TabController(
    length: UserProfileTab.values.length,
    initialIndex: widget.initialTab.index,
    vsync: this,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _tabLabel(UserProfileTab tab, S s) => switch (tab) {
        UserProfileTab.stats => s.Prof_Tab_Stats,
        UserProfileTab.friends => s.Prof_Tab_Friends,
        UserProfileTab.clubs => s.Prof_Tab_Clubs,
        UserProfileTab.about => s.Prof_Tab_About,
        UserProfileTab.favorites => s.Prof_Tab_Favorites,
        UserProfileTab.history => s.Prof_Tab_History,
      };

  Widget _tabBody(UserProfileTab tab) {
    final data = widget.data;
    return switch (tab) {
      UserProfileTab.stats =>
        StatsSection(data: data, isSelf: widget.isSelf, onRetryExtras: widget.onRetryExtras),
      UserProfileTab.friends => FriendsSection(username: data.username),
      UserProfileTab.clubs => ClubsSection(username: data.username),
      UserProfileTab.about => AboutSection(
          username: data.username,
          isSelf: widget.isSelf,
          fromPage: data.about == null
              ? null
              : UserAboutHtml(about: data.about, modern: data.aboutModern),
        ),
      UserProfileTab.favorites => FavoritesSection(
          favorites: data.favorites,
          username: data.username,
          extras: data.extras,
          onRetry: widget.onRetryExtras,
        ),
      UserProfileTab.history => HistorySection(username: data.username),
    };
  }

  void _share() {
    final data = widget.data;
    final s = S.current;
    final anime = data.anime;
    final manga = data.manga;
    final summary = [
      if (anime.totalEntries > 0)
        '${s.Prof_Anime}: ${s.Prof_Entry_Count(anime.totalEntries)}'
            '${(anime.meanScore ?? 0) > 0 ? ' · ${profileMean(anime.meanScore)}' : ''}',
      if (manga.totalEntries > 0)
        '${s.Prof_Manga}: ${s.Prof_Entry_Count(manga.totalEntries)}'
            '${(manga.meanScore ?? 0) > 0 ? ' · ${profileMean(manga.meanScore)}' : ''}',
    ].join('\n');
    showShareBuilder(
      context,
      subject: data.username,
      fields: [
        ShareField(label: s.Prof_Share_Name, value: data.username, labelled: false),
        ShareField(label: s.Prof_Share_Link, value: data.profileUrl, labelled: false),
        if (summary.isNotEmpty)
          ShareField(label: s.Prof_Share_Stats, value: summary, labelled: false),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    final data = widget.data;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverOverlapAbsorber(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          sliver: SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: widget.showBack,
            forceElevated: innerBoxIsScrolled,
            expandedHeight: kToolbarHeight + ProfileHeader.bandHeight + _tabBarHeight,
            // Opaque and themed: the title, icons, tabs and status bar (the app bar theme's
            // overlay style) always sit on the surface they were made for.
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            title: _CollapsedTitle(data.username),
            actions: [
              AppBarMenu(
                onShare: _share,
                onOpenInBrowser: () => openLink(context, data.profileUrl),
                items: [
                  if (widget.isSelf)
                    AppBarMenuItem(
                      label: s.Prof_Edit_Profile,
                      icon: Icons.edit_outlined,
                      onTap: () => openLink(context, 'https://myanimelist.net/editprofile.php'),
                    )
                  else if (data.id != 0)
                    AppBarMenuItem(
                      label: s.Prof_Report_Action,
                      icon: Icons.flag_outlined,
                      onTap: () => reportUser(
                        context,
                        userId: data.id,
                        username: data.username,
                        pictureUrl: data.pictureUrl,
                      ),
                    ),
                ],
              ),
            ],
            flexibleSpace: ProfileHeader(
              data: data,
              isSelf: widget.isSelf,
              bottomInset: _tabBarHeight,
            ),
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (final tab in UserProfileTab.values) Tab(text: _tabLabel(tab, s)),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final tab in UserProfileTab.values) _tabBody(tab),
        ],
      ),
    );
  }
}

/// The user name in the toolbar, shown once the header (which carries the name in large) has
/// scrolled away. Reads the app bar's extent itself, so only this text repaints while
/// scrolling; the fade is a text colour alpha, not an opacity layer.
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
      // Fully shown in the last third of the collapse.
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
