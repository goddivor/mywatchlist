import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_forum_page.dart' show AnilistThreadList;
import 'package:mywatchlist/services/api/Anilist/anilist_media_detail.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart' show AnilistRecommendationVote;
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_thread_tile.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_cards.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_format.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_header.dart' show openAnilistRanking;
import 'package:mywatchlist/widgets/Anilist/people/anilist_people_ui.dart'
    show anilistLanguageLabel, anilistVoiceLanguages;
import 'package:mywatchlist/widgets/Anilist/search/anilist_labels.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_result_tiles.dart' show anilistScoreRole;
import 'package:mywatchlist/widgets/Anilist/social/anilist_activity_feed.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart' show openAnilistUser;
import 'package:mywatchlist/widgets/Anilist/social/anilist_review_tile.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_reviews_feed.dart' show openAnilistReviews;
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Pages of one list of the title page (characters, staff, recommendations): the page asks
/// for more when its scroll nears the end ([loadMore] does nothing while a page loads or
/// after the last one).
class AnilistPager<T> extends ChangeNotifier {
  AnilistPager(this._loader);

  final Future<AnilistPeoplePage<T>> Function(int page) _loader;
  final List<T> items = [];
  int _page = 0;
  bool hasNext = true;
  bool loading = false;
  Object? error;
  bool _disposed = false;

  bool get started => _page > 0 || loading;

  Future<void> loadMore() async {
    if (loading || !hasNext || _disposed) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await _loader(_page + 1);
      if (_disposed) return;
      _page++;
      items.addAll(page.items);
      hasNext = page.hasNext && page.items.isNotEmpty;
    } catch (e) {
      if (_disposed) return;
      error = e;
    }
    loading = false;
    notifyListeners();
  }

  /// Replaces [old] by [now] (a vote).
  void replace(T old, T now) {
    final i = items.indexOf(old);
    if (i < 0) return;
    items[i] = now;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The rows of an [AnilistPager] as slivers: a list (or a grid with [gridWidth]), then a
/// spinner, Retry, or [empty] when there is nothing at all.
class AnilistPagerSliver<T> extends StatelessWidget {
  const AnilistPagerSliver({
    super.key,
    required this.pager,
    required this.itemBuilder,
    required this.empty,
    this.gridWidth,
    this.gridHeight,
  });

  final AnilistPager<T> pager;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String empty;
  final double? gridWidth;
  final double? gridHeight;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pager,
      builder: (context, _) {
        final items = pager.items;
        final footer = pager.loading
            ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            : pager.error != null
                ? AnilistTabMessage(text: S.of(context).Amp_Load_Failed, onRetry: pager.loadMore)
                : items.isEmpty && !pager.hasNext
                    ? AnilistTabMessage(text: empty)
                    : const SizedBox(height: 96);
        final body = gridWidth == null
            ? SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: itemBuilder(context, items[i]),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: gridWidth!,
                    mainAxisExtent: gridHeight,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => itemBuilder(context, items[i]),
                ),
              );
        return SliverMainAxisGroup(slivers: [body, SliverToBoxAdapter(child: footer)]);
      },
    );
  }
}

/// A centred line of a tab (empty state, error with Retry).
class AnilistTabMessage extends StatelessWidget {
  const AnilistTabMessage({super.key, required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Text(text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (onRetry != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.tonal(onPressed: onRetry, child: Text(S.of(context).Alp_Retry)),
            ),
        ],
      ),
    );
  }
}

/// The voice actor language picker of the Characters tab.
class AnilistLanguageBar extends StatelessWidget {
  const AnilistLanguageBar({super.key, required this.language, required this.onChanged});

