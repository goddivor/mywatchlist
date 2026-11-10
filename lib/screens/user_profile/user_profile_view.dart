import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mwl_commons/mwl_commons.dart' show UserAboutHtml;
import 'package:mywatchlist/cache/bookmarks.dart' show BookmarkKind;
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/mal_web/compose_message_screen.dart' show openComposeMalMessage;
import 'package:mywatchlist/screens/user_profile/sections/about_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/clubs_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/comments_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/favorites_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/friends_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/history_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/list_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/reviews_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/stats_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/weekly_section.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_button.dart';
import 'package:mywatchlist/widgets/common/app_bar_menu.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';
import 'package:mywatchlist/widgets/user/profile/profile_format.dart';
import 'package:mywatchlist/widgets/user/profile/profile_header.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';
import 'package:mywatchlist/widgets/user/profile/report_user.dart';

/// The tabs of a profile, in display order. [list] is only on another user's profile (first,
/// like DailyAL), [weekly] only on your own.
enum UserProfileTab {
  list,
  stats,
  friends,
  clubs,
  about,
  favorites,
  history,
  comments,
  reviews,
  recommendations,
  stacks,
  blog,
  weekly,
}

/// The tabs shown on a profile ([isSelf] = the signed-in user's).
List<UserProfileTab> profileTabsFor({required bool isSelf}) => [
      for (final tab in UserProfileTab.values)
        if ((tab != UserProfileTab.list || !isSelf) && (tab != UserProfileTab.weekly || isSelf))
          tab,
    ];

/// The tab a profile opens on: another user's opens on their list unless a tab other than
/// the default Stats is asked (DailyAL always opens a user on the list).
UserProfileTab openingProfileTab(UserProfileTab asked, {required bool isSelf}) {
  final tabs = profileTabsFor(isSelf: isSelf);
  if (!isSelf && asked == UserProfileTab.stats) return UserProfileTab.list;
  return tabs.contains(asked) ? asked : tabs.first;
}

