import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/MAL/mal_user_page.dart';
import 'package:mywatchlist/screens/forum/forum_topics_screen.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_forum_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_user.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_topics_data.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/home/contentlistwidget.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/forum/forum_topic_widget.dart';
import 'package:mywatchlist/widgets/loading/loadingcard.dart';

/// Answers of the home sections kept in memory, so coming back to the home (or a rebuild)
/// shows them at once. Cleared by a pull to refresh.
class HomeSectionCache {
  HomeSectionCache._();

  static final Map<String, ({DateTime at, Object data})> _entries = {};

  /// The kept answer for [key] when it is younger than [maxAge].
  static T? fresh<T>(String key, Duration maxAge) {
    final entry = _entries[key];
    if (entry == null || DateTime.now().difference(entry.at) > maxAge) return null;
    final data = entry.data;
    return data is T ? data as T : null;
  }

  static void put(String key, Object data) =>
      _entries[key] = (at: DateTime.now(), data: data);

  static void clear() => _entries.clear();
}

/// Loads [load] once (or reads the in-memory answer), shows [loading] meanwhile, an error state
/// with a "Try again" button when it fails and [builder] with the data otherwise. A new
/// [refresh] value reloads from the network and keeps the old data on screen until the new
/// answer comes.
class HomeAsync<T extends Object> extends StatefulWidget {
  final String cacheKey;
  final Duration maxAge;
  final int refresh;
  final Future<T> Function() load;
  final Widget loading;
  final Widget Function(BuildContext context, T data) builder;

  const HomeAsync({
    super.key,
    required this.cacheKey,
    required this.maxAge,
    required this.load,
    required this.loading,
    required this.builder,
    this.refresh = 0,
  });

  @override
  State<HomeAsync<T>> createState() => _HomeAsyncState<T>();
}

class _HomeAsyncState<T extends Object> extends State<HomeAsync<T>> {
  T? _data;
  bool _failed = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _start(force: false);
  }

  @override
  void didUpdateWidget(covariant HomeAsync<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey) {
      _data = null;
      _start(force: false);
    } else if (oldWidget.refresh != widget.refresh) {
      _start(force: true);
    }
  }

  Future<void> _start({required bool force}) async {
    final cached = force ? null : HomeSectionCache.fresh<T>(widget.cacheKey, widget.maxAge);
    if (cached != null) {
      _data = cached;
      _failed = false;
      return;
    }
    final token = ++_token;
    if (_failed) setState(() => _failed = false);
    try {
      final data = await widget.load();
      HomeSectionCache.put(widget.cacheKey, data);
      if (!mounted || token != _token) return;
      setState(() {
        _data = data;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() => _failed = _data == null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data != null) return widget.builder(context, data);
    if (_failed) {
      return HomeMessage(
        icon: Icons.cloud_off_outlined,
        text: S.current.Hw_Section_Failed,
        actionLabel: S.current.Hw_Retry,
        onAction: () => _start(force: true),
      );
    }
    return widget.loading;
  }
}

/// A compact state card of a home section (empty, signed out, failed) with an optional action.
class HomeMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const HomeMessage({
    super.key,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// The user's own MyAnimeList list (one category, optionally one status) as a row of cards, most
/// recently updated first. Signed out, it explains what is missing and opens the accounts.
class HomeUserListSection extends StatelessWidget {
  final HomeSectionPreference section;
  final double cardWidth;
  final double cardHeight;
  final int refresh;

  const HomeUserListSection({
    super.key,
    required this.section,
    required this.cardWidth,
    required this.cardHeight,
    this.refresh = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: section.getDisplayTitle(),
            onTap: () => AppRoutes.push<void>(
              context,
              Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: const MalUserPage(),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: UserManager.instance,
            builder: (context, _) {
              if (!UserManager.instance.isAuthenticated(AccountType.myanimelist)) {
                return HomeMessage(
                  icon: Icons.person_outline_rounded,
                  text: S.current.Hw_Sign_In_List,
                  actionLabel: S.current.Acc_Connect_Tracker,
                  onAction: () => AppRoutes.openManageAccounts(context),
                );
              }
              return _loaded(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _loaded(BuildContext context) {
    final category = section.userCategory;
    final status = section.userStatus;
    return HomeAsync<List<Anime>>(
      cacheKey: 'userlist:$category:${status ?? 'all'}:${section.itemCount}',
      maxAge: Duration(hours: section.cacheDurationHours),
      refresh: refresh,
      load: () => MalUser.getMyContentList(
        category: category,
        status: status,
        limit: section.itemCount,
        sortType: 'list_updated_at',
      ),
      loading: loadingCardList(
        containerHeight: cardHeight,
        height: cardHeight,
        width: cardWidth,
        itemCount: section.itemCount,
        listPadding: const EdgeInsets.all(8),
      ),
      builder: (context, items) {
        if (items.isEmpty) {
          return HomeMessage(icon: Icons.inbox_outlined, text: S.current.Hw_Empty_List);
        }
        return ContentListWidget(
          category: category,
          items: items,
          height: cardHeight,
          padding: const EdgeInsets.all(8),
          tileWidth: cardWidth,
          tileHeight: cardHeight,
        );
      },
    );
  }
}

/// The latest topics of the MyAnimeList forum (one board or sub-board, or the whole forum).
class HomeForumSection extends StatelessWidget {
  final HomeSectionPreference section;
  final int refresh;

  /// Topics shown at most; the header opens the full board.
  static const int maxTopics = 6;

  const HomeForumSection({super.key, required this.section, this.refresh = 0});

  Future<List<ForumTopicsData>> _load() async {
    final result = await MalForumApi().getForumTopics(
      boardId: section.boardId,
      subboardId: section.subboardId,
      limit: maxTopics + 2,
      fromHtml: true,
    );
    // null = the request failed: the section shows its error state with "Try again".
    if (result == null) throw StateError('forum topics unavailable');
    return result.data ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    final title = section.getDisplayTitle();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: title,
            onTap: () => AppRoutes.push<void>(
              context,
              ForumTopicsScreen(
                boardId: section.boardId,
                subBoardId: section.subboardId,
                title: title,
              ),
            ),
          ),
          HomeAsync<List<ForumTopicsData>>(
            cacheKey: 'forum:${section.boardId}:${section.subboardId}',
            maxAge: Duration(hours: section.cacheDurationHours),
            refresh: refresh,
            load: _load,
            loading: const ForumSkeleton(count: 3),
            builder: (context, topics) {
              final shown = topics.take(maxTopics).toList();
              if (shown.isEmpty) {
                return HomeMessage(
                    icon: Icons.forum_outlined, text: S.current.Fc_Topics_Empty_Title);
              }
              return Column(
                children: [for (final topic in shown) ForumTopicWidget(topic: topic)],
              );
            },
          ),
        ],
      ),
    );
  }
}
