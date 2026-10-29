import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

/// Side margin of the title page (DailyAL's 15 dp, titles indented by 10 more).
const double kitsuPagePadding = 15;

/// A section title (22 sp as DailyAL) with an arrow to the full list when [onViewAll] is given.
class KitsuSectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const KitsuSectionTitle(this.title, {super.key, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final view = onViewAll;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(kitsuPagePadding + 10, 25, kitsuPagePadding, view == null ? 14 : 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22)),
          ),
          if (view != null)
            IconButton(
              tooltip: S.current.Kmp_View_All,
              onPressed: view,
              icon: const Icon(Icons.arrow_forward),
            ),
        ],
      ),
    );
  }
}

/// A section: its title row then its body.
class KitsuSection extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  final Widget child;

  const KitsuSection({super.key, required this.title, required this.child, this.onViewAll});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [KitsuSectionTitle(title, onViewAll: onViewAll), child],
      );
}

/// A horizontal row of cards, built lazily.
class KitsuStrip extends StatelessWidget {
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double spacing;

  const KitsuStrip({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: kitsuPagePadding),
          itemCount: itemCount,
          separatorBuilder: (_, __) => SizedBox(width: spacing),
          itemBuilder: itemBuilder,
        ),
      );
}

/// Body text folded to [maxLines] with Show more / Show less.
class KitsuExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;

  const KitsuExpandableText(this.text, {super.key, this.maxLines = 5, this.style});

  @override
  State<KitsuExpandableText> createState() => _KitsuExpandableTextState();
}

class _KitsuExpandableTextState extends State<KitsuExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? Theme.of(context).textTheme.bodyMedium;
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: widget.maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: style,
            maxLines: _open ? null : widget.maxLines,
            overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (overflows || _open)
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () => setState(() => _open = !_open),
              child: Text(_open ? S.current.Kmp_Show_Less : S.current.Kmp_Show_More),
            ),
        ],
      );
    });
  }
}

/// Wrapped tonal chips; tappable when [onTap] is given.
class KitsuChips extends StatelessWidget {
  final List<String> labels;
  final void Function(int index)? onTap;

  const KitsuChips(this.labels, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(color: scheme.onSecondaryContainer, fontSize: 13);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < labels.length; i++)
          onTap == null
              ? Chip(
                  label: Text(labels[i]),
                  labelStyle: style,
                  backgroundColor: scheme.secondaryContainer,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                )
              : ActionChip(
                  label: Text(labels[i]),
                  labelStyle: style,
                  backgroundColor: scheme.secondaryContainer,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onTap!(i),
                ),
      ],
    );
  }
}

/// One label and value line of the Information section.
class KitsuInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const KitsuInfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(kitsuPagePadding + 10, 5, kitsuPagePadding + 10, 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// A grey block standing for a section that is still loading.
class KitsuBlockSkeleton extends StatelessWidget {
  final double height;

  const KitsuBlockSkeleton({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kitsuPagePadding, vertical: 12),
      child: ShimmerColor(
        DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: SizedBox(height: height, width: double.infinity),
        ),
      ),
    );
  }
}