/// A MyAnimeList profile: pinned header (background, avatar, name) over lazily built tabs
/// behind DailyAL's icon strip. [username] null = the signed-in user. Without a [Scaffold] of
/// its own so it can sit in the home shell as well as in [UserProfileScreen].
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

  late final List<UserProfileTab> _tabList = profileTabsFor(isSelf: widget.isSelf);
  late final TabController _tabs = TabController(
    length: _tabList.length,
    initialIndex: _tabList.indexOf(openingProfileTab(widget.initialTab, isSelf: widget.isSelf)),
    vsync: this,
  );

  /// "Details expanded" off = the header opens collapsed (DailyAL `detailsExpanded`).
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: Preferences.general.detailsExpanded ? 0 : ProfileHeader.bandHeight,
  );

  @override
  void dispose() {
    _tabs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _tabBody(UserProfileTab tab) {
    final data = widget.data;
    return switch (tab) {
      UserProfileTab.list =>
        ListSection(username: data.username, anime: data.anime, manga: data.manga),
      UserProfileTab.stats =>
        StatsSection(data: data, isSelf: widget.isSelf, onRetryExtras: widget.onRetryExtras),
      UserProfileTab.friends => FriendsSection(username: data.username),
      UserProfileTab.clubs => ClubsSection(username: data.username),
      UserProfileTab.about => AboutSection(
          username: data.username,
          isSelf: widget.isSelf,
          timezone: data.timezone,
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
      UserProfileTab.comments => CommentsSection(username: data.username),
      UserProfileTab.reviews => ReviewsSection(username: data.username),
      UserProfileTab.recommendations => RecommendationsSection(username: data.username),
      UserProfileTab.stacks => StacksSection(username: data.username),
      UserProfileTab.blog => BlogSection(username: data.username),
      UserProfileTab.weekly => const WeeklySection(),
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
      controller: _scroll,
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
              if (!widget.isSelf)
                BookmarkButton(
                  tracker: AccountType.myanimelist.name,
                  kind: BookmarkKind.user,
                  id: data.username,
                  title: data.username,
                  imageUrl: data.pictureUrl,
                ),
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
                  else ...[
                    AppBarMenuItem(
                      label: s.Pm_Message,
                      icon: Icons.mail_outline_rounded,
                      onTap: () => openComposeMalMessage(context, to: data.username),
                    ),
                    if (data.id != 0)
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
                ],
              ),
            ],
            flexibleSpace: ProfileHeader(
              data: data,
              isSelf: widget.isSelf,
              bottomInset: _tabBarHeight,
            ),
            bottom: ProfileTabStrip(controller: _tabs, tabs: _tabList),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final tab in _tabList) _tabBody(tab),
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

/// Label and icon of a profile tab (DailyAL's icons where it has the tab).
(String, IconData) profileTabLook(UserProfileTab tab, S s) => switch (tab) {
      UserProfileTab.list => (s.Pl_Tab_List, Icons.view_list_rounded),
      UserProfileTab.stats => (s.Prof_Tab_Stats, Icons.stacked_bar_chart_rounded),
      UserProfileTab.friends => (s.Prof_Tab_Friends, Icons.people_alt_rounded),
      UserProfileTab.clubs => (s.Prof_Tab_Clubs, Icons.castle_rounded),
      UserProfileTab.about => (s.Prof_Tab_About, Icons.info_rounded),
      UserProfileTab.favorites => (s.Prof_Tab_Favorites, Icons.favorite_rounded),
      UserProfileTab.history => (s.Prof_Tab_History, Icons.history_rounded),
      UserProfileTab.comments => (s.Ms_Comments_Tab, Icons.forum_rounded),
      UserProfileTab.reviews => (s.Reviews, Icons.rate_review_rounded),
      UserProfileTab.recommendations => (s.Recommendations, Icons.thumbs_up_down_rounded),
      UserProfileTab.stacks => (s.Interest_Stacks, Icons.collections_bookmark_rounded),
      UserProfileTab.blog => (s.Mpe_Tab_Blog, Icons.article_rounded),
      UserProfileTab.weekly => (s.Pl_Tab_Weekly, Icons.weekend_rounded),
    };

/// DailyAL's profile tab strip: one icon per tab, the selected one widened into a tonal
/// pill with its label, so every tab fits on a phone. Scrolls when the screen is narrower
/// still, keeping the selected tab in view. Rebuilds alone when the tab changes.
class ProfileTabStrip extends StatefulWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<UserProfileTab> tabs;

  const ProfileTabStrip({super.key, required this.controller, required this.tabs});

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  State<ProfileTabStrip> createState() => _ProfileTabStripState();
}

class _ProfileTabStripState extends State<ProfileTabStrip> {
  late List<GlobalKey> _keys = [for (final _ in widget.tabs) GlobalKey()];
  late int _index = widget.controller.index;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTab);
  }

  @override
  void didUpdateWidget(ProfileTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTab);
      widget.controller.addListener(_onTab);
      _index = widget.controller.index;
    }
    if (oldWidget.tabs.length != widget.tabs.length) {
      _keys = [for (final _ in widget.tabs) GlobalKey()];
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    final index = widget.controller.index;
    if (index == _index) return;
    setState(() => _index = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[index].currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: const Duration(milliseconds: 220),
          curve: const Cubic(0.23, 1, 0.32, 1),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            for (final (i, tab) in widget.tabs.indexed)
              Padding(
                key: _keys[i],
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _StripButton(
                  icon: profileTabLook(tab, s).$2,
                  label: profileTabLook(tab, s).$1,
                  selected: i == _index,
                  colors: cs,
                  labelStyle: labelStyle,
                  onTap: () => widget.controller.animateTo(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StripButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final ColorScheme colors;
  final TextStyle? labelStyle;
  final VoidCallback onTap;

  const _StripButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.colors,
    required this.labelStyle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? colors.onSecondaryContainer : colors.onSurfaceVariant;
    const radius = BorderRadius.all(Radius.circular(18));
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: selected ? colors.secondaryContainer : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: const Cubic(0.23, 1, 0.32, 1),
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: foreground),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Text(label, maxLines: 1, style: labelStyle?.copyWith(color: foreground)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
