import 'package:flutter/material.dart';

/// Ease-out of the app's interface motion.
const Curve editEaseOut = Cubic(0.23, 1, 0.32, 1);

/// Horizontal strip of round number buttons (score 0-10, episode 1-N), the
/// selected one centred. Lazy (`ListView.builder` with a fixed extent), so a
/// thousand-episode show costs no more than a short one.
class NumberBar extends StatefulWidget {
  /// Values shown, in order.
  final int first;
  final int count;
  final int? selected;
  final bool busy;
  final ValueChanged<int> onSelected;

  /// Content of a button; defaults to the number.
  final Widget Function(BuildContext context, int value)? labelBuilder;
  final String Function(int value)? semanticLabel;

  const NumberBar({
    super.key,
    required this.first,
    required this.count,
    required this.selected,
    required this.onSelected,
    this.busy = false,
    this.labelBuilder,
    this.semanticLabel,
  });

  static const double itemExtent = 52;
  static const double height = 48;

  @override
  State<NumberBar> createState() => _NumberBarState();
}

const double _padding = 12;

class _NumberBarState extends State<NumberBar> {
  final ScrollController _controller = ScrollController();
  double _viewport = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _center(animate: false));
  }

  @override
  void didUpdateWidget(covariant NumberBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _center(animate: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _center({required bool animate}) {
    final selected = widget.selected;
    if (!mounted || selected == null || !_controller.hasClients) return;
    final index = (selected - widget.first).clamp(0, widget.count - 1);
    final position = _controller.position;
    final target = (_padding +
            index * NumberBar.itemExtent -
            (_viewport - NumberBar.itemExtent) / 2)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (animate) {
      _controller.animateTo(target,
          duration: const Duration(milliseconds: 220), curve: editEaseOut);
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: NumberBar.height,
      child: LayoutBuilder(builder: (context, constraints) {
        _viewport = constraints.maxWidth;
        return ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          itemExtent: NumberBar.itemExtent,
          padding: const EdgeInsets.symmetric(horizontal: _padding),
          itemCount: widget.count,
          itemBuilder: (context, index) {
            final value = widget.first + index;
            final isSelected = value == widget.selected;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Semantics(
                selected: isSelected,
                button: true,
                label: widget.semanticLabel?.call(value),
                excludeSemantics: widget.semanticLabel != null,
                child: Material(
                  color: isSelected
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.busy ? null : () => widget.onSelected(value),
                    child: Center(
                      child: isSelected && widget.busy
                          ? SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : DefaultTextStyle.merge(
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? scheme.onPrimary
                                    : scheme.onSurface,
                              ),
                              child: IconTheme.merge(
                                data: IconThemeData(
                                  size: 18,
                                  color: isSelected
                                      ? scheme.onPrimary
                                      : scheme.onSurfaceVariant,
                                ),
                                child:
                                    widget.labelBuilder?.call(context, value) ??
                                        Text('$value'),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
