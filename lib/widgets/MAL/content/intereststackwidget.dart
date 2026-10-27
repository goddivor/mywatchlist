import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplayType, gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/interest_stack_detail_screen.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/MAL/review/user_link.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';

/// Interest stacks as a horizontal strip (detail page) or a vertical list (stack screen,
/// "view all"): a fan of pictures, the title, the author (tap = quick user sheet), the
/// counts and, in the vertical layout, the date and the description.
class InterestStackContentList extends StatelessWidget {
  final DisplayType type;
  final double horizPadding;
  final List<InterestStack> interestStacks;
  static BorderRadius radius = BorderRadius.circular(12.0);
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;

  const InterestStackContentList({
    super.key,
    required this.horizPadding,
    required this.interestStacks,
    this.shrinkWrap = false,
    this.padding,
    this.type = DisplayType.list_horiz,
  });

  bool get isHoriz => type == DisplayType.list_horiz;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isHoriz ? 240 : null,
      child: ListView.builder(
        scrollDirection: isHoriz ? Axis.horizontal : Axis.vertical,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        padding: padding ??
            (isHoriz
                ? EdgeInsets.symmetric(horizontal: horizPadding + 15.0)
                : const EdgeInsets.symmetric(vertical: 20, horizontal: 5)),
        itemCount: interestStacks.length,
        itemBuilder: (context, index) => _StackCard(stack: interestStacks[index], isHoriz: isHoriz),
      ),
    );
  }
}

class _StackCard extends StatelessWidget {
  final InterestStack stack;
  final bool isHoriz;

  const _StackCard({required this.stack, required this.isHoriz});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = InterestStackContentList.radius;
    final images = List<String>.from((stack.imageUrls ?? const <String>[]).reversed);
    final updatedAt = stack.updatedAt;
    final description = stack.description;
    final secondary = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: isHoriz ? 0 : 10),
      child: SizedBox(
        width: isHoriz ? 310 : null,
        child: Material(
          borderRadius: radius,
          color: Colors.transparent,
          child: InkWell(
            onTap: () => gotoPage(context: context, newPage: InterestStackDetailScreen(stack: stack)),
            borderRadius: radius,
            child: Row(
              crossAxisAlignment: isHoriz ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: isHoriz ? 170 : 130,
                  height: isHoriz ? null : 230,
                  child: InterestStackPictures(images: images),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isHoriz) const SizedBox(height: 10),
                      Text(
                        stack.title?.trim() ?? '',
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
                      ),
                      InterestStackAuthor(username: stack.username),
                      const SizedBox(height: 8),
                      Text(S.current.Social_Stack_Entries(stack.entries ?? 0), style: secondary),
                      const SizedBox(height: 4),
                      Text(S.current.Social_Stack_Restacks(stack.reStacks ?? 0), style: secondary),
                      if (!isHoriz && updatedAt != null && updatedAt.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(updatedAt, style: secondary),
                      ],
                      if (!isHoriz && description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240.0),
                          child: Text(
                            description,
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ],
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

/// "by {username}" under a stack title. A real user opens the quick user sheet; the
/// placeholder names MAL uses for deleted accounts are shown as plain text.
class InterestStackAuthor extends StatelessWidget {
  final String? username;
  final TextAlign align;

  const InterestStackAuthor({super.key, required this.username, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final name = username;
    if (name == null || name.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final linkable = isLinkableUser(name);
    final text = Text(
      S.current.Social_Stack_By(name),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: linkable ? theme.colorScheme.primary : null,
      ),
    );
    if (!linkable) return Padding(padding: const EdgeInsets.only(top: 10), child: text);
    return Semantics(
      button: true,
      label: S.current.Social_Open_Profile(name),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => openMalUser(context, name),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: text),
      ),
    );
  }
}

/// Fan of up to a few posters (the first of [images] at the back, the last in front); a
/// tap opens them in the image viewer. With no picture, a neutral placeholder.
class InterestStackPictures extends StatelessWidget {
  final List<String> images;

  const InterestStackPictures({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (images.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.collections_bookmark_outlined, color: scheme.onSurfaceVariant),
      );
    }
    return Semantics(
      button: true,
      label: S.current.Social_Stack_Zoom,
      child: Stack(
        children: [
          for (final entry in images.asMap().entries)
            PositionedDirectional(
              end: entry.key * 20.0,
              top: entry.key * 10.0 + 10.0,
              bottom: entry.key * 10.0 + 10.0,
              child: GestureDetector(
                onTap: () => zoomInImageList(context, images.reversed.toList()),
                // A thin outline separates the overlapping posters (no blurred shadow, which
                // is costly on every card of a list).
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: scheme.surface.withValues(alpha: 0.9), width: 1.5),
                  ),
                  child: AspectRatio(
                    aspectRatio: 0.68,
                    child: AppImage(
                      url: entry.value,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Address of a stack page on MyAnimeList: the scraper may give a path (`/stacks/12`) or a
/// full address. Null without a usable address.
String? stackWebUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final value = url.trim();
  if (value.startsWith('http')) return value;
  return 'https://myanimelist.net${value.startsWith('/') ? '' : '/'}$value';
}

/// Fields offered by the share builder for a stack: link, title, author, the first
/// [maxEntries] entry titles and the description. Empty values are left out.
List<ShareField> stackShareFields({
  String? url,
  String? title,
  String? author,
  List<String> entries = const [],
  String? description,
  int maxEntries = 30,
}) {
  final shown = entries.where((e) => e.trim().isNotEmpty).take(maxEntries).toList();
  return [
    if (url != null && url.isNotEmpty) ShareField(label: S.current.Url, value: url, labelled: false),
    if (title != null && title.trim().isNotEmpty) ShareField(label: S.current.Title, value: title.trim()),
    if (author != null && author.isNotEmpty) ShareField(label: S.current.Social_Stack_Share_Author, value: author),
    if (shown.isNotEmpty)
      ShareField(
        label: S.current.Social_Stack_Share_Entries,
        value: shown.map((e) => '- $e').join('\n'),
        selected: false,
      ),
    if (description != null && description.trim().isNotEmpty)
      ShareField(label: S.current.Social_Stack_Share_Description, value: description.trim(), selected: false),
  ];
}
