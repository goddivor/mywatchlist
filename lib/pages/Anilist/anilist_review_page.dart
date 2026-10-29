import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_html.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_review_composer.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/MAL/review/review_item.dart' show ReviewScoreBadge;
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumMessage, ForumSkeleton;

/// Opens the AniList review [id]; [initial] (the row tapped) shows its header at once.
/// Completes with the review as the page left it (votes), null when it never loaded.
Future<AnilistReview?> openAnilistReview(BuildContext context, int id, {AnilistReview? initial}) =>
    AppRoutes.push<AnilistReview>(context, AnilistReviewPage(reviewId: id, initial: initial));

/// A whole AniList review, laid out like the MAL review page: the title (banner, cover; a
/// tap opens it), reviewer and date, score, summary, the text, then "Was this review
/// helpful?" with up and down votes. The reviewer edits or deletes it from the app bar.
class AnilistReviewPage extends StatefulWidget {
  const AnilistReviewPage({super.key, required this.reviewId, this.initial, this.service});

  final int reviewId;
  final AnilistReview? initial;
  final AnilistSocialService? service;

  @override
  State<AnilistReviewPage> createState() => _AnilistReviewPageState();
}

class _AnilistReviewPageState extends State<AnilistReviewPage> {
  AnilistReview? _review;
  bool _full = false;
  bool _voting = false;
  Object? _error;
  int? _viewerId;

  AnilistSocialService get _service => widget.service ?? AnilistSocialService.instance;

  bool get _mine => _viewerId != null && _review?.user?.id == _viewerId;

  @override
  void initState() {
    super.initState();
    _review = widget.initial;
    _service.viewerId().then((id) {
      if (mounted) setState(() => _viewerId = id);
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final review = await _service.review(widget.reviewId);
      if (!mounted) return;
      setState(() {
        _review = review;
        _full = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _vote(AnilistReviewVote vote) async {
    final review = _review;
    if (review == null || _voting) return;
    final next = review.userRating == vote ? AnilistReviewVote.none : vote;
    setState(() => _voting = true);
    final result =
        await runAnilistWrite(context, () => _service.rateReview(review.id, next), service: _service);
    if (!mounted) return;
    setState(() {
      _voting = false;
      if (result != null) {
        _review = _review?.copyWith(
          rating: result.rating,
          ratingAmount: result.ratingAmount,
          userRating: result.userRating,
        );
      }
    });
  }

  Future<void> _edit() async {
    final media = _review?.media;
    if (media == null) return;
    final saved = await openAnilistReviewComposer(context,
        mediaId: media.id, mediaTitle: media.title, service: _service);
    if (!mounted || saved == null) return;
    if (saved == 0) {
      Navigator.of(context).pop();
    } else {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final review = _review;
    return PopScope<AnilistReview>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_review);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            review?.media?.title ?? s.Review,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_mine && _full)
              IconButton(tooltip: s.Edit, icon: const Icon(Icons.edit_outlined), onPressed: _edit),
            IconButton(
              tooltip: s.Open_In_Browser,
              icon: const Icon(Icons.open_in_browser),
              onPressed: () =>
                  openLink(context, 'https://anilist.co/review/${widget.reviewId}', confirm: false),
            ),
          ],
        ),
        body: review == null
            ? (_error != null
                ? ForumMessage(
                    icon: Icons.cloud_off_outlined,
                    title: anilistErrorText(_error!),
                    onRetry: _load,
                  )
                : const ForumSkeleton(count: 6))
            : RefreshIndicator(onRefresh: _load, child: _content(context, review)),
      ),
    );
  }

  Widget _content(BuildContext context, AnilistReview review) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = review.media;
    return CustomScrollView(
      slivers: [
        if (media != null) SliverToBoxAdapter(child: _MediaHeader(media: media)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnilistAuthorLine(
                  user: review.user,
                  time: review.createdAt,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (review.isPrivate)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: Icon(Icons.lock_outline,
                              size: 18, semanticLabel: s.Als_Private, color: scheme.onSurfaceVariant),
                        ),
                      ReviewScoreBadge(score: review.score, size: 24),
                      Text('/100',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  review.summary,
                  style: theme.textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                if (_full)
                  AnilistHtml(review.bodyHtml, maxImageWidth: MediaQuery.sizeOf(context).width - 40)
                else if (_error != null)
                  ForumMessage(
                    icon: Icons.cloud_off_outlined,
                    title: anilistErrorText(_error!),
                    onRetry: _load,
                    scrollable: false,
                  )
                else
                  const ForumSkeleton(count: 4, padding: EdgeInsets.zero),
              ],
            ),
          ),
        ),
        if (_full)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: _Votes(
                review: review,
                canVote: !_mine,
                busy: _voting,
                onVote: _vote,
              ),
            ),
          ),
      ],
    );
  }
}

class _MediaHeader extends StatelessWidget {
  const _MediaHeader({required this.media});

  final AnilistMediaRef media;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = AppColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final banner = media.bannerUrl;
    void open() => openAnilistLink(context, 'https://anilist.co/${media.category}/${media.id}');
    return InkWell(
      onTap: open,
      child: SizedBox(
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (banner != null && banner.isNotEmpty)
              AppImage(url: banner, width: width, height: 150)
            else
              ColoredBox(color: scheme.surfaceContainerHigh),
            if (banner != null && banner.isNotEmpty) ColoredBox(color: tokens.imageScrim),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppImage(
                    url: media.coverUrl,
                    width: 80,
                    height: 118,
                    borderRadius: BorderRadius.circular(8),
                    placeholderColor: scheme.surfaceContainerHighest,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      media.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: banner != null && banner.isNotEmpty
                            ? tokens.onImageScrim
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Votes extends StatelessWidget {
  const _Votes({
    required this.review,
    required this.canVote,
    required this.busy,
    required this.onVote,
  });

  final AnilistReview review;
  final bool canVote;
  final bool busy;
  final ValueChanged<AnilistReviewVote> onVote;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final up = review.userRating == AnilistReviewVote.up;
    final down = review.userRating == AnilistReviewVote.down;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (review.ratingAmount > 0)
              Text(
                s.Als_Review_Helpful(review.rating, review.ratingAmount),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            if (canVote) ...[
              if (review.ratingAmount > 0) const SizedBox(height: 12),
              Text(s.Als_Review_Was_Helpful, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _VoteButton(
                    selected: up,
                    icon: up ? Icons.thumb_up : Icons.thumb_up_outlined,
                    label: s.Als_Vote_Up,
                    onPressed: busy ? null : () => onVote(AnilistReviewVote.up),
                  ),
                  const SizedBox(width: 12),
                  _VoteButton(
                    selected: down,
                    icon: down ? Icons.thumb_down : Icons.thumb_down_outlined,
                    label: s.Als_Vote_Down,
                    onPressed: busy ? null : () => onVote(AnilistReviewVote.down),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => selected
      ? FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label))
      : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label));
}
