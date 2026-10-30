import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/mal_web/message_composer/message_markup.dart';

/// A message body (MAL's HTML, or [bbcodeToHtml] of a typed one) with bold, italic, underline,
/// strike, links (in-app screen for MAL pages, else asked then the in-app browser), quotes,
/// spoilers (tap to reveal) and pictures (fixed box, tap to zoom). Fits any width: pictures
/// never ask for more than [imageWidth], nothing measures an unbounded axis.
class MalMessageMarkup extends StatelessWidget {
  const MalMessageMarkup(this.html, {super.key, this.style, this.imageWidth = 220});

  final String html;
  final TextStyle? style;
  final double imageWidth;

  /// Replaces the network picture (widget tests: no network, no cache plugin).
  @visibleForTesting
  static Widget Function(String url)? debugImage;

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    return HtmlWidget(
      normalizeMalMessageHtml(html),
      textStyle: textStyle,
      onTapUrl: (url) {
        openLink(context, url);
        return true;
      },
      customWidgetBuilder: (element) {
        switch (element.localName) {
          case 'img':
            final src = element.attributes['src'] ?? '';
            if (src.isEmpty) return const SizedBox.shrink();
            return _MessageImage(url: src, width: imageWidth);
          case spoilerElement:
            return _Spoiler(
              html: element.innerHtml,
              name: element.attributes['data-name'],
              style: textStyle,
              imageWidth: imageWidth,
            );
          case 'blockquote':
            return _Quote(html: element.innerHtml, style: textStyle, imageWidth: imageWidth);
        }
        return null;
      },
    );
  }
}

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.url, required this.width});

  final String url;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = width * 0.75;
    final image = MalMessageMarkup.debugImage?.call(url) ??
        AppImage(
          url: url,
          width: width,
          height: height,
          placeholderColor: scheme.surfaceContainerHighest,
          errorWidget: (_) => ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: Center(child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        image: true,
        button: true,
        label: S.of(context).Pmc_Photo,
        child: GestureDetector(
          onTap: () => zoomInImage(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: width, height: height, child: image),
          ),
        ),
      ),
    );
  }
}

/// A spoiler: a tonal pill with its name until tapped, then the content (tap the label again
/// to hide it).
class _Spoiler extends StatefulWidget {
  const _Spoiler({required this.html, required this.name, required this.style, required this.imageWidth});

  final String html;
  final String? name;
  final TextStyle? style;
  final double imageWidth;

  @override
  State<_Spoiler> createState() => _SpoilerState();
}

class _SpoilerState extends State<_Spoiler> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final name = (widget.name ?? '').isEmpty ? s.Pmc_Spoiler : widget.name!;
    final label = Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_open ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 16, color: scheme.onSecondaryContainer),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _open ? s.Pmc_Hide_Spoiler(name) : s.Pmc_Show_Spoiler(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          label,
          if (_open)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: MalMessageMarkup(widget.html, style: widget.style, imageWidth: widget.imageWidth),
            ),
        ],
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.html, required this.style, required this.imageWidth});

  final String html;
  final TextStyle? style;
  final double imageWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = style?.color ?? scheme.onSurface;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
      decoration: BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: color.withValues(alpha: 0.45), width: 3)),
      ),
      child: MalMessageMarkup(
        html,
        style: style?.copyWith(color: color.withValues(alpha: 0.85)),
        imageWidth: imageWidth - 14,
      ),
    );
  }
}

/// The start of a message on one line (inbox rows), its BBCode drawn as styles.
class MalMessagePreview extends StatelessWidget {
  const MalMessagePreview(this.text, {super.key, this.style, this.maxLines = 1});

  final String text;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: malPreviewSpans(text, style: style)),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
