import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show text;
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';

/// Title row (name, optional trailing widget, "view all" arrow) above a
/// section body. The first section has no title row (it sits right under
/// the tab bar).
class DetailSectionFrame extends StatelessWidget {
  final DetailSection section;
  final bool isFirst;

  const DetailSectionFrame({
    super.key,
    required this.section,
    required this.isFirst,
  });

  static const double _pad = detailHorizPadding;

  @override
  Widget build(BuildContext context) {
    final onViewAll = section.onViewAll;
    final trailing = section.trailing;
    return Column(
      children: [
        if (!isFirst && !section.skipTitle)
          Padding(
            padding: const EdgeInsets.only(
                left: _pad + 10, top: 25, right: _pad + 10),
            child: Row(
              children: [
                text(section.title, fontSize: 22),
                if (onViewAll != null || trailing != null) ...[
                  const Spacer(),
                  if (trailing != null && onViewAll != null) ...[
                    trailing,
                    const SizedBox(width: 15),
                  ],
                  // Without an arrow, the trailing buttons take its place at the end of the row.
                  if (trailing != null && onViewAll == null)
                    Padding(
                        padding: const EdgeInsets.only(right: _pad),
                        child: trailing),
                  if (onViewAll != null)
                    Padding(
                      padding: const EdgeInsets.only(right: _pad),
                      child: PlainButton(
                        padding: const EdgeInsets.symmetric(horizontal: _pad),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        onPressed: () => onViewAll(context),
                        child: const Icon(Icons.arrow_forward),
                      ),
                    ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 20),
        section.child,
      ],
    );
  }
}