  final String language;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(s.Amp_Voice_Language, style: Theme.of(context).textTheme.labelLarge),
          const Spacer(),
          DropdownButton<String>(
            value: language,
            underline: const SizedBox.shrink(),
            items: [
              for (final l in anilistVoiceLanguages)
                DropdownMenuItem(value: l, child: Text(anilistLanguageLabel(l))),
            ],
            onChanged: (v) {
              if (v != null && v != language) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

/// The Relations tab: every related title grouped by relation, then the recommendations
/// with votes and "Recommend a title".
List<Widget> anilistRelationsSlivers(
  BuildContext context, {
  required AnilistMediaDetail detail,
  required AnilistPager<AnilistRecommendation> recommendations,
  required void Function(AnilistRecommendation r, AnilistRecommendationVote vote) onVote,
  required VoidCallback onRecommend,
}) {
  final s = S.of(context);
  final relations = detail.sortedRelations;
  return [
    if (relations.isEmpty)
      SliverToBoxAdapter(child: AnilistTabMessage(text: s.Amp_No_Relations))
    else ...[
      SliverToBoxAdapter(child: AnilistSectionTitle(s.Related)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            mainAxisExtent: 214,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: relations.length,
          itemBuilder: (_, i) => AnilistTitleCard(
            media: relations[i].media,
            label: AnilistMediaFormat.relation(relations[i].type),
          ),
        ),
      ),
    ],
    SliverToBoxAdapter(
      child: AnilistSectionTitle(
        s.Recommendations,
        trailing: TextButton.icon(
          onPressed: onRecommend,
          icon: const Icon(Icons.add, size: 18),
          label: Text(s.Amp_Recommend),
        ),
      ),
    ),
    AnilistPagerSliver<AnilistRecommendation>(
      pager: recommendations,
      empty: s.Amp_No_Recommendations,
      gridWidth: 120,
      gridHeight: 248,
      itemBuilder: (context, r) => AnilistTitleCard(
        media: r.media,
        footer: AnilistVoteBar(recommendation: r, onVote: (v) => onVote(r, v)),
      ),
    ),
  ];
}

/// The Stats tab: rankings, status distribution, score distribution and recent activity.
class AnilistStatsTab extends StatelessWidget {
  const AnilistStatsTab({super.key, required this.detail});

  final AnilistMediaDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = detail;
    final rankings = [...d.rankings]
      ..sort((a, b) => a.scope != b.scope ? a.scope.compareTo(b.scope) : a.rank.compareTo(b.rank));
    final statuses = d.statusDistribution.values.fold<int>(0, (a, b) => a + b);
    final scores = d.scoreDistribution.values.fold<int>(0, (a, b) => a + b);
    final trends = [for (final t in d.trends.reversed) if (t.trending >= 0) t];
    if (rankings.isEmpty && statuses == 0 && scores == 0 && trends.length < 2) {
      return AnilistTabMessage(text: s.Amp_No_Stats);
    }
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rankings.isNotEmpty) ...[
          AnilistSectionTitle(s.Amp_Rankings),
          for (final r in rankings)
            ListTile(
              dense: true,
              leading: Icon(r.rated ? Icons.star_rounded : Icons.favorite_rounded,
                  color: r.rated ? colors.score.color : colors.danger.color),
              title: Text(AnilistMediaFormat.ranking(r)),
              subtitle: r.format == null ? null : Text(AnilistLabels.format(r.format!)),
              onTap: () => openAnilistRanking(context, d, r),
            ),
        ],
        if (statuses > 0) ...[
          AnilistSectionTitle(s.Amp_Status_Distribution),
          _StatusBar(detail: d, total: statuses),
        ],
        if (scores > 0) ...[
          AnilistSectionTitle(s.Amp_Score_Distribution),
          _ScoreBars(distribution: d.scoreDistribution),
        ],
        if (trends.length >= 2) ...[
          AnilistSectionTitle(s.Amp_Recent_Activity),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _TrendPainter(
                  values: [for (final t in trends) t.trending.toDouble()],
                  line: Theme.of(context).colorScheme.primary,
                  fill: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 96),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.detail, required this.total});

  final AnilistMediaDetail detail;
  final int total;

