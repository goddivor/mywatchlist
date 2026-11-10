import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, getTileSizeValues;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_feeds_service.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_chips.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_home_sections.dart';
import 'package:mywatchlist/widgets/Anilist/notifications/anilist_notification_bell.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart' show HomeSectionCache;

/// The AniList home tab: the app bar (with the AniList bell and its unread badge) and the
/// shortcut chips, then the sections the user picked in the home settings (shared with
/// MyAnimeList's home): seasonal, ranking rows, "Suggested" as the recommendations of the
/// user's list, the user's own list and the AniList forum; then what the people the user
/// follows did and today's birthdays. Every AniList row of the page comes in one request
/// ([AnilistFeedsService.home]); News and features are MyAnimeList's and are skipped.
class AnilistHomePage extends StatefulWidget {
  const AnilistHomePage({super.key, this.service});

  /// Replaced in tests.
  final AnilistFeedsService? service;

  @override
  State<AnilistHomePage> createState() => _AnilistHomePageState();
}

class _AnilistHomePageState extends State<AnilistHomePage> {
  /// Bumped by a pull to refresh: every section reloads from the network when it changes.
  int _refresh = 0;

  AnilistFeedsService get _service => widget.service ?? AnilistFeedsService.instance;

  String? _planKey;
  Future<AnilistFeed>? _feed;

  /// The request of [plan], started once per plan (a settings change or a sign in makes a
  /// new one).
  Future<AnilistFeed> _feedOf(AnilistHomePlan plan, {bool force = false}) {
    if (!force && _planKey == plan.key && _feed != null) return _feed!;
    _planKey = plan.key;
    return _feed = plan.load(_service, force: force);
  }

  void _retry(AnilistHomePlan plan) => setState(() => _feedOf(plan, force: true));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HomePreferencesBloc>().add(LoadHomePreferencesEvent());
    });
  }

  Future<void> _onRefresh() async {
    HomeSectionCache.clear();
    _service.clear();
    _planKey = null;
    context.read<HomePreferencesBloc>().add(LoadHomePreferencesEvent());
    setState(() => _refresh++);
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    // Section titles and chips read S.current: rebuild when the app language changes.
    Localizations.localeOf(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        edgeOffset: kToolbarHeight + 60,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              // Empty list does not suppress the automatic endDrawer button; a placeholder does.
              actions: const [SizedBox.shrink()],
              pinned: true,
              floating: true,
              titleSpacing: 0,
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: kToolbarHeight,
              title: AppBarHome(
                backgroundColor: Colors.transparent,
                showAvatar: true,
                showSettings: true,
                titleWidget: const _HomeTitle(),
                onSearchTap: () => openAnilistSearch(context),
              ),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(52),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 10, top: 7),
                  child: AnilistChipsBar(),
                ),
              ),
            ),
            BlocBuilder<HomePreferencesBloc, HomePreferencesState>(
              buildWhen: (a, b) => a.isLoading != b.isLoading || a.preferences != b.preferences,
              builder: (context, state) {
                if (state.isLoading) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final tile = getTileSizeValues(state.preferences.tileSize);
                return ListenableBuilder(
                  listenable: UserManager.instance,
                  builder: (context, _) {
                    final signedIn = UserManager.instance.isAuthenticated(AccountType.anilist);
                    final plan = AnilistHomePlan.of(state.preferences.sections, signedIn: signedIn);
                    final sections = plan.sections;
                    return FutureBuilder<AnilistFeed>(
                      future: _feedOf(plan),
                      builder: (context, feed) {
                        if (sections.isEmpty) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: Text(S.current.Hw_Empty_Items)),
                          );
                        }
                        return SliverList.builder(
                          itemCount: sections.length + 1,
                          itemBuilder: (context, i) {
                            if (i == sections.length) {
                              return RepaintBoundary(
                                child: AnilistHomeExtras(feed: feed, signedIn: signedIn),
                              );
                            }
                            return RepaintBoundary(
                              child: AnilistHomeSection(
                                key: ValueKey('${sections[i].type.name}$i'),
                                section: sections[i],
                                row: plan.rowOf[i],
                                feed: feed,
                                onRetry: () => _retry(plan),
                                cardWidth: tile.containerHeight * (2 / 3),
                                cardHeight: tile.containerHeight,
                                refresh: _refresh,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

/// The start of the home app bar: the app logo, and the AniList bell (unread badge) at the
/// end next to the other actions while an AniList account is signed in.
class _HomeTitle extends StatelessWidget {
  const _HomeTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundImage: const AssetImage('assets/images/mwl-black-bg.png'),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        const Spacer(),
        ListenableBuilder(
          listenable: UserManager.instance,
          builder: (context, bell) =>
              UserManager.instance.isAuthenticated(AccountType.anilist) ? bell! : const SizedBox.shrink(),
          child: IconButtonTheme(
            // The size of the other app bar buttons.
            data: IconButtonThemeData(
              style: IconButton.styleFrom(
                iconSize: 20,
                foregroundColor: theme.colorScheme.onSurface,
                fixedSize: const Size(44, 40),
                minimumSize: const Size(44, 40),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            child: const AnilistNotificationBell(),
          ),
        ),
      ],
    );
  }
}
