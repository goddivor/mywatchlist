import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/services/frames/avatar_frames.dart';

/// A MAL user's avatar ([child], [size] × [size]) with the frame that user wears, if any. The
/// frame is painted around the avatar, outside its box: the layout keeps the avatar's size.
/// With [fitInside], the frame keeps the avatar's size instead and the picture shrinks into it
/// (small slots such as the app bar and the sidebar, where an overflowing frame is too big).
class FramedAvatar extends StatefulWidget {
  final String? username;
  final double size;
  final Widget child;

  /// Shown instead of [child] while a frame is worn: the avatar without its own border, which
  /// the frame replaces (a border under the frame reads as a stray ring and shrinks the picture).
  final Widget? framedChild;

  final bool fitInside;

  /// Where frames are read; tests give their own.
  final AvatarFrames? frames;

  const FramedAvatar({
    super.key,
    required this.username,
    required this.size,
    required this.child,
    this.framedChild,
    this.fitInside = false,
    this.frames,
  });

  @override
  State<FramedAvatar> createState() => _FramedAvatarState();
}

class _FramedAvatarState extends State<FramedAvatar> {
  AvatarFrames get _frames => widget.frames ?? AvatarFrames.instance;
  AvatarFrame? _frame;

  @override
  void initState() {
    super.initState();
    _frames.addListener(_onChanged);
    _load();
  }

  @override
  void didUpdateWidget(FramedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frames != widget.frames) {
      (oldWidget.frames ?? AvatarFrames.instance).removeListener(_onChanged);
      _frames.addListener(_onChanged);
    }
    if (oldWidget.username != widget.username || oldWidget.frames != widget.frames) _load();
  }

  @override
  void dispose() {
    _frames.removeListener(_onChanged);
    super.dispose();
  }

  void _load() {
    final name = widget.username;
    if (name == null || name.isEmpty) {
      _frame = null;
      return;
    }
    _frame = _frames.cached(name);
    if (_frames.isKnown(name)) return;
    _frames.frameOf(name).then((frame) {
      if (mounted && widget.username == name && frame != _frame) setState(() => _frame = frame);
    });
  }

  void _onChanged() {
    final name = widget.username;
    if (name == null) return;
    final frame = _frames.cached(name);
    if (frame != _frame && mounted) setState(() => _frame = frame);
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    if (frame == null) return widget.child;
    final size = widget.size;
    // Frame box and avatar box, in this widget's coordinates.
    final side = widget.fitInside ? size : size * frame.scale;
    final avatar = widget.fitInside ? size / frame.scale : size;
    final avatarLeft = widget.fitInside ? (size - avatar) / 2 - frame.dx * avatar : 0.0;
    final avatarTop = widget.fitInside ? (size - avatar) / 2 - frame.dy * avatar : 0.0;
    final picture = widget.framedChild ?? widget.child;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: avatarLeft,
            top: avatarTop,
            width: avatar,
            height: avatar,
            child: widget.fitInside
                ? FittedBox(child: SizedBox(width: size, height: size, child: picture))
                : picture,
          ),
          Positioned(
            left: avatarLeft + (avatar - side) / 2 + frame.dx * avatar,
            top: avatarTop + (avatar - side) / 2 + frame.dy * avatar,
            width: side,
            height: side,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Image(
                  key: ValueKey(frame.imageUrl),
                  image: CachedNetworkImageProvider(frame.imageUrl),
                  width: side,
                  height: side,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