  static const _order = ['CURRENT', 'PLANNING', 'COMPLETED', 'PAUSED', 'DROPPED', 'REPEATING'];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final entries = [
      for (final k in _order)
        if ((detail.statusDistribution[k] ?? 0) > 0) (k, detail.statusDistribution[k]!),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final (status, n) in entries)
                    Expanded(
                      flex: math.max(1, (n * 1000 / total).round()),
                      child: ColoredBox(color: colors.statusOf(status)?.color ?? scheme.primary),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final (status, n) in entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.statusOf(status)?.color ?? scheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const SizedBox(width: 10, height: 10),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${AnilistLabels.listStatus(status, anime: detail.isAnime)} '
                      '${AnilistMediaFormat.number(n)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ten bars (10 to 100) on anilist.co's red / amber / green scale, the count on top.
class _ScoreBars extends StatelessWidget {
  const _ScoreBars({required this.distribution});

  final Map<int, int> distribution;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final most = distribution.values.fold<int>(1, math.max);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var score = 10; score <= 100; score += 10)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        AnilistMediaFormat.compact(distribution[score] ?? 0),
                        maxLines: 1,
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: 4 + 96 * (distribution[score] ?? 0) / most,
                        decoration: BoxDecoration(
                          color: anilistScoreRole(context, score).color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('$score', style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.values, required this.line, required this.fill});

  final List<double> values;
  final Color line;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final top = values.reduce(math.max);
    final low = values.reduce(math.min);
    final span = top - low == 0 ? 1 : top - low;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - 4 - (size.height - 8) * (values[i] - low) / span;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.values != values || old.line != line;
}

/// The Social tab: the followed users' entries (score in their own format), the first forum
/// threads, then all threads and the title's activity.
class AnilistSocialTab extends StatelessWidget {
  const AnilistSocialTab({super.key, required this.detail, required this.signedIn});

  final AnilistMediaDetail detail;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = detail;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (signedIn) ...[
          AnilistSectionTitle(s.Amp_Following),
          if (d.following.isEmpty)
            AnilistTabMessage(text: s.Amp_No_Following)
          else
            for (final f in d.following)
              ListTile(
                leading: ClipOval(
                  child: AppImage(
                    url: f.user.avatarUrl,
                    width: 40,
                    height: 40,
                    placeholderColor: scheme.surfaceContainerHighest,
                  ),
                ),
                title: Text(f.user.name),
                subtitle: f.status == null
                    ? null
                    : Text([
                        AnilistLabels.listStatus(f.status!, anime: d.isAnime),
                        if (f.progress > 0 && f.status != 'COMPLETED') '${f.progress}',
                      ].join(' · ')),
                trailing: AnilistUserScore(
                  raw: f.scoreRaw,
                  format: f.scoreFormat,
                  style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
                ),
                onTap: () => openAnilistUser(context, f.user.name),
              ),
        ],
        AnilistSectionTitle(
          s.Amp_Forum_Threads,
          trailing: TextButton(
            onPressed: () => AppRoutes.push<void>(
              context,
              Scaffold(
                appBar: AppBar(title: Text(d.title)),
                body: AnilistThreadList(mediaId: d.id),
              ),
            ),
            child: Text(s.Amp_All_Threads),
          ),
        ),
        for (final t in d.threads) AnilistThreadTile(thread: t),
        ListTile(
          leading: const Icon(Icons.dynamic_feed_outlined),
          title: Text(s.Als_Activity),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppRoutes.push<void>(
            context,
            Scaffold(
              appBar: AppBar(title: Text(d.title)),
              body: AnilistActivityFeed(mediaId: d.id),
            ),
          ),
        ),
        const SizedBox(height: 96),
      ],
    );
  }
}

/// The Reviews tab: the most helpful reviews, then the whole feed (sorts, write a review).
class AnilistReviewsTab extends StatelessWidget {
  const AnilistReviewsTab({super.key, required this.detail});

  final AnilistMediaDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        for (final r in d.reviews) AnilistReviewTile(review: r, showMedia: false),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          child: FilledButton.tonalIcon(
            onPressed: () => openAnilistReviews(context, mediaId: d.id, title: d.title),
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(s.Reviews),
          ),
        ),
      ],
    );
  }
}
