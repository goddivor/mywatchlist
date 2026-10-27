import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Shows [child] with the shimmer effect only while [showShimmer] is true.
class ShimmerConditionally extends StatelessWidget {
  final Widget child;
  final bool showShimmer;
  final Color? baseColor;
  final Color? highlightColor;

  // ignore: use_super_parameters
  const ShimmerConditionally({
    required this.showShimmer,
    required this.child,
    Key? key,
    this.baseColor,
    this.highlightColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (showShimmer) {
      return ShimmerColor(
        child,
        baseColor: baseColor,
        highlightColor: highlightColor,
      );
    } else {
      return child;
    }
  }
}

/// Loading placeholder: paints [child]'s shape with a moving highlight.
///
/// Every shimmer on screen is driven by ONE shared [ShimmerClock] and only repaints (no rebuild,
/// no per-widget AnimationController): a grid of 38 placeholders costs one ticker, not 38. The
/// clock stops when no shimmer is visible, and a shimmer inside a disabled [TickerMode] (an
/// off-screen tab, a route under another one) does not keep it running.
class ShimmerColor extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  const ShimmerColor(
    this.child, {
    super.key,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ShimmerColors.fromContext(context);
    return _SharedShimmer(
      clock: ShimmerClock.instance,
      animate: TickerMode.of(context),
      gradient: shimmerGradient(
        baseColor ?? colors.baseColor,
        highlightColor ?? colors.highlightColor,
      ),
      child: child,
    );
  }
}

/// The diagonal band used by the `shimmer` package, so the look does not change.
LinearGradient shimmerGradient(Color base, Color highlight) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.centerRight,
      colors: <Color>[base, base, highlight, base, base],
      stops: const <double>[0.0, 0.35, 0.5, 0.65, 1.0],
    );

/// One ticker for every shimmer of the app: [value] goes from 0 to 1 every [period].
///
/// It ticks only while at least one animating shimmer is attached.
class ShimmerClock extends ChangeNotifier implements ValueListenable<double> {
  ShimmerClock({this.period = const Duration(milliseconds: 1500)});

  static final ShimmerClock instance = ShimmerClock();

  final Duration period;
  Ticker? _ticker;
  double _value = 0;
  int _listeners = 0;

  @override
  double get value => _value;

  /// Whether the ticker is currently scheduling frames.
  bool get isTicking => _ticker?.isActive ?? false;

  /// Number of shimmers currently listening (for tests).
  @visibleForTesting
  int get listenerCount => _listeners;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners++;
    if (_listeners == 1) {
      (_ticker ??= Ticker(_onTick, debugLabel: 'ShimmerClock')).start();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listeners--;
    if (_listeners == 0) {
      _ticker?.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final periodUs = period.inMicroseconds;
    _value = (elapsed.inMicroseconds % periodUs) / periodUs;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

class _SharedShimmer extends SingleChildRenderObjectWidget {
  final ShimmerClock clock;
  final bool animate;
  final Gradient gradient;

  const _SharedShimmer({
    required this.clock,
    required this.animate,
    required this.gradient,
    super.child,
  });

  @override
  RenderSharedShimmer createRenderObject(BuildContext context) =>
      RenderSharedShimmer(clock: clock, animate: animate, gradient: gradient);

  @override
  void updateRenderObject(BuildContext context, RenderSharedShimmer renderObject) {
    renderObject
      ..clock = clock
      ..animate = animate
      ..gradient = gradient;
  }
}

/// Paints its child through a moving gradient mask; listens to the clock only while attached
/// and [animate] is true, and only marks itself for repaint on each tick.
class RenderSharedShimmer extends RenderProxyBox {
  RenderSharedShimmer({
    required ShimmerClock clock,
    required bool animate,
    required Gradient gradient,
  })  : _clock = clock,
        _animate = animate,
        _gradient = gradient;

  ShimmerClock _clock;
  bool _animate;
  Gradient _gradient;
  bool _listening = false;

  set clock(ShimmerClock value) {
    if (identical(value, _clock)) return;
    _unlisten();
    _clock = value;
    _syncListening();
    markNeedsPaint();
  }

  set animate(bool value) {
    if (value == _animate) return;
    _animate = value;
    _syncListening();
  }

  set gradient(Gradient value) {
    if (value == _gradient) return;
    _gradient = value;
    markNeedsPaint();
  }

  /// Whether this shimmer currently keeps the shared clock running.
  bool get isListening => _listening;

  void _syncListening() {
    if (attached && _animate) {
      if (!_listening) {
        _clock.addListener(markNeedsPaint);
        _listening = true;
      }
    } else {
      _unlisten();
    }
  }

  void _unlisten() {
    if (_listening) {
      _clock.removeListener(markNeedsPaint);
      _listening = false;
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _syncListening();
  }

  @override
  void detach() {
    _unlisten();
    super.detach();
  }

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      layer = null;
      return;
    }
    final width = child.size.width;
    final height = child.size.height;
    // Left to right: the band enters from the left edge and leaves by the right one.
    final dx = -width + 2 * width * _clock.value;
    final rect = Rect.fromLTWH(dx - width, 0, 3 * width, height);
    layer ??= ShaderMaskLayer();
    layer!
      ..shader = _gradient.createShader(rect)
      ..maskRect = offset & size
      ..blendMode = BlendMode.srcIn;
    context.pushLayer(layer!, super.paint, offset);
  }
}

class ShimmerColors {
  final Color baseColor;
  final Color highlightColor;

  ShimmerColors({
    required this.baseColor,
    required this.highlightColor,
  });

  factory ShimmerColors.fromContext(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness != Brightness.dark;
    return ShimmerColors(
      baseColor: isLight ? Colors.grey[200]! : theme.scaffoldBackgroundColor,
      highlightColor: isLight
          ? Colors.grey[100]!
          : _lighten(theme.scaffoldBackgroundColor),
    );
  }

  static Color _lighten(Color color, [int percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var p = percent / 100;
    return Color.fromARGB(
      (color.a * 255).round(),
      (color.r * 255).round() + ((255 - (color.r * 255).round()) * p).round(),
      (color.g * 255).round() + ((255 - (color.g * 255).round()) * p).round(),
      (color.b * 255).round() + ((255 - (color.b * 255).round()) * p).round(),
    );
  }
}

/// Network image with a shimmer while it loads, decoded at its displayed size.
class ShimmerImageLoader extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;

  const ShimmerImageLoader({
    super.key,
    required this.imageUrl,
    this.width = double.infinity,
    this.height = 200.0,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return AppImage(
      url: imageUrl,
      width: width,
      height: height,
      fit: fit,
      shimmerPlaceholder: true,
    );
  }
}
