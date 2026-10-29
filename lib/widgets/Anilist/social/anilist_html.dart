import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';

/// A YouTube video id of AniList's `<div class='youtube' id='…'>` (null when absent).
String? anilistYoutubeId(dom.Element element) {
  if (element.localName != 'div' || !element.classes.contains('youtube')) return null;
  final id = element.id.trim();
  return id.isEmpty ? null : id;
}

/// The address of AniList's `webm(url)` video (`<video src>` or its `<source src>`).
String? anilistVideoUrl(dom.Element element) {
  if (element.localName != 'video') return null;
  final direct = element.attributes['src'];
  if (direct != null && direct.isNotEmpty) return direct;
  for (final source in element.getElementsByTagName('source')) {
    final src = source.attributes['src'];
    if (src != null && src.isNotEmpty) return src;
  }
  return null;
}

/// True for AniList's spoiler markup (`<span class='markdown_spoiler'>`).
bool isAnilistSpoiler(dom.Element element) => element.classes.contains('markdown_spoiler');

/// AniList's HTML (`asHtml: true` text of threads, comments, activities, reviews, bios):
///
/// - spoilers stay hidden behind a "Spoiler" pill until tapped;
/// - `img` at their own width (`img220(url)` = 220 dp), never wider than the text, tap to zoom
///   (or to follow the link around them);
/// - YouTube embeds as a thumbnail with a play button, webm videos as a play tile: both open
///   the video;
/// - links to `anilist.co` open their screen in the app ([openAnilistLink]), others ask
///   first and open in the in-app browser.
class AnilistHtml extends StatelessWidget {
  const AnilistHtml(this.html, {super.key, this.style, this.maxImageWidth});

  final String html;
  final TextStyle? style;

  /// Widest a picture may be; defaults to the screen width minus 32.
  final double? maxImageWidth;

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    final maxWidth = maxImageWidth ?? MediaQuery.sizeOf(context).width - 32;
    return HtmlWidget(
      html,
      textStyle: textStyle,
      rebuildTriggers: [maxWidth],
      onTapUrl: (url) {
        openAnilistLink(context, url);
        return true;
      },
      customWidgetBuilder: (element) {
        if (isAnilistSpoiler(element)) {
          return InlineCustomWidget(
            child: AnilistSpoiler(
              child: AnilistHtml(element.innerHtml, style: textStyle, maxImageWidth: maxWidth),
            ),
          );
        }
        final youtube = anilistYoutubeId(element);
        if (youtube != null) {
          return _VideoTile(
            thumbnail: 'https://img.youtube.com/vi/$youtube/hqdefault.jpg',
            url: 'https://www.youtube.com/watch?v=$youtube',
            width: maxWidth,
          );
        }
        final video = anilistVideoUrl(element);
        if (video != null) return _VideoTile(url: video, width: maxWidth);
        if (element.localName == 'img') return _image(context, element, maxWidth);
        return null;
      },
    );
  }

  Widget _image(BuildContext context, dom.Element element, double maxWidth) {
    final src = element.attributes['src'] ?? element.attributes['data-src'];
    if (src == null || src.isEmpty) return const SizedBox.shrink();
    final asked = double.tryParse(element.attributes['width']?.replaceAll('%', '') ?? '');
    final percent = element.attributes['width']?.endsWith('%') == true;
    final width = asked == null || asked <= 0
        ? maxWidth
        : (percent ? maxWidth * asked / 100 : asked).clamp(24.0, maxWidth);
    final link = element.parent?.localName == 'a' ? element.parent!.attributes['href'] : null;
    final image = AppImage(
      url: src,
      width: width,
      fit: BoxFit.contain,
      alignment: AlignmentDirectional.centerStart,
      errorWidget: (_) => const SizedBox.shrink(),
    );
    return InlineCustomWidget(
      child: GestureDetector(
        onTap: () => link != null && link.isNotEmpty
            ? openAnilistLink(context, link)
            : zoomInImage(context, src),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SizedBox(width: width, child: image),
        ),
      ),
    );
  }
}

/// Hidden content: a "Spoiler" pill until tapped, then the content (tap again hides it).
class AnilistSpoiler extends StatefulWidget {
  const AnilistSpoiler({super.key, required this.child});

  final Widget child;

  @override
  State<AnilistSpoiler> createState() => _AnilistSpoilerState();
}

class _AnilistSpoilerState extends State<AnilistSpoiler> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_shown) {
      return GestureDetector(
        onLongPress: () => setState(() => _shown = false),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: widget.child,
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _shown = true),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_off_outlined, size: 14, color: scheme.onErrorContainer),
                const SizedBox(width: 4),
                Text(
                  S.of(context).Als_Spoiler,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.url, required this.width, this.thumbnail});

  final String url;
  final String? thumbnail;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = AppColors.of(context);
    final tileWidth = width.clamp(120.0, 480.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          width: tileWidth,
          height: tileWidth * 9 / 16,
          child: Material(
            color: scheme.surfaceContainerHighest,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => launchWebView(url, context: context),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnail != null)
                    AppImage(url: thumbnail, width: tileWidth, height: tileWidth * 9 / 16),
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.imageScrim,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 36,
                          semanticLabel: S.of(context).Als_Play_Video,
                          color: tokens.onImageScrim,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
