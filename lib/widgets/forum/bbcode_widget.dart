import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:url_launcher/url_launcher.dart';

/// Converts BBCode (already bracket-converted to angle brackets) to HTML
/// and renders it. Matching DailyAL's BbcodeWidget exactly.
class BbcodeWidget extends StatelessWidget {
  static const tagsToReplace = {
    "<right>": "<div style='text-align: right;'>",
    "<list>": "<ul>",
    "<code>": "</div>",
    "</right>": "</div>",
    "</list>": "</ul>",
    "</url>": "</a>",
    "</color>": "</span>",
    "</span>": "</span>",
    "</center>": "</div>",
    "</img>": "",
    "<quote>": "<div>",
    "</quote>": "</div>",
    "<*>": "</li><li>",
    "< * >": "</li><li>",
    "</yt>": "</iframe>",
    "</code>": "</div>",
    "<br /><br />": "",
    "<Level>": "",
    "<Total Items Needed>": "",
  };

  static const validTags = [
    "<color",
    "<size",
    "<list",
    "<url",
    "<img",
    "<yt",
    "<spoiler",
    "<center",
  ];

  final String body;
  final Color? color;
  final bool minimize;
  final bool alignCenter;
  final bool shrinkWrap;

  const BbcodeWidget({
    super.key,
    required this.body,
    this.color,
    this.shrinkWrap = true,
    this.minimize = false,
    this.alignCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    final transformedHtml =
        '<div ${alignCenter ? 'style="text-align:center;"' : ''}>${applyTransform(body)}</div>';
    final theme = Theme.of(context);

    return HtmlWidget(
      transformedHtml,
      textStyle: TextStyle(
        fontSize: minimize ? 12 : 14,
        color: color ?? theme.colorScheme.onSurface,
        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
      ),
      onTapUrl: (url) async {
        final uri = Uri.tryParse(url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return true;
      },
      customWidgetBuilder: (element) {
        // Handle images: make them tappable and hide in minimize mode
        if (element.localName == 'img') {
          if (minimize) return const SizedBox.shrink();
          final src = element.attributes['src'];
          if (src != null && src.isNotEmpty) {
            return GestureDetector(
              onTap: () => zoomInImage(context, src),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Image.network(
                  src,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          }
        }
        // Handle iframes: hide in minimize mode
        if (element.localName == 'iframe' && minimize) {
          return const SizedBox.shrink();
        }
        // Handle spoiler tags
        if (element.localName == 'spoiler') {
          if (minimize) return const SizedBox.shrink();
          final name = element.attributes['name'] ?? 'Spoiler';
          final innerHtml = element.innerHtml;
          return _SpoilerWidget(
            name: name,
            content: innerHtml,
            color: color,
          );
        }
        return null;
      },
    );
  }

  /// Port of DailyAL's applyTransform — processes angle-bracket BBCode
  /// (brackets already converted from [] to <>) into valid HTML.
  String applyTransform(String text) {
    int index = 0;
    String transformedText = text;
    var nestedTagStack = <int>[];
    var replaceContent = <String, String>{};

    while (index < text.length) {
      for (String tag in validTags) {
        try {
          String st = "";
          if ((index + tag.length) < text.length) {
            st = text.substring(index, index + tag.length).toLowerCase();
          }
          String et = "";
          final closingTag = _getClosingTag(tag);
          if ((index + closingTag.length) <= text.length) {
            et = text
                .substring(index, index + closingTag.length)
                .toLowerCase();
          }
          if (st == tag) {
            nestedTagStack.add(index);
          }
          if (et == closingTag) {
            if (nestedTagStack.isEmpty) continue;
            int startIndex = nestedTagStack.removeLast();
            var tagContent = text.substring(startIndex, index);
            var tagHeader = tagContent.substring(0, tagContent.indexOf(">"));
            var newContent = "";
            var tagValue = "";
            if (tagHeader.contains("=")) {
              tagValue = tagContent.substring(
                  tagContent.indexOf("=") + 1, tagContent.indexOf(">"));
            }
            var tagBody = tagContent.substring(tagContent.indexOf(">") + 1);

            if (tag == "<color") {
              newContent = "<span style='color: $tagValue;'>$tagBody";
            } else if (tag == "<size") {
              var sizeValue = int.tryParse(tagValue);
              if (sizeValue != null && sizeValue >= 130) {
                newContent = "<span style='font-size: 130%;'>$tagBody";
              } else {
                newContent = "<span style='font-size: $tagValue%;'>$tagBody";
              }
            } else if (tag == "<list") {
              if (tagValue.isNotEmpty) {
                newContent = "<ol type='$tagValue'>$tagBody";
              } else {
                newContent = "<ul>$tagBody";
              }
              newContent = newContent
                  .replaceFirst("<*>", "<li>")
                  .replaceFirst("< * >", "<li>");
            } else if (tag == "<url") {
              newContent = "<a style='' href='$tagValue'>$tagBody";
            } else if (tag == "<img") {
              newContent =
                  "<img src='$tagBody' style='vertical-align: $tagValue;' />";
            } else if (tag == "<spoiler") {
              newContent =
                  "<spoiler ${tagValue.isEmpty ? '' : "name='$tagValue'"}>$tagBody";
            } else if (tag == "<center") {
              newContent = "<div style='text-align: center;'>$tagBody";
            } else if (tag == "<yt") {
              newContent = """
              <div style='text-align: center;'>
                <iframe height="315"
                src="http://www.youtube.com/embed/$tagBody?autoplay=1">
              </div>
              """;
            }

            replaceContent[tagContent] = newContent;

            if (nestedTagStack.isEmpty) {
              for (var tc in replaceContent.keys.toList().reversed) {
                transformedText =
                    transformedText.replaceAll(tc, replaceContent[tc]!);
              }
              replaceContent.clear();
            }
          }
        } catch (e) {
          debugPrint('BbcodeWidget transform error: $e');
        }
      }
      index++;
    }

    transformedText = _replaceBBTags(transformedText);
    return transformedText;
  }

  String _replaceBBTags(String text) {
    for (String tag in tagsToReplace.keys) {
      text = text.replaceAll(tag, tagsToReplace[tag]!);
      text = text.replaceAll(tag.toUpperCase(), tagsToReplace[tag]!);
    }
    return text;
  }

  static String _getClosingTag(String tag) {
    return "</${tag.substring(1)}>";
  }
}

/// Spoiler widget with reveal toggle.
class _SpoilerWidget extends StatefulWidget {
  final String name;
  final String content;
  final Color? color;

  const _SpoilerWidget({
    required this.name,
    required this.content,
    this.color,
  });

  @override
  State<_SpoilerWidget> createState() => _SpoilerWidgetState();
}

class _SpoilerWidgetState extends State<_SpoilerWidget> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _isRevealed = !_isRevealed),
          icon: Icon(
            _isRevealed ? Icons.visibility_off : Icons.visibility,
            size: 16,
          ),
          label: Text(
            _isRevealed ? 'Hide ${widget.name}' : 'Show ${widget.name}',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        if (_isRevealed)
          BbcodeWidget(
            body: widget.content,
            color: widget.color,
          ),
      ],
    );
  }
}
