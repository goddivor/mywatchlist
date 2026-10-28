import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:mwl_commons/mwl_commons.dart' show RankedPersonHtml, ReviewHtml;
import 'package:mywatchlist/cache/top_characters.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/explore/explore_data.dart';
import 'package:mywatchlist/screens/explore/explore_images.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/search/search_catalog.dart' show SearchCatalog;
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/screens/seasonal/seasonal_screen.dart';
import 'package:mywatchlist/screens/studios/studios_screen.dart';
import 'package:mywatchlist/screens/weekly/weekly_schedule_screen.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart' show launchWebView;
import 'package:mywatchlist/widgets/MAL/search/headerwidget.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart' show PlainButton, ShadowButton;
import 'package:provider/provider.dart';

/// Size of a category or genre group card in a row (DailyAL's 140 x 105).
const double kExploreCardWidth = 140;
const double kExploreCardHeight = 104;

/// Search query of a ranking (`#all`, `#bypopularity@manga`…), what the search screen understands.
String rankingQuery(Enum ranking, {required bool isAnime}) => isAnime
    ? '#${rankingMap[ranking]}'
    : '#${mangaRankingMap[ranking]}@manga';

/// The bundled DailyAL picture of a ranking card, null when there is none.
String? rankingImage(Enum ranking, {required bool isAnime}) {
  final word = isAnime ? rankingMap[ranking] : mangaRankingMap[ranking];
  return word == null ? null : ExploreImages.ranking(word, isAnime ? 'anime' : 'manga');
}

IconData _rankingIcon(Enum ranking) => switch (ranking) {
      RankingType.UPCOMING => Icons.event_available_rounded,
      RankingType.BYPOPULARITY || MangaRanking.bypopularity => Icons.local_fire_department_rounded,
      RankingType.ALL || MangaRanking.all => Icons.emoji_events_rounded,
      RankingType.AIRING => Icons.sensors_rounded,
      RankingType.FAVOURITE || MangaRanking.favorite => Icons.favorite_rounded,
      RankingType.MOVIE => Icons.movie_rounded,
      RankingType.OVA => Icons.album_rounded,
      RankingType.SPECIAL => Icons.auto_awesome_rounded,
      RankingType.TV => Icons.tv_rounded,
      RankingType.ONA => Icons.public_rounded,
      MangaRanking.manga => Icons.menu_book_rounded,
      MangaRanking.lightnovels || MangaRanking.novels => Icons.auto_stories_rounded,
      MangaRanking.manhwa || MangaRanking.manhua => Icons.translate_rounded,
      MangaRanking.oneshots => Icons.bolt_rounded,
      MangaRanking.doujin => Icons.draw_rounded,
      _ => Icons.leaderboard_rounded,
    };

/// Translated rankings of a category, in the order Explore shows them.
List<({Enum ranking, String label})> rankingEntries(bool isAnime) {
  final map = isAnime
      ? desiredTopAnimeOrderSS(S.current)
      : desiredMangaRankingMapSS(S.current);
  return [for (final e in map.entries) (ranking: e.key, label: e.value)];
}

Widget _rankingCard(BuildContext context, ({Enum ranking, String label}) e, int index,
        {required bool isAnime, double width = kExploreCardWidth, double height = kExploreCardHeight}) =>
    ExplorePictureCard(
      asset: rankingImage(e.ranking, isAnime: isAnime),
      icon: _rankingIcon(e.ranking),
      label: e.label,
      hue: 18.0 + index * 34,
      width: width,
      height: height,
      onTap: () => AppRoutes.openSearch(context, query: rankingQuery(e.ranking, isAnime: isAnime)),
    );

/// Rankings (top by score, popularity, airing…) as a row of picture cards (DailyAL) that open
/// the search screen.
class RankingsRow extends StatelessWidget {
  final bool isAnime;

  const RankingsRow({super.key, required this.isAnime});

  @override
  Widget build(BuildContext context) {
    final entries = rankingEntries(isAnime);
    return SizedBox(
      height: kExploreCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kExplorePadding),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _rankingCard(context, entries[i], i, isAnime: isAnime),
      ),
    );
  }
}

/// Every ranking as a grid of picture cards (the "View all" of the rankings row).
class RankingsScreen extends StatelessWidget {
  final bool isAnime;

