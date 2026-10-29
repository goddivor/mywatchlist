import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/MAL/home/animecardbar.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/dub_icon.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/common/score_reveal.dart';
import 'package:mywatchlist/widgets/user/contenteditwidget.dart';

// ---------------------------------------------------------------------------
// Number formats (one instance per locale: building a NumberFormat is slow and
// a card is built many times while a list scrolls)
// ---------------------------------------------------------------------------

final Map<String, NumberFormat> _compactFormats = {};
final Map<String, NumberFormat> _scoreFormats = {};

/// Compact counts ("252k") in the app language.
NumberFormat get userCountFormat => _compactFormats.putIfAbsent(
    Intl.getCurrentLocale(), () => NumberFormat.compact());

/// Scores with two decimals ("9.04") in the app language.
NumberFormat get ratingFormat => _scoreFormats.putIfAbsent(
    Intl.getCurrentLocale(), () => NumberFormat('0.00'));

// ---------------------------------------------------------------------------
// Pure rules (tested without a widget tree)
// ---------------------------------------------------------------------------

/// What a card knows about the user's list entry of its title.
@immutable
class CardListEntry {
  /// MAL's status word: `watching`, `reading`, `completed`, `on_hold`,
  /// `dropped`, `plan_to_watch`, `plan_to_read`.
  final String status;

  /// 0 = not scored.
  final int score;

  /// Episodes watched (anime) or chapters read (manga).
  final int progress;

  const CardListEntry({required this.status, this.score = 0, this.progress = 0});

  @override
  bool operator ==(Object other) =>
      other is CardListEntry &&
      other.status == status &&
      other.score == score &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(status, score, progress);
}

/// The entry a card shows. The list status cache wins over the entry that came
/// with the node (an edit or a removal updates the cache, the node is a
/// snapshot); [deleted] says the user removed the entry from this card.
CardListEntry? resolveCardEntry({
  required Anime node,
  required String category,
  CachedListStatus? cached,
  bool deleted = false,
}) {
  if (cached != null) {
    return CardListEntry(
        status: cached.status, score: cached.score, progress: cached.progress);
  }
  final mine = node.myListStatus;
  if (deleted || mine == null || mine.status.isEmpty) return null;
  return CardListEntry(
    status: mine.status,
    score: mine.score,
    progress: category == 'manga'
        ? (mine.numChaptersRead ?? 0)
        : mine.numEpisodesWatched,
  );
}

/// Episodes of [node] that should have aired at [now], from its start date and
/// weekly broadcast slot (JST), or null when it cannot be told: not airing,
/// not a weekly series, unknown total or partial start date.
///
/// MAL and Jikan give no per-episode schedule, so this counts one episode per
/// week from the premiere; a break in the season makes it an over-estimate,
/// which is why a count above the total hides the marker instead of guessing.
int? estimateAiredEpisodes(Anime node, DateTime now) {
  final status = node.status?.toLowerCase().replaceAll(' ', '_');
  if (status != 'currently_airing') return null;
  final type = node.mediaType?.toLowerCase();
  if (type != null && type != 'tv' && type != 'ona') return null;
  final total = node.numEpisodes;
  if (total == null || total <= 0) return null;
  final first = _premiere(node);
  if (first == null || now.isBefore(first)) return null;
  final weeks = now.difference(first).inSeconds ~/ Duration.secondsPerDay ~/ 7;
  final aired = weeks + 1;
  return aired > total ? null : aired;
}

final RegExp _fullDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

DateTime? _premiere(Anime node) {
  final match = _fullDate.firstMatch(node.startDate ?? '');
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  var hour = 0;
  var minute = 0;
  final parts = node.broadcast?.startTime.split(':');
  if (parts != null && parts.length >= 2) {
    hour = int.tryParse(parts[0]) ?? 0;
    minute = int.tryParse(parts[1]) ?? 0;
  }
  // Broadcast times are Japan Standard Time (UTC+9).
  return DateTime.utc(year, month, day, hour - 9, minute);
}

