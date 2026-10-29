import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_media_format.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_media_parts.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// The rating histogram: one bar per whole point (1 to 10), each the sum of the two Kitsu steps
/// (out of 20) that make it, the tallest bar full height.
class KitsuRatingHistogram extends StatelessWidget {
  final KitsuRatingFrequencies ratings;

  const KitsuRatingHistogram(this.ratings, {super.key});

  static const double _barArea = 110;

  /// Votes per whole point, index 0 = 1 point.
  static List<int> buckets(KitsuRatingFrequencies r) => [
        for (var point = 1; point <= 10; point++) r[point * 2 - 1] + r[point * 2],
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final values = buckets(ratings);
    final peak = values.fold(0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kitsuPagePadding + 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(KitsuMediaFormat.ratings(ratings.total), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          SizedBox(
            height: _barArea + 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: Semantics(
                      label: S.current.Kmp_Rating_Bar(KitsuMediaFormat.count(values[i]), i + 1),
                      excludeSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: peak == 0 ? 2 : (_barArea * values[i] / peak).clamp(2.0, _barArea),
                              decoration: BoxDecoration(
                                color: values[i] == 0 ? scheme.surfaceContainerHighest : scheme.primary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${i + 1}', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A legal streaming link: site, the subtitle and dub languages and the regions. A tap opens it.
class KitsuStreamingTile extends StatelessWidget {
  final KitsuStreamingLink link;
  final VoidCallback onTap;

  const KitsuStreamingTile({super.key, required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = [
      if (link.subs.isNotEmpty) '${S.current.Kmp_Subs} ${link.subs.join(', ')}',
      if (link.dubs.isNotEmpty) '${S.current.Kmp_Dubs} ${link.dubs.join(', ')}',
      if (link.regions.isNotEmpty) link.regions.join(', '),
    ];
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(kitsuPagePadding + 10, 0, kitsuPagePadding, 0),
      leading: Icon(Icons.play_circle_outline, color: scheme.primary),
      title: Text(link.site, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: lines.isEmpty ? null : Text(lines.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Icon(Icons.open_in_new, size: 18, color: scheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

/// The trailer: its YouTube picture with a play mark.
class KitsuTrailerCard extends StatelessWidget {
  final String videoId;
  final VoidCallback onTap;

  const KitsuTrailerCard({super.key, required this.videoId, required this.onTap});

  static String thumbnail(String videoId) => 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kitsuPagePadding),
      child: Semantics(
        button: true,
        label: S.current.Kmp_Trailer,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(
                  url: thumbnail(videoId),
                  borderRadius: BorderRadius.circular(12),
                  placeholderColor: scheme.surfaceContainerHighest,
                ),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.imageScrim.withValues(alpha: AppColors.imageScrimOpacity),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.play_arrow_rounded, size: 40, color: tokens.onImageScrim),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A poster with the title and a small caption (a related title and its relation).
class KitsuPosterCard extends StatelessWidget {
  final KitsuMediaRef media;
  final String? caption;
  final double width;
  final VoidCallback onTap;

  const KitsuPosterCard({super.key, required this.media, required this.onTap, this.caption, this.width = 116});

  static const double aspect = 1.5;

  static double heightFor(BuildContext context, double width) =>
      width * aspect + 18 + MediaQuery.textScalerOf(context).scale(46);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = media.titles.display;
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppImage(
                url: media.poster?.url,
                width: width,
                height: width * aspect,
                borderRadius: BorderRadius.circular(10),
                placeholderColor: scheme.surfaceContainerHighest,
                semanticLabel: title,
              ),
              const SizedBox(height: 6),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An episode or a chapter: thumbnail when Kitsu has one, then the number, the title, the date
/// and the length.
class KitsuUnitCard extends StatelessWidget {
  final KitsuUnit unit;
  final KitsuMediaKind kind;
  final bool volume;

  const KitsuUnitCard({super.key, required this.unit, required this.kind, this.volume = false});

  static const double width = 190;

  static double heightFor(BuildContext context) =>
      width * 9 / 16 + 12 + MediaQuery.textScalerOf(context).scale(58);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = KitsuMediaFormat.unitName(kind, unit.number, volume: volume);
    final details = [
      if (unit.releasedAt != null) KitsuMediaFormat.date(unit.releasedAt),
      if (unit.length != null && unit.length! > 0) KitsuMediaFormat.minutes(unit.length!),
    ].join(' · ');
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(
            url: unit.thumbnail?.url,
            width: width,
            height: width * 9 / 16,
            borderRadius: BorderRadius.circular(10),
            placeholderColor: scheme.surfaceContainerHighest,
            errorWidget: (_) => ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Center(child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant)),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
          if (unit.title != null)
            Text(unit.title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
          if (details.isNotEmpty)
            Text(
              details,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// A row of the full episode or chapter list.
class KitsuUnitRow extends StatelessWidget {
  final KitsuUnit unit;
  final KitsuMediaKind kind;

  const KitsuUnitRow({super.key, required this.unit, required this.kind});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = [
      if (unit.releasedAt != null) KitsuMediaFormat.date(unit.releasedAt),
      if (unit.length != null && unit.length! > 0) KitsuMediaFormat.minutes(unit.length!),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kitsuPagePadding, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unit.thumbnail != null) ...[
            AppImage(
              url: unit.thumbnail!.url,
              width: 128,
              height: 72,
              borderRadius: BorderRadius.circular(8),
              placeholderColor: scheme.surfaceContainerHighest,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(KitsuMediaFormat.unitName(kind, unit.number), style: theme.textTheme.labelLarge),
                if (unit.title != null) Text(unit.title!, style: theme.textTheme.bodyMedium),
                if (details.isNotEmpty)
                  Text(details, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                if (unit.description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      unit.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A round avatar with a fallback initial.
class KitsuAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;

  const KitsuAvatar({super.key, required this.name, this.url, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: AppImage(
          url: url,
          width: size,
          height: size,
          placeholderColor: scheme.surfaceContainerHighest,
          errorWidget: (_) => ColoredBox(
            color: scheme.secondaryContainer,
            child: Center(
              child: Text(
                name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase(),
                style: TextStyle(color: scheme.onSecondaryContainer, fontSize: size * .4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A short Kitsu review: who, at which episode, the text and its likes. A tap opens the whole
/// text in a sheet.
class KitsuReactionCard extends StatelessWidget {
  final KitsuReaction reaction;
  final KitsuMediaKind kind;
  final double? width;
  final bool compact;

  const KitsuReactionCard({super.key, required this.reaction, required this.kind, this.width = 280, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final at = reaction.progress <= 0
        ? null
        : kind == KitsuMediaKind.anime
            ? S.current.Kmp_Reaction_Episode(reaction.progress)
            : S.current.Kmp_Reaction_Chapter(reaction.progress);
    final card = Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHigh,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: compact ? () => _openFull(context, at) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Row(
                children: [
                  KitsuAvatar(name: reaction.author.name, url: reaction.author.avatar?.url),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reaction.author.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
                        if (at != null)
                          Text(at, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (compact)
                Expanded(child: Text(reaction.text, maxLines: 6, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium))
              else
                Text(reaction.text, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.thumb_up_outlined, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(KitsuMediaFormat.likes(reaction.likes),
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }

  void _openFull(BuildContext context, String? at) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        maxChildSize: .95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(kitsuPagePadding, 0, kitsuPagePadding, 24),
          children: [KitsuReactionCard(reaction: reaction, kind: kind, width: null, compact: false)],
        ),
      ),
    );
  }
}

/// A character with its role and Japanese voice actor.
class KitsuCharacterCard extends StatelessWidget {
  final KitsuCharacterRole role;

  const KitsuCharacterCard({super.key, required this.role});

  static const double width = 100;

  static double heightFor(BuildContext context) =>
      width * 1.4 + 10 + MediaQuery.textScalerOf(context).scale(74);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(
            url: role.image?.url,
            width: width,
            height: width * 1.4,
            borderRadius: BorderRadius.circular(10),
            placeholderColor: scheme.surfaceContainerHighest,
            semanticLabel: role.name,
          ),
          const SizedBox(height: 6),
          Text(role.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
          Text(KitsuMediaFormat.role(role.role),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          if (role.voice != null)
            Text(role.voice!.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// A staff member with the role.
class KitsuStaffCard extends StatelessWidget {
  final KitsuStaffMember member;

  const KitsuStaffCard({super.key, required this.member});

  static const double width = 100;

  static double heightFor(BuildContext context) =>
      width * 1.4 + 10 + MediaQuery.textScalerOf(context).scale(60);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(
            url: member.image?.url,
            width: width,
            height: width * 1.4,
            borderRadius: BorderRadius.circular(10),
            placeholderColor: scheme.surfaceContainerHighest,
            semanticLabel: member.name,
          ),
          const SizedBox(height: 6),
          Text(member.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
          if (member.role.isNotEmpty)
            Text(member.role,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// A discussion post in the preview: author, spoiler and NSFW marks, the first lines, the counts.
class KitsuPostTile extends StatelessWidget {
  final KitsuPost post;
  final VoidCallback? onTap;

  const KitsuPostTile({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hidden = post.isSpoiler || post.isNsfw;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(kitsuPagePadding + 10, 8, kitsuPagePadding + 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KitsuAvatar(name: post.author.name, url: post.author.avatar?.url),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.author.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 2),
                  if (hidden)
                    Wrap(
                      spacing: 6,
                      children: [
                        if (post.isSpoiler) _Mark(S.current.Kmp_Spoiler),
                        if (post.isNsfw) _Mark(S.current.Kmp_Nsfw),
                      ],
                    )
                  else
                    Text(post.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    [
                      KitsuMediaFormat.likes(post.likes),
                      KitsuMediaFormat.comments(post.comments),
                    ].join(' · '),
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
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

class _Mark extends StatelessWidget {
  final String text;

  const _Mark(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(text, style: TextStyle(color: scheme.onErrorContainer, fontSize: 12)),
      ),
    );
  }
}

/// A quote: its lines, the speaker in front when Kitsu has one.
class KitsuQuoteTile extends StatelessWidget {
  final KitsuQuote quote;

  const KitsuQuoteTile(this.quote, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(kitsuPagePadding + 10, 6, kitsuPagePadding + 10, 6),
      child: Container(
        padding: const EdgeInsetsDirectional.only(start: 12),
        decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: scheme.primary, width: 3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in quote.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text.rich(TextSpan(children: [
                  if (line.character != null)
                    TextSpan(text: '${line.character}  ', style: theme.textTheme.labelLarge),
                  TextSpan(text: line.text, style: theme.textTheme.bodyMedium),
                ])),
              ),
          ],
        ),
      ),
    );
  }
}