  const RankingsScreen({super.key, required this.isAnime});

  @override
  Widget build(BuildContext context) {
    ExploreImages.registerLicense();
    final entries = rankingEntries(isAnime);
    return Scaffold(
      appBar: AppBar(title: Text(S.current.Explore_Rankings)),
      body: GridView.builder(
        padding: const EdgeInsets.all(kExplorePadding),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 112,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: entries.length,
        itemBuilder: (context, i) => _rankingCard(context, entries[i], i,
            isAnime: isAnime, width: double.infinity, height: 112),
      ),
    );
  }
}

String _genreGroupLabel(String type) => switch (type) {
      'Genres' => S.current.Genres,
      'Themes' => S.current.Explore_Genre_Themes,
      'Demographics' => S.current.Explore_Genre_Demographics,
      GenreGroup.explicitType => S.current.Explore_Genre_Explicit,
      _ => type,
    };

IconData _genreGroupIcon(String type) => switch (type) {
      'Themes' => Icons.palette_rounded,
      'Demographics' => Icons.groups_rounded,
      GenreGroup.explicitType => Icons.eighteen_up_rating_rounded,
      _ => Icons.category_rounded,
    };

/// The NSFW preference, followed live (the default when no bloc is above, as in tests).
bool _watchNsfw(BuildContext context) => context.select<PreferencesBloc?, bool>(
    (bloc) => bloc?.state.general.nsfw ?? Preferences.general.nsfw);

/// Genre groups (Genres, Explicit genres, Themes, Demographics) as DailyAL's picture cards; a
/// card opens the genres of its group. The groups come from the app's MAL tables, so the row
/// never waits for the network.
///
/// Explicit genres follow the NSFW preference: with it off, the card shows no picture (a flat
/// 18+ block) and asks before turning the preference on, since MyAnimeList hides those titles
/// from every browse and search while it is off.
class GenresRow extends StatelessWidget {
  final String category;

  const GenresRow({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final nsfw = _watchNsfw(context);
    final groups = ExploreData.genreGroups(category);
    return SizedBox(
      height: kExploreCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kExplorePadding),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final group = groups[i];
          final hidden = group.isExplicit && !nsfw;
          return ExplorePictureCard(
            asset: ExploreImages.genreGroup(group.type, category),
            icon: _genreGroupIcon(group.type),
            label: _genreGroupLabel(group.type),
            // DailyAL shows the group name only (no genre count).
            caption: hidden ? S.current.Exp_Nsfw_Hidden : null,
            hue: 200.0 + i * 55,
            hidden: hidden,
            width: kExploreCardWidth,
            height: kExploreCardHeight,
            onTap: () async {
              if (hidden && !await _askNsfw(context)) return;
              if (context.mounted) _showGenres(context, group, category);
            },
          );
        },
      ),
    );
  }

  /// Asks to turn the NSFW preference on; true when it is on afterwards.
  static Future<bool> _askNsfw(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.eighteen_up_rating_rounded),
        title: Text(S.current.Exp_Nsfw_Title),
        content: Text(S.current.Exp_Nsfw_Body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.current.Cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.current.Exp_Nsfw_Enable),
          ),
        ],
      ),
    );
    if (yes != true) return false;
    final bloc = Preferences.bloc;
    if (bloc == null) return false;
    bloc.add(GeneralPreferencesChanged((p) => p.copyWith(nsfw: true)));
    return true;
  }

  void _showGenres(BuildContext context, GenreGroup group, String category) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => _GenresSheet(
          controller: controller,
          group: group,
          category: category,
          onPick: (id) {
            Navigator.of(sheetContext).pop();
            AppRoutes.push<void>(context, GeneralSearchScreen.byGenre(ids: [id], category: category));
          },
        ),
      ),
    );
  }
}

/// The genres of one group as DailyAL's picture cards (two per row on a phone), with the
/// number of titles when mwl-api gives it.
class _GenresSheet extends StatelessWidget {
  final ScrollController controller;
  final GenreGroup group;
  final String category;
  final ValueChanged<int> onPick;