/// Fraction of the bar (0..1) for [count] of [total]; null when unknown.
double? progressFraction(int? count, int? total) {
  if (count == null || total == null || total <= 0) return null;
  return (count / total).clamp(0.0, 1.0);
}

// ---------------------------------------------------------------------------
// The card
// ---------------------------------------------------------------------------

/// Anime / manga cover card used by the home rows, search results and the
/// related/recommendation rows.
///
/// - `compact`: the cover with the title over a bottom scrim, the mean score
///   and members top-left, a progress bar on top and, with [showCardBar], the
///   edit button (status colour, your score) bottom-end.
/// - `comfortable`: the cover, then a bar with score/members and the status
///   button, then the title.
/// - `cover_only_grid`: the cover alone.
///
/// The status comes from the list status cache and follows edits. The edit
/// button opens the edit sheet ([showContentEditSheet]) unless [onEdit] is
/// given. Nothing here uses `Opacity`, a clip per card or a blur: the cover is
/// one decoration with a radius, the badges are alpha colours.
class AnimeGridCard extends StatelessWidget {
  final Anime node;
  final String category;
  final Function? onTap;
  final bool showText;

  /// Kept for compatibility: the status button shows whenever [showCardBar] is set.
  final bool showEdit;
  final bool showGenres;
  final double height;
  final double width;
  final double smallHeight;
  final double smallWidth;
  final double? aspectRatio;

  /// Shows a recommendation badge with this count.
  final int? numRecommendations;

  /// Kept for compatibility: the list status cache is always updated.
  final bool updateCache;
  final double borderRadius;
  final bool showTime;
  final bool showMemberCount;

  /// Shows the status / edit button (comfortable bar or compact corner).
  final bool showCardBar;
  final VoidCallback? onEdit;
  final NodeStatusValue? parentNsv;
  final double horizPadding;
  final VoidCallback? onClose;
  final bool showSelfScoreInsteadOfStatus;
  final Widget? additionalWidget;
  final DisplaySubType? displaySubType;
  final double? gridHeight;

  /// Title to show instead of `node.title` (preferred language).
  final String? displayTitle;

  /// Favourites count badge; null hides it.
  final int? favorites;

  /// Adult title: the cover is hidden while the NSFW preference is off. A
  /// MAL `black` node (`Anime.isAdult`) counts as adult too.
  final bool isNsfw;

  const AnimeGridCard({
    super.key,
    required this.node,
    this.category = "anime",
    this.onTap,
    this.numRecommendations,
    this.showText = true,
    this.showEdit = false,
    this.updateCache = false,
    this.height = 200,
    this.width = 140,
    this.showGenres = false,
    this.showTime = false,
    this.borderRadius = 6,
    this.showCardBar = false,
    this.aspectRatio,
    this.smallHeight = 30,
    this.smallWidth = 30,
    this.showMemberCount = true,
    this.onEdit,
    this.parentNsv,
    this.horizPadding = 5.0,
    this.onClose,
    this.showSelfScoreInsteadOfStatus = false,
    this.additionalWidget,
    this.displaySubType,
    this.gridHeight,
    this.displayTitle,
    this.favorites,
    this.isNsfw = false,
  });

  DisplaySubType get _displaySubType =>
      displaySubType ?? DisplaySubType.comfortable;
  bool get _compact => _displaySubType == DisplaySubType.compact;
  bool get _coverOnly => _displaySubType == DisplaySubType.cover_only_grid;

  bool get isEditable =>
      showCardBar && (category == 'anime' || category == 'manga');

  String get _title => displayTitle ?? node.title;

  bool get _adult => isNsfw || node.isAdult;

  /// "18+" only while adult titles are shown (otherwise the cover is hidden).
  bool _adultShown(BuildContext context) =>
      (_adult || node.isNsfwRated) && _CardImage._adultAllowed(context);

