import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/services/frames/avatar_frames.dart';

/// A MAL user's avatar ([child], [size] × [size]) with the frame that user wears, if any. The
/// frame is painted around the avatar, outside its box: the layout keeps the avatar's size.
class FramedAvatar extends StatefulWidget {
  final String? username;
  final double size;
  final Widget child;

  /// Where frames are read; tests give their own.
  final AvatarFrames? frames;

  const FramedAvatar({super.key, required this.username, required this.size, required this.child, this.frames});

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
    final side = size * frame.scale;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            left: (size - side) / 2 + frame.dx * size,
            top: (size - side) / 2 + frame.dy * size,
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
