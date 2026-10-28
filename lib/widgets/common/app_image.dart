import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

/// Decoded sizes are rounded up to a multiple of this many physical pixels, so the same picture
/// shown at 110 and 112 logical pixels shares one decoded copy in the image cache.
const int _decodeStep = 32;

/// The app's network image: disk cache of [CachedNetworkImageProvider], decoded at the size it is
/// displayed (logical size × device pixel ratio) instead of the file's full resolution, no fade
/// by default and a flat placeholder (see docs/PERFORMANCE.md).
///
/// Give [width] and [height] when the slot has a fixed size; otherwise the size is read from the
/// layout constraints. Use it for every network picture in lists, grids and headers.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.fadeInDuration = Duration.zero,
    this.placeholder,
    this.shimmerPlaceholder = false,
    this.placeholderColor,
    this.errorWidget,
    this.errorAsset,
    this.imageBuilder,
    this.headers,
    this.maxDiskWidth,
    this.semanticLabel,
  });

  /// Image URL; null or empty shows the error widget.
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  /// Clips the image, its placeholder and its error widget.
  final BorderRadius? borderRadius;

  /// Fade from the placeholder once the image is ready. Zero (the default, as DailyAL) costs
  /// nothing; keep any other value short (≤ 150 ms) and off repeated list items.
  final Duration fadeInDuration;

  /// Shown until the first frame is decoded. Defaults to a flat [placeholderColor] box, or a
  /// shimmer when [shimmerPlaceholder] is true.
  final WidgetBuilder? placeholder;
  final bool shimmerPlaceholder;
  final Color? placeholderColor;

  /// Shown when the URL is missing or the download fails. Defaults to [errorAsset] when given,
  /// else the placeholder box.
  final WidgetBuilder? errorWidget;
  final String? errorAsset;

  /// Builds the loaded image from its (already decoded) provider, e.g. into an `Ink` decoration
  /// so an `InkWell` ripple stays visible over it.
  final Widget Function(BuildContext context, ImageProvider provider)? imageBuilder;

  final Map<String, String>? headers;

  /// Also stores a resized copy on disk (flutter_cache_manager re-encodes it as PNG on first
  /// load, which costs CPU while scrolling): only for big pictures shown small and often.
  final int? maxDiskWidth;
  final String? semanticLabel;

  /// The provider [AppImage] uses: cached on disk, decoded for a [logicalWidth] × [logicalHeight]
  /// slot at [devicePixelRatio]. Use it where a provider is needed (DecorationImage, PhotoView).
  static ImageProvider provider(
    String url, {
    double? logicalWidth,
    double? logicalHeight,
    double devicePixelRatio = 1.0,
    BoxFit fit = BoxFit.cover,
    Map<String, String>? headers,
    int? maxDiskWidth,
  }) {
    final source = CachedNetworkImageProvider(
      url,
      headers: headers,
      maxWidth: maxDiskWidth,
    );
    final targetWidth = _physical(logicalWidth, devicePixelRatio);
    final targetHeight = _physical(logicalHeight, devicePixelRatio);
    if (fit == BoxFit.none || (targetWidth == null && targetHeight == null)) {
      return source;
    }
    return SizedDecodeImage(
      source,
      width: targetWidth,
      height: targetHeight,
      cover: fit != BoxFit.contain && fit != BoxFit.scaleDown,
    );
  }

  static int? _physical(double? logical, double dpr) {
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    final px = (logical * dpr).ceil();
    return ((px + _decodeStep - 1) ~/ _decodeStep) * _decodeStep;
  }

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final Widget content;
    if (url == null || url.isEmpty) {
      content = _sized(_buildError(context, width, height));
    } else if (_finite(width) || _finite(height)) {
      content = _buildImage(context, url, _finiteOrNull(width), _finiteOrNull(height));
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) => _buildImage(
          context,
          url,
          constraints.hasBoundedWidth ? constraints.maxWidth : null,
          constraints.hasBoundedHeight ? constraints.maxHeight : null,
        ),
      );
    }
    final radius = borderRadius;
    if (radius == null) return content;
    return ClipRRect(borderRadius: radius, child: content);
  }

  static bool _finite(double? v) => v != null && v.isFinite;
  static double? _finiteOrNull(double? v) => _finite(v) ? v : null;

  Widget _sized(Widget child) => SizedBox(width: width, height: height, child: child);

  Widget _buildImage(BuildContext context, String url, double? slotWidth, double? slotHeight) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final image = provider(
      url,
      logicalWidth: slotWidth,
      logicalHeight: slotHeight,
      devicePixelRatio: dpr,
      fit: fit,
      headers: headers,
      maxDiskWidth: maxDiskWidth,
    );
    return Image(
      image: image,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame == null && !wasSynchronouslyLoaded) {
          return _sized(_buildPlaceholder(context));
        }
        final loaded = imageBuilder != null ? _sized(imageBuilder!(context, image)) : child;
        if (wasSynchronouslyLoaded || fadeInDuration == Duration.zero) return loaded;
        return _FadeIn(duration: fadeInDuration, child: loaded);
      },
      errorBuilder: (context, error, stackTrace) =>
          _sized(_buildError(context, slotWidth, slotHeight)),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final custom = placeholder;
    if (custom != null) return custom(context);
    if (shimmerPlaceholder) {
      return ShimmerColor(ColoredBox(
          color: AppColors.of(context).shimmerBase, child: const SizedBox.expand()));
    }
    return ColoredBox(
      color: placeholderColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const SizedBox.expand(),
    );
  }

  Widget _buildError(BuildContext context, double? slotWidth, double? slotHeight) {
    final custom = errorWidget;
    if (custom != null) return custom(context);
    final asset = errorAsset;
    if (asset != null) {
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
      final assetImage = ResizeImage.resizeIfNeeded(
        _physical(slotWidth, dpr),
        null,
        AssetImage(asset),
      );
      return Image(image: assetImage, fit: fit, alignment: alignment);
    }
    return _buildPlaceholder(context);
  }
}

