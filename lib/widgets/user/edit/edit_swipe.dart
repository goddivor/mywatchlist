import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// What a vertical swipe on the edit sheet asks for.
enum EditSwipe { none, expand, collapse, dismiss }

/// Distance (logical pixels) or speed (px/s) that makes a drag a swipe.
const double editSwipeDistance = 40;
const double editSwipeSpeed = 500;

/// Decides what a finished vertical drag does (MoeList-like): up expands
/// "More options"; down collapses them, or closes the sheet when they are
/// already collapsed. [dy] is the total move, [velocity] the release speed;
/// both are negative upwards.
EditSwipe editSwipeFor({
  required double dy,
  required double velocity,
  required bool expanded,
}) {
  final up = dy <= -editSwipeDistance || velocity <= -editSwipeSpeed;
  final down = dy >= editSwipeDistance || velocity >= editSwipeSpeed;
  if (up && !down) return expanded ? EditSwipe.none : EditSwipe.expand;
  if (down && !up) return expanded ? EditSwipe.collapse : EditSwipe.dismiss;
  return EditSwipe.none;
}

/// Catches vertical swipes over the whole edit sheet, not only its handle.
///
/// When the sheet sits in a scroll view that can scroll (expanded options taller
/// than the screen), the drag scrolls it as usual; a pull down once at the top
/// then counts as a swipe down.
class EditSwipeArea extends StatefulWidget {
  const EditSwipeArea({
    super.key,
    required this.expanded,
    required this.onSwipe,
    required this.child,
  });

  final bool expanded;
  final ValueChanged<EditSwipe> onSwipe;
  final Widget child;

  @override
  State<EditSwipeArea> createState() => _EditSwipeAreaState();
}

class _EditSwipeAreaState extends State<EditSwipeArea> {
  double _dy = 0;
  ScrollPosition? _position;
  Drag? _drag;

  ScrollPosition? _scrollable() {
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null || !position.hasContentDimensions) return null;
    return position.maxScrollExtent > position.minScrollExtent ? position : null;
  }

  bool get _atTop =>
      _position == null || _position!.pixels <= _position!.minScrollExtent;

  void _start(DragStartDetails details) {
    _dy = 0;
    _position = _scrollable();
    _drag = _position?.drag(details, () => _drag = null);
  }

  void _update(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (_drag != null && !(_atTop && delta > 0 && _dy >= 0)) {
      _drag!.update(details);
      return;
    }
    _dy += delta;
  }

  void _end(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final scrolled = _drag != null;
    if (scrolled) {
      if (_dy > 0) {
        _drag!.cancel();
      } else {
        _drag!.end(details);
      }
    }
    final swipe = scrolled
        // While scrolling, only a pull at the top counts (as a swipe down).
        ? (_dy >= editSwipeDistance ? EditSwipe.collapse : EditSwipe.none)
        : editSwipeFor(dy: _dy, velocity: velocity, expanded: widget.expanded);
    _reset();
    if (swipe != EditSwipe.none) widget.onSwipe(swipe);
  }

  void _cancel() {
    _drag?.cancel();
    _reset();
  }

  void _reset() {
    _dy = 0;
    _drag = null;
    _position = null;
  }

  @override
  void dispose() {
    _drag?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragStart: _start,
      onVerticalDragUpdate: _update,
      onVerticalDragEnd: _end,
      onVerticalDragCancel: _cancel,
      child: widget.child,
    );
  }
}
