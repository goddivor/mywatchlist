import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';


class SysonpsisWidget extends StatefulWidget {
  final String? synopsis;
  final List<Genre>? genres;
  final String? background;
  final String category;
  final double horizPadding;
  final int characterLimit;
  final bool expanded;

  const SysonpsisWidget({
    super.key,
    this.synopsis,
    this.genres,
    this.category = "anime",
    this.background,
    this.expanded = false,
    this.characterLimit = 300,
    this.horizPadding = 15.0,
  });

  @override
  // ignore: library_private_types_in_public_api
  _SysonpsisWidgetState createState() => _SysonpsisWidgetState();
}

class _SysonpsisWidgetState extends State<SysonpsisWidget>
    with AutomaticKeepAliveClientMixin {
  String? synopsis;
  bool expanded = false;
  bool showExpand = false;

  @override
  void initState() {
    super.initState();
    if (widget.synopsis != null) {
      synopsis = widget.synopsis;
      showExpand = (synopsis != null &&
          synopsis!.isNotEmpty &&
          synopsis!.length > widget.characterLimit);
      expanded = widget.expanded || !showExpand;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CustomPaint(
            foregroundPainter: FadingEffect(
              extend: 5,
              color: Theme.of(context).scaffoldBackgroundColor,
              start: expanded ? 50 : 0,
              end: expanded ? 50 : 255,
            ),
            child: Container(
              height: expanded ? null : 220,
              padding: EdgeInsets.fromLTRB(
                widget.horizPadding,
                0,
                widget.horizPadding,
                0,
              ),
              child: synopsisContent(),
            ),
          ),
        ),
        if (showExpand)
          Center(
            child: SizedBox(
              height: 40,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    expanded = !expanded;
                  });
                },
                padding: EdgeInsets.zero,
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 24,
                ),
              ),
            ),
          )
      ],
    );
  }

  Container synopsisContent() {
    // ignore: sized_box_for_whitespace
    return Container(
      width: double.infinity,
      child: (widget.synopsis == null)
          ? loadingText(context)
          : ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 10),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                genresWidget(widget.genres ?? [], widget.category, context),
                const SizedBox(height: 5),
                Text(
                  synopsis ?? "No synopsis available.",
                  textAlign: TextAlign.justify,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                      ),
                ),
                const SizedBox(height: 5),
                (widget.background == null || widget.background == "")
                    ? Container()
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            height: 10,
                          ),
                          Text(
                            Intl.message(
                              'Background',
                              name: 'Background',
                              desc: '',
                              args: [],
                            ),
                            textAlign: TextAlign.left,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 14,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.background ??
                                Intl.message(
                                  'None',
                                  name: 'None',
                                  desc: '',
                                  args: [],
                                ),
                            textAlign: TextAlign.justify,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 14,
                                ),
                          )
                        ],
                      ),
              ],
            ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class FadingEffect extends CustomPainter {
  final Color color;
  final int start;
  final int end;
  final int extend;

  FadingEffect({
    required this.color,
    required this.start,
    required this.end,
    this.extend = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(start / 255), color.withOpacity(end / 255)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height + extend));
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