class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)..forward();
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: const Cubic(0.23, 1, 0.32, 1));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _opacity, child: widget.child);
}

/// Decodes [imageProvider] no larger than needed to paint a [width] × [height] (physical
/// pixels) slot, keeping the aspect ratio and never upscaling.
///
/// With [cover] the decoded picture still covers the whole slot (BoxFit.cover and friends);
/// otherwise it fits inside it (BoxFit.contain). Flutter's [ResizeImage] cannot do "cover"
/// without knowing the file's size, which is only known at decode time: this provider decides
/// there, through the decoder's target size callback.
@immutable
class SizedDecodeImage extends ImageProvider<SizedDecodeKey> {
  const SizedDecodeImage(
    this.imageProvider, {
    this.width,
    this.height,
    this.cover = true,
  }) : assert(width != null || height != null);

  final ImageProvider imageProvider;
  final int? width;
  final int? height;
  final bool cover;

  /// The decoded size for an [intrinsicWidth] × [intrinsicHeight] file (pure, for tests).
  static ui.TargetImageSize targetSize(
    int intrinsicWidth,
    int intrinsicHeight, {
    int? width,
    int? height,
    bool cover = true,
  }) {
    if (intrinsicWidth <= 0 || intrinsicHeight <= 0) return const ui.TargetImageSize();
    final scales = <double>[
      if (width != null) width / intrinsicWidth,
      if (height != null) height / intrinsicHeight,
    ];
    if (scales.isEmpty) return const ui.TargetImageSize();
    final scale = cover ? scales.reduce(math.max) : scales.reduce(math.min);
    if (scale >= 1) return const ui.TargetImageSize();
    return ui.TargetImageSize(
      width: math.max(1, (intrinsicWidth * scale).ceil()),
      height: math.max(1, (intrinsicHeight * scale).ceil()),
    );
  }

  @override
  Future<SizedDecodeKey> obtainKey(ImageConfiguration configuration) {
    final inner = imageProvider.obtainKey(configuration);
    SizedDecodeKey wrap(Object key) => SizedDecodeKey._(key, width, height, cover);
    // Keep the synchronous path synchronous: a cached picture must paint in the same frame.
    if (inner is SynchronousFuture<Object>) {
      late final Object key;
      inner.then((value) => key = value);
      return SynchronousFuture<SizedDecodeKey>(wrap(key));
    }
    return inner.then(wrap);
  }

  @override
  ImageStreamCompleter loadImage(SizedDecodeKey key, ImageDecoderCallback decode) {
    Future<ui.Codec> decodeSized(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSizeCallback? getTargetSize,
    }) {
      return decode(
        buffer,
        getTargetSize: (int intrinsicWidth, int intrinsicHeight) => targetSize(
          intrinsicWidth,
          intrinsicHeight,
          width: width,
          height: height,
          cover: cover,
        ),
      );
    }

    // ignore: invalid_use_of_protected_member
    return imageProvider.loadImage(key.providerKey, decodeSized);
  }

  @override
  bool operator ==(Object other) =>
      other is SizedDecodeImage &&
      other.imageProvider == imageProvider &&
      other.width == width &&
      other.height == height &&
      other.cover == cover;

  @override
  int get hashCode => Object.hash(imageProvider, width, height, cover);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'SizedDecodeImage')}($imageProvider, $width×$height, '
      '${cover ? 'cover' : 'contain'})';
}

/// Image cache key of [SizedDecodeImage]: the source key plus the target slot.
@immutable
class SizedDecodeKey {
  const SizedDecodeKey._(this.providerKey, this.width, this.height, this.cover);

  final Object providerKey;
  final int? width;
  final int? height;
  final bool cover;

  @override
  bool operator ==(Object other) =>
      other is SizedDecodeKey &&
      other.providerKey == providerKey &&
      other.width == width &&
      other.height == height &&
      other.cover == cover;

  @override
  int get hashCode => Object.hash(providerKey, width, height, cover);
}