  const _GenresSheet({
    required this.controller,
    required this.group,
    required this.category,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final manga = category == 'manga';
    return FutureBuilder<Map<int, int>>(
      future: ExploreData.genreCounts(category),
      builder: (context, snapshot) {
        final counts = snapshot.data ?? const <int, int>{};
        return CustomScrollView(
          controller: controller,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kExplorePadding, 0, kExplorePadding, 12),
                child: Text(_genreGroupLabel(group.type),
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(kExplorePadding, 0, kExplorePadding, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 100,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: group.ids.length,
                itemBuilder: (context, i) {
                  final id = group.ids[i];
                  final count = counts[id];
                  return ExplorePictureCard(
                    asset: ExploreImages.genre(id, category),
                    icon: _genreGroupIcon(group.type),
                    label: SearchCatalog.genreLabel(id, manga: manga),
                    caption: count == null ? null : S.current.Exp_Genre_Titles(compactCount(context, count)),
                    hue: 200.0 + i * 23,
                    width: double.infinity,
                    height: 100,
                    onTap: () => onPick(id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A wide entry card of the Explore page (studios directory): icon, title, chevron.
class ExploreEntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const ExploreEntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kExplorePadding),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(icon, color: scheme.onSecondaryContainer),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleMedium),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The studios directory entry (anime only).
class StudiosEntry extends StatelessWidget {
  const StudiosEntry({super.key});

  @override
  Widget build(BuildContext context) => ExploreEntryCard(
        icon: Icons.business_rounded,
        title: S.current.Exp_Studios,
        onTap: () => AppRoutes.push<void>(context, const StudiosScreen()),
      );
}

/// The seasonal picker of DailyAL's Explore page (`SeasonalWidget`): a row of years, the four
/// seasons under it, then "Search by season" (opens the picked season) and "Weekly anime" (the
/// airing calendar). Same rows, font sizes, gaps and margins as DailyAL; the rows grow with
/// the text size, and the two buttons go one under the other when they do not fit side by
/// side, so no language cuts a label.
class SeasonalPicker extends StatefulWidget {
  /// DailyAL's side margin of the picker.
  static const horizPadding = 20.0;

  const SeasonalPicker({super.key});

  @override
  State<SeasonalPicker> createState() => _SeasonalPickerState();
}

class _SeasonalPickerState extends State<SeasonalPicker> {
  late final List<int> _years = [
    for (var y = lastSeasonYear(); y >= kFirstSeasonYear; y--) y,
  ];
  late int _yearIndex = _years.indexOf(SeasonKey.current().year).clamp(0, _years.length - 1);
  int _seasonIndex = SeasonKey.current().season.index;
  final PageStorageBucket _yearsBucket = PageStorageBucket();

  /// The season the two rows point at.
  SeasonKey get selected => SeasonKey(SeasonType.values[_seasonIndex], _years[_yearIndex]);

  @override
  Widget build(BuildContext context) {
    // DailyAL's rows are 45 high; they follow the text size here so large text is not clipped.
    final rowHeight = MediaQuery.textScalerOf(context).scale(45);
    const listPadding = EdgeInsets.symmetric(horizontal: SeasonalPicker.horizPadding);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HeaderWidget is a ScrollablePositionedList: it saves an `ItemPosition` in the page
        // storage, which a plain scroll view of the page would read back as its offset.
        PageStorage(
          bucket: _yearsBucket,
          child: HeaderWidget(
          key: const ValueKey('seasonal-years'),
          listPadding: listPadding,
          header: [for (final y in _years) '$y'],
          selectedIndex: _yearIndex,
          shouldAnimate: false,
          fontSize: 19,
          height: rowHeight,
          onPressed: (index) {
            if (mounted) setState(() => _yearIndex = index);
          },
        ),
        ),
        const SizedBox(height: 15),
        _SeasonsRow(
          padding: listPadding,
          height: rowHeight,
          selectedIndex: _seasonIndex,
          onPressed: (index) {
            if (mounted) setState(() => _seasonIndex = index);
          },
        ),
        const SizedBox(height: 15),
        Padding(
          padding: listPadding,
          child: OverflowBar(
            alignment: MainAxisAlignment.spaceEvenly,
            overflowAlignment: OverflowBarAlignment.center,
            overflowSpacing: 8,
            children: [
              ShadowButton(
                onPressed: () => AppRoutes.push<void>(context, SeasonalScreen(initial: selected)),
                child: Text(S.current.Search_By_Season),
              ),
              ShadowButton(
                onPressed: () =>
                    AppRoutes.push<void>(context, WeeklyScheduleScreen(season: selected)),
                child: Text(S.current.WeeklyAnime),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The seasons row of [SeasonalPicker]: DailyAL's `HeaderWidget` items (font 13, 20 px
/// inside each button, 10 px between them). `HeaderWidget` scrolls its selected item to the
/// start, which on four items leaves only "Fall" and an empty row in autumn; this row lays
/// out from the first season and centres the selected one as far as the row can scroll.
///
/// It scrolls its own [ScrollController] only: `Scrollable.ensureVisible` would also scroll
/// the Explore page back up to the picker each time the picker is built again.
class _SeasonsRow extends StatefulWidget {
  final EdgeInsets padding;
  final double height;
  final int selectedIndex;
  final ValueChanged<int> onPressed;

  const _SeasonsRow({
    required this.padding,
    required this.height,
    required this.selectedIndex,
    required this.onPressed,
  });

  @override
  State<_SeasonsRow> createState() => _SeasonsRowState();
}

class _SeasonsRowState extends State<_SeasonsRow> {
  final _selectedKey = GlobalKey();
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centreSelected(animate: false));
  }

  @override
  void didUpdateWidget(_SeasonsRow old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centreSelected(animate: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Offset of the row that puts the selected season in its middle, within the row's extent.
  void _centreSelected({required bool animate}) {
    if (!mounted || !_controller.hasClients) return;
    final item = _selectedKey.currentContext?.findRenderObject();
    if (item == null || !item.attached) return;
    // The nearest viewport of the item is the row's own, never the page's.
    final viewport = RenderAbstractViewport.maybeOf(item);
    if (viewport == null) return;
    final position = _controller.position;
    final target = viewport
        .getOffsetToReveal(item, 0.5, axis: Axis.horizontal)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) return;
    if (animate) {
      _controller.animateTo(target,
          duration: const Duration(milliseconds: 250), curve: const Cubic(0.23, 1, 0.32, 1));
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    const itemPadding = EdgeInsets.symmetric(horizontal: 20);
    final base = Theme.of(context).textTheme.bodyMedium;
    return SizedBox(
      height: widget.height,
      child: SingleChildScrollView(
        key: const ValueKey('seasonal-seasons'),
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        child: Row(
          children: [
            for (var i = 0; i < SeasonType.values.length; i++)
              Padding(
                key: i == widget.selectedIndex ? _selectedKey : null,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _item(i, base, itemPadding),
              ),
          ],
        ),
      ),
    );
  }

  Widget _item(int i, TextStyle? base, EdgeInsets itemPadding) {
    final selected = i == widget.selectedIndex;
    final label = Text(
      seasonLabel(SeasonType.values[i]),
      style: base?.copyWith(
        fontSize: 13,
        color: base.color?.withValues(alpha: selected ? 1.0 : 0.4),
      ),
    );
    void tap() => widget.onPressed(i);
    return selected
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: ShadowButton(onPressed: tap, padding: itemPadding, child: label),
          )
        : PlainButton(onPressed: tap, padding: itemPadding, child: label);
  }
}

/// A recommendation card: the liked title, the suggested one, and the reason.
class RecommendationCard extends StatelessWidget {
  final CommunityRecommendation item;
  final String category;
  final double width;

  const RecommendationCard({super.key, required this.item, required this.category, this.width = 300});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reportUrl = item.reportUrl(category);
    Widget side(String caption, RecoRef ref) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => AppRoutes.openContent(context, id: ref.id, category: category),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                AppImage(
                  url: ref.imageUrl,
                  height: 128,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 4),
                Text(ref.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        );
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  side(S.current.If_You_Liked, item.first),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 64, 6, 0),
                    child: Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.primary),
                  ),
                  side(S.current.Then_You_Might, item.second),
                ],
              ),
              if (item.text != null) ...[
                const SizedBox(height: 8),
                Expanded(
                  child: Text(item.text!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall),
                ),
              ] else
                const Spacer(),
              if (item.username != null || reportUrl != null)
                Row(
                  children: [
                    Expanded(
                      child: item.username == null
                          ? const SizedBox.shrink()
                          : InkWell(
                              onTap: () => AppRoutes.openUserProfile(context,
                                  tracker: AccountType.myanimelist, username: item.username),
                              child: Text(S.current.Explore_Reco_By(item.username!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium
                                      ?.copyWith(color: scheme.primary)),
                            ),
                    ),
                    if (reportUrl != null)
                      TextButton(
                        onPressed: () => reportRecommendation(context, item, reportUrl),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: scheme.onSurfaceVariant,
                        ),
                        child: Tooltip(
                          message: S.current.Report_Recommendation,
                          child: Text(S.current.Report),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// DailyAL's report confirmation, then MyAnimeList's report page of the recommendation
/// [item] at [url] in the browser (reporting needs the user's MAL website login).
Future<void> reportRecommendation(
    BuildContext context, CommunityRecommendation item, String url) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(S.current.Report_Confirmation),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${S.current.Recommendation_made_by} ${item.username ?? ''}'.trim(),
            style: Theme.of(dialogContext).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text('${item.first.title} → ${item.second.title}',
              style: Theme.of(dialogContext).textTheme.bodySmall),
          const SizedBox(height: 16),
          Text(S.current.Report_Description),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(S.current.Cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(S.current.ContinueW),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await launchWebView(url, context: context, external: true);
}

/// A review: reviewer, score, the reviewed title and the start of the text.
class ReviewCard extends StatelessWidget {
  final ReviewHtml review;
  final String category;
  final double width;

  const ReviewCard({super.key, required this.review, required this.category, this.width = 300});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final node = review.relatedNode;
    final score = review.overallRating;
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: node?.id == null
              ? null
              : () => AppRoutes.openContent(context, id: node!.id!, category: node.category ?? category),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppImage(
                      url: review.userPicture?.best,
                      width: 36,
                      height: 36,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(review.username ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (review.timeAdded != null)
                            Text(review.timeAdded!,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    if (score != null && score.isNotEmpty)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 14, color: scheme.onPrimaryContainer),
                              const SizedBox(width: 3),
                              Text(score,
                                  style: TextStyle(
                                      color: scheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (node?.title != null) ...[
                  const SizedBox(height: 10),
                  Text(node!.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
                ],
                const SizedBox(height: 6),
                Expanded(
                  child: Text(review.reviewText ?? '',
                      overflow: TextOverflow.fade, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A ranked character or voice actor: rank at the top, ♥ favourites count at the bottom
/// (MAL's top lists give it; for a character without it, the Top MAL characters list).
class PersonTile extends StatelessWidget {
  final RankedPersonHtml person;
  final bool isPerson;

  const PersonTile({super.key, required this.person, required this.isPerson});

  int? get favorites =>
      person.favorites ?? (isPerson ? null : TopCharacters.instance.favoritesOf(person.id));

  @override
  Widget build(BuildContext context) {
    final favorites = this.favorites;
    return PosterTile(
      imageUrl: person.image?.best,
      title: person.name,
      subtitle: isPerson ? person.birthday : person.otherName,
      width: 110,
      imageHeight: 150,
      badge: person.rank == null ? null : CornerBadge('#${person.rank}'),
      bottomBadge: favorites == null
          ? null
          : CornerBadge(
              compactCount(context, favorites),
              icon: Icons.favorite_rounded,
              semanticLabel: S.current.Exp_Favorites(favorites),
            ),
      onTap: () => AppRoutes.push<void>(
        context,
        CharacterScreen(id: person.id, category: isPerson ? 'person' : 'character'),
      ),
    );
  }
}

/// Horizontal strip of [children] built lazily, with the Explore side margins.
class HorizontalStrip extends StatelessWidget {
  final double height;
  final int count;
  final double gap;
  final IndexedWidgetBuilder itemBuilder;

  const HorizontalStrip({
    super.key,
    required this.height,
    required this.count,
    required this.itemBuilder,
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kExplorePadding),
        itemCount: count,
        separatorBuilder: (_, __) => SizedBox(width: gap),
        itemBuilder: itemBuilder,
      ),
    );
  }
}
