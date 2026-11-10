import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_group_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_post_page.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_feed.dart';
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_feed_list.dart';
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_groups_list.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';

/// The Forum tab for Kitsu: the latest posts of the site, the Kitsu news (group 596) and the
/// groups directory. Posts open a thread, groups open their own feed.
class KitsuForumPage extends StatefulWidget {
  /// Source of the data; defaults to the shared Kitsu client.
  final KitsuFeed? feed;

  /// Hides the app bar (the page is then hosted by a screen that has its own).
  final bool showAppBar;
  const KitsuForumPage({super.key, this.feed, this.showAppBar = true});

  static const String siteUrl = KitsuFeed.siteUrl;

  @override
  State<KitsuForumPage> createState() => _KitsuForumPageState();
}

class _KitsuForumPageState extends State<KitsuForumPage> with SingleTickerProviderStateMixin {
  late final KitsuFeed _feed = widget.feed ?? KitsuFeed();
  late final KitsuFeedController _latest = _feed.latest();
  late final KitsuFeedController _news = _feed.news();
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    _latest.dispose();
    _news.dispose();
    super.dispose();
  }

  void _openPost(String id) =>
      gotoPage(context: context, newPage: KitsuPostPage(postId: id, feed: widget.feed));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          if (widget.showAppBar)
            AppBarHome(title: s.Hw_Tab_Forum, showBookmarks: false, showCalendar: false),
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: s.Kc_Tab_Latest),
              Tab(text: s.Kc_Tab_News),
              Tab(text: s.Kc_Tab_Groups),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                KitsuFeedList(controller: _latest, onOpenPost: (p) => _openPost(p.id)),
                KitsuFeedList(controller: _news, onOpenPost: (p) => _openPost(p.id)),
                KitsuGroupsList(
                  feed: _feed,
                  onOpenGroup: (g) => gotoPage(
                      context: context, newPage: KitsuGroupScreen(group: g, feed: widget.feed)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