  @override
  Widget build(BuildContext context) {
    final title = _title;
    final time = showTime ? _timeLabel() : null;

    if (_compact || _coverOnly) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0, left: 6.0, right: 6.0),
        child: aspectRatio != null
            ? AspectRatio(
                aspectRatio: aspectRatio!,
                child: _cover(context, title, time),
              )
            : SizedBox(
                height: gridHeight ?? height,
                width: width,
                child: _cover(context, title, time),
              ),
      );
    }

    final cover = gridHeight != null
        ? Expanded(child: _cover(context, title, time))
        : AspectRatio(
            aspectRatio: aspectRatio ?? (width / height),
            child: _cover(context, title, time),
          );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizPadding),
      child: SizedBox(
        height: gridHeight,
        width: gridHeight == null ? width : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            cover,
            if (isEditable) _comfortableBar(context),
            if (showText) _titleText(title),
            if (showGenres) _genres(context),
            if (gridHeight != null) const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  // -- pieces ---------------------------------------------------------------

  BorderRadius get _coverRadius => isEditable && _displaySubType == DisplaySubType.comfortable
      ? BorderRadius.vertical(top: Radius.circular(borderRadius))
      : BorderRadius.circular(borderRadius);

  Widget _titleText(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        title,
        textAlign: TextAlign.start,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _genres(BuildContext context) {
    final genres = node.genres;
    if (genres == null || genres.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        genres.take(3).join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.start,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9),
      ),
    );
  }

  String? _timeLabel() {
    final broadcast = node.broadcast;
    if (broadcast != null) {
      final text = MalApi.getFormattedAiringDate(broadcast);
      if (text != null) return text;
    }
    final start = node.startDate;
    if (start == null || start.isEmpty) return null;
    final match = _fullDate.firstMatch(start);
    if (match == null) return start;
    try {
      return DateFormat.yMMMd(Intl.getCurrentLocale()).format(DateTime(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!)));
    } catch (_) {
      return match.group(0);
    }
  }

  Widget _comfortableBar(BuildContext context) {
    return _EntryScope(
      node: node,
      category: category,
      editable: true,
      onEdit: onEdit,
      builder: (context, entry, edit) => AnimeCardBar(
        radius: borderRadius,
        nsv: parentNsv ??
            (entry == null ? null : NodeStatusValue.fromString(entry.status)),
        node: node,
        entry: entry,
        showEdit: true,
        smallHeight: smallHeight,
        smallWidth: width,
        showMemberCount: showMemberCount,
        showSelfScoreInsteadOfStatus: showSelfScoreInsteadOfStatus,
        onTap: edit,
      ),
    );
  }

  /// The cover with every overlay.
  Widget _cover(BuildContext context, String title, String? time) {
    final radius = _coverRadius;
    final url = node.imageUrl.isEmpty ? null : node.imageUrl;
    final compact = _compact;
    final showsEntry = isEditable || node.myListStatus != null;
    final topInset = time != null ? 22.0 : 6.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        _CardImage(
          url: url,
          radius: radius,
          blurred: _adult,
          fixedSize: aspectRatio == null && gridHeight == null && !_coverOnly
              ? Size(width, height)
              : null,
        ),
        Positioned.fill(
          child: Semantics(
            button: true,
            label: title,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap == null ? null : () => onTap!(),
                onLongPress: url == null ? null : () => zoomInImage(context, url),
              ),
            ),
          ),
        ),
        if (compact)
          showsEntry
              ? _EntryScope(
                  node: node,
                  category: category,
                  editable: isEditable,
                  onEdit: onEdit,
                  builder: (context, entry, edit) =>
                      _compactLayer(context, title, entry, edit),
                )
              : _compactLayer(context, title, null, null),
        if (time != null) _timeCard(context, time),
        if (!_coverOnly) _badges(context, topInset, compact),
        if (!_coverOnly && _adultShown(context) || category == 'anime' && onClose == null)
          PositionedDirectional(
            top: topInset,
            end: 5,
            // "18+" sits top-end, on the line of the score badge, next to the dub badge.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_coverOnly && _adultShown(context))
                  Padding(
                    padding: EdgeInsetsDirectional.only(end: category == 'anime' ? 3 : 0),
                    child: _AdultBadge(radius: borderRadius),
                  ),
                if (category == 'anime' && onClose == null)
                  DubStatusBadge(animeId: node.id, radius: borderRadius),
              ],
            ),
          ),
        if (additionalWidget != null && !_coverOnly) additionalWidget!,
        if (onClose != null)
          PositionedDirectional(
            top: 4,
            end: 4,
            child: _CloseButton(onPressed: onClose!),
          ),
      ],
    );
  }

  /// Scrim, title, progress bar and edit button of the compact card.
  Widget _compactLayer(BuildContext context, String title, CardListEntry? entry,
      VoidCallback? edit) {
    final total = node.numEpisodes;
    final watched = category == 'anime' && entry != null
        ? progressFraction(entry.progress, total)
        : null;
    final aired = watched == null
        ? null
        : progressFraction(estimateAiredEpisodes(node, DateTime.now()), total);
    final nsv = parentNsv ??
        (entry == null ? null : NodeStatusValue.fromString(entry.status));
    return Stack(
      fit: StackFit.expand,
      children: [
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          height: 84,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(borderRadius)),
                gradient: AppColors.of(context).bottomScrimGradient,
              ),
            ),
          ),
        ),
        if (watched != null)
          PositionedDirectional(
            top: 0,
            start: 2,
            end: 2,
            height: 3,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ProgressPainter(
                  watched: watched,
                  aired: aired,
                  track: AppColors.of(context).onImageScrim.withValues(alpha: 0.4),
                  airedColor: AppColors.of(context).score.container,
                  watchedColor: AppColors.of(context).completed.container,
                  direction: Directionality.of(context),
                ),
              ),
            ),
          ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 6),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        color: AppColors.of(context).onImageScrim,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              if (edit != null)
                CardEditButton(
                  nsv: nsv,
                  score: entry?.score ?? 0,
                  radius: borderRadius,
                  onPressed: edit,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timeCard(BuildContext context, String time) {
    final tokens = AppColors.of(context);
    return PositionedDirectional(
      top: 0,
      start: 0,
      end: 0,
      height: 20,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.imageScrim,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(borderRadius)),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  time,
                  maxLines: 1,
                  style: TextStyle(color: tokens.onImageScrim, fontSize: 10),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mean score + members (compact only), favourites and recommendations,
  /// stacked top-start. Each badge is its own directional widget so that
  /// numbers never get reordered in right-to-left languages.
  Widget _badges(BuildContext context, double top, bool compact) {
    final members = node.members;
    final score = node.score;
    final hasScore = score > 0;
    final hasMembers = members > 0;
    final children = <Widget>[
      if (compact && showMemberCount && (hasScore || hasMembers))
        ScoreMembersBadge(
          score: hasScore ? score : null,
          members: hasMembers ? members : null,
          radius: borderRadius,
        ),
      if (favorites != null && favorites! > 0)
        _Pill(
          radius: borderRadius,
          semantics: S.current.Card_Favorites_Count(favorites!),
          icon: Icons.favorite,
          iconColor: AppColors.of(context).dropped.container,
          text: userCountFormat.format(favorites),
        ),
      if (numRecommendations != null)
        _Pill(
          radius: borderRadius,
          semantics: S.current.Card_Recommendations_Count(numRecommendations!),
          icon: Icons.people,
          text: userCountFormat.format(numRecommendations),
        ),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return PositionedDirectional(
      top: top,
      start: 5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            children[i],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cover
// ---------------------------------------------------------------------------

class _CardImage extends StatelessWidget {
  final String? url;
  final BorderRadius radius;
  final bool blurred;

  /// Slot size when it is known up front (saves a LayoutBuilder).
  final Size? fixedSize;

  const _CardImage({
    required this.url,
    required this.radius,
    required this.blurred,
    required this.fixedSize,
  });

  @override
  Widget build(BuildContext context) {
    if (blurred && !_adultAllowed(context)) {
      return _hidden(context);
    }
    return AppImage(
      url: url,
      width: fixedSize?.width,
      height: fixedSize?.height,
      placeholder: (context) => _Flat(radius: radius),
      errorWidget: (context) => _Flat(radius: radius, missing: true),
      imageBuilder: (context, provider) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          image: DecorationImage(image: provider, fit: BoxFit.cover),
        ),
      ),
    );
  }

  /// The cover stays a flat block: a blur filter on a scrolling list item
  /// costs a layer per card, and the title behind it is adult anyway.
  Widget _hidden(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_off_outlined, size: 28),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                S.current.Card_Adult_Hidden,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _adultAllowed(BuildContext context) {
    try {
      return context.select((PreferencesBloc b) => b.state.general.nsfw);
    } on ProviderNotFoundException {
      return Preferences.general.nsfw;
    }
  }
}

class _Flat extends StatelessWidget {
  final BorderRadius radius;
  final bool missing;
  const _Flat({required this.radius, this.missing = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: scheme.surfaceContainerHighest,
      ),
      child: missing
          ? Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_not_supported_outlined,
                          size: 32, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 4),
                      Text(
                        S.current.Card_No_Image,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.expand(),
    );
  }
}

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------

/// Badges over a cover: the image scrim with its white text (readable on any
/// picture, the same in light, dark and black).
TextStyle _badgeText(AppColors tokens) => TextStyle(
    color: tokens.onImageScrim, fontSize: 10, fontWeight: FontWeight.w500);

/// Mean score and member count, each in its own text so a right-to-left
/// language reorders the two parts as a whole instead of scrambling the digits
/// ("k 252 | 9.04"). The score hides behind a tap-to-reveal eye when the
/// "hide score" preference is on; the member count stays.
class ScoreMembersBadge extends StatelessWidget {
  final double? score;
  final int? members;
  final double radius;

  const ScoreMembersBadge({super.key, this.score, this.members, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    final score = this.score;
    final members = this.members;
    final scoreText = score == null ? null : ratingFormat.format(score);
    final tokens = AppColors.of(context);
    final soft = tokens.onImageScrim.withValues(alpha: 0.75);
    final parts = <Widget>[
      if (scoreText != null)
        ScoreReveal(
          iconSize: 12,
          iconColor: soft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 12, color: tokens.score.container),
              const SizedBox(width: 2),
              Text(scoreText, style: _badgeText(tokens)),
            ],
          ),
        ),
      if (members != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_alt_outlined, size: 11, color: soft),
            const SizedBox(width: 2),
            Text(userCountFormat.format(members), style: _badgeText(tokens)),
          ],
        ),
    ];
    final label = [
      if (scoreText != null) S.current.Card_Score(scoreText),
      if (members != null) S.current.Card_Members_Count(members),
    ].join(', ');
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.imageScrim,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < parts.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                parts[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final double radius;
  final IconData icon;
  final Color? iconColor;
  final String text;
  final String semantics;

  const _Pill({
    required this.radius,
    required this.icon,
    this.iconColor,
    required this.text,
    required this.semantics,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return IgnorePointer(
      child: Semantics(
        label: semantics,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.imageScrim,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: iconColor ?? tokens.onImageScrim),
                const SizedBox(width: 3),
                Text(text, style: _badgeText(tokens)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "18+" mark of an adult or "may not be safe" title (MAL `black` / `gray`).
class _AdultBadge extends StatelessWidget {
  final double radius;
  const _AdultBadge({required this.radius});

  @override
  Widget build(BuildContext context) {
    final role = AppColors.of(context).danger;
    return IgnorePointer(
      child: Semantics(
        label: S.current.Dsb_Adult_Semantics,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: role.container,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: Text(
              S.current.Dsb_Adult,
              style: TextStyle(
                  color: role.onContainer,
                  fontSize: 10,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: S.current.Card_Remove,
      excludeSemantics: true,
      child: Material(
        color: AppColors.of(context).imageScrim,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(Icons.close,
                size: 16, color: AppColors.of(context).onImageScrim),
          ),
        ),
      ),
    );
  }
}

/// The status button of a card: filled with the status colour, your score when
/// you gave one (and scores are not hidden), else a pencil. Opens the edit
/// sheet.
class CardEditButton extends StatelessWidget {
  final NodeStatusValue? nsv;
  final int score;
  final double radius;
  final VoidCallback onPressed;

  const CardEditButton({
    super.key,
    required this.nsv,
    required this.score,
    required this.radius,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final role = nsv?.role(context);
    final background = role?.container ?? tokens.imageScrim;
    final foreground = role?.onContainer ?? tokens.onImageScrim;
    final hasScore = score > 0 && !scoreHiddenOf(context);
    final status = nsv?.fullLabel;
    return Semantics(
      button: true,
      label: status == null ? S.current.Card_Edit : S.current.Card_Edit_Status(status),
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(radius * 2),
            bottomEnd: Radius.circular(radius),
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: hasScore ? 42 : 32,
            height: 32,
            child: Center(
              child: hasScore
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: foreground),
                        const SizedBox(width: 1),
                        Text('$score',
                            style: TextStyle(color: foreground, fontSize: 12)),
                      ],
                    )
                  : Icon(Icons.edit, size: 16, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aired (score amber) and watched (completed blue) episodes on a thin track,
/// drawn with plain rounded rectangles: no clip, no progress indicator widget
/// per card. Colours come from the theme tokens.
class _ProgressPainter extends CustomPainter {
  final double watched;
  final double? aired;
  final TextDirection direction;
  final Color track;
  final Color airedColor;
  final Color watchedColor;

  const _ProgressPainter({
    required this.watched,
    required this.aired,
    required this.direction,
    required this.track,
    required this.airedColor,
    required this.watchedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    void bar(double fraction, Color color) {
      final w = size.width * fraction;
      final left = direction == TextDirection.rtl ? size.width - w : 0.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, 0, w, size.height), radius),
        Paint()..color = color,
      );
    }

    bar(1, track);
    if (aired != null) bar(aired!, airedColor);
    bar(watched, watchedColor);
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.watched != watched ||
      old.aired != aired ||
      old.direction != direction ||
      old.track != track ||
      old.airedColor != airedColor ||
      old.watchedColor != watchedColor;
}

// ---------------------------------------------------------------------------
// List status of one card
// ---------------------------------------------------------------------------

/// Follows the list status of one title (cache, then the node's own entry) and
/// owns the edit action, so that only the parts that show the status rebuild.
class _EntryScope extends StatefulWidget {
  final Anime node;
  final String category;
  final bool editable;
  final VoidCallback? onEdit;
  final Widget Function(
      BuildContext context, CardListEntry? entry, VoidCallback? edit) builder;

  const _EntryScope({
    required this.node,
    required this.category,
    required this.editable,
    required this.builder,
    this.onEdit,
  });

  @override
  State<_EntryScope> createState() => _EntryScopeState();
}

class _EntryScopeState extends State<_EntryScope> {
  late ValueListenable<CachedListStatus?> _watch;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _watch = ListStatusCache.instance.watch(widget.node.id, category: widget.category);
    _watch.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_EntryScope old) {
    super.didUpdateWidget(old);
    if (old.node.id != widget.node.id || old.category != widget.category) {
      _watch.removeListener(_changed);
      _deleted = false;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _watch.removeListener(_changed);
    super.dispose();
  }

  void _edit() {
    final custom = widget.onEdit;
    if (custom != null) {
      custom();
      return;
    }
    showContentEditSheet(
      context,
      widget.category,
      widget.node,
      onDelete: () {
        if (mounted) setState(() => _deleted = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = resolveCardEntry(
      node: widget.node,
      category: widget.category,
      cached: _watch.value,
      deleted: _deleted,
    );
    return widget.builder(context, entry, widget.editable ? _edit : null);
  }
}

// ---------------------------------------------------------------------------
// Status values
// ---------------------------------------------------------------------------

/// A list status as a card shows it: short translated label (`CW`, `CMP`…),
/// colour, and the full translated name for screen readers.
class NodeStatusValue {
  /// Short translated label, null for an unknown status.
  String? status;

  /// Full translated name ("Plan to watch").
  String? fullLabel;

  /// MAL's status word the value was built from.
  String? key;
  /// The status chip colour (`AppColors.statusChips`), for callers without a
  /// `BuildContext`; widgets use [role].
  Color? color;
  int? index;
  ListStatusTone? tone;

  NodeStatusValue({this.status, this.color});

  NodeStatusValue.fromListStatus(MyListStatus myListStatus) {
    setDynStatus(myListStatus.status);
  }

  /// The status of [node]: its own entry, else the list status cache.
  NodeStatusValue.fromStatus(Anime node, {String? category}) {
    setDynStatus(node.myListStatus?.status ??
        ListStatusCache.instance.statusOf(node.id, category: category ?? 'anime'));
  }

  NodeStatusValue.fromString(String _status) {
    setDynStatus(_status);
  }

  void setDynStatus(String? dynStatus) {
    if (dynStatus == null) return;
    final word = dynStatus.toLowerCase();
    final s = S.current;
    switch (word) {
      case 'watching':
        status = s.Card_Short_Watching;
        fullLabel = s.Card_Status_Watching;
        index = 0;
      case 'reading':
        status = s.Card_Short_Reading;
        fullLabel = s.Card_Status_Reading;
        index = 0;
      case 'completed':
        status = s.Card_Short_Completed;
        fullLabel = s.Card_Status_Completed;
        index = 1;
      case 'on_hold':
        status = s.Card_Short_On_Hold;
        fullLabel = s.Card_Status_On_Hold;
        index = 2;
      case 'dropped':
        status = s.Card_Short_Dropped;
        fullLabel = s.Card_Status_Dropped;
        index = 3;
      case 'plan_to_watch':
        status = s.Card_Short_Plan_Watch;
        fullLabel = s.Card_Status_Plan_Watch;
        index = 4;
      case 'plan_to_read':
        status = s.Card_Short_Plan_Read;
        fullLabel = s.Card_Status_Plan_Read;
        index = 4;
      default:
        return;
    }
    key = word;
    tone = AppColors.toneOf(word);
    color = tone == null ? null : AppColors.statusChips[tone!];
  }

  /// The theme role of this status (DailyAL's hue: `container` + white bold
  /// `onContainer` for chips and buttons, `color` for marks); null when unknown.
  AppColorRole? role(BuildContext context) {
    final tone = this.tone;
    return tone == null ? null : AppColors.of(context).status(tone);
  }
}

/// Black or white, whichever reads best on [bgColor] (a colour that is not a
/// theme role).
Color getTextColor(Color bgColor) => readableOn(bgColor);

class PriorityBadge {
  String? status;
  Color? color;
}

// ---------------------------------------------------------------------------
// Edit sheet
// ---------------------------------------------------------------------------

/// Opens the edit sheet of [node] (anime or manga by [category]) and keeps the
/// list status cache in step with what the sheet saves, so every card shows the
/// new status at once. [onDelete] runs when the entry is removed from the list.
/// [updateCache] is kept for old callers; the cache is always updated.
Future<void> showContentEditSheet(
  BuildContext context,
  String category,
  Anime node, {
  bool updateCache = false,
  VoidCallback? onDelete,
}) {
  final cache = ListStatusCache.instance;
  void remember(dynamic saved) {
    final entry = _cachedFromSaved(saved, category);
    if (entry != null) cache.put(node.id, entry, category: category);
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ContentEditWidget(
          id: node.id,
          category: category,
          onListStatusChange: remember,
          onDelete: () {
            cache.remove(node.id, category: category);
            onDelete?.call();
          },
        ),
      ),
    ),
  );
}

/// The cache entry for what the edit sheet saved (`MyAnimeListStatus` or
/// `MyMangaListStatus`); null when the answer carries no status.
CachedListStatus? _cachedFromSaved(dynamic saved, String category) {
  try {
    final status = saved.status as String?;
    if (status == null || status.isEmpty) return null;
    final score = (saved.score as int?) ?? 0;
    final progress = category == 'manga'
        ? ((saved.numChaptersRead as int?) ?? 0)
        : ((saved.numEpisodesWatched as int?) ?? 0);
    return CachedListStatus(status: status, score: score, progress: math.max(0, progress));
  } catch (_) {
    return null;
  }
}
