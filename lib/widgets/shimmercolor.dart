import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

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
    return Shimmer.fromColors(
      baseColor: baseColor ?? colors.baseColor,
      highlightColor: highlightColor ?? colors.highlightColor,
      child: child,
    );
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
    final brightness = Theme.of(context).brightness;
    final isLight = brightness != Brightness.dark;
    return ShimmerColors(
      baseColor: isLight
          ? Colors.grey[200]!
          : Theme.of(context).scaffoldBackgroundColor,
      highlightColor: isLight
          ? Colors.grey[100]!
          : _lighten(Theme.of(context).scaffoldBackgroundColor),
    );
  }

  static Color _lighten(Color color, [int percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var p = percent / 100;
    return Color.fromARGB(
      color.a.toInt(),
      color.r.toInt() + ((255 - color.r.toInt()) * p).round(),
      color.g.toInt() + ((255 - color.g.toInt()) * p).round(),
      color.b.toInt() + ((255 - color.b.toInt()) * p).round(),
    );
  }
}

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

  Future<void> _loadImage() async {
    final completer = Completer<void>();
    final image = NetworkImage(imageUrl);
    final listener = ImageStreamListener((_, __) {
      completer.complete();
    }, onError: (dynamic error, stackTrace) {
      completer.completeError(error);
    });
    image.resolve(const ImageConfiguration()).addListener(listener);
    await completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadImage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: width,
              height: height,
              color: Colors.white,
            ),
          );
        } else if (snapshot.hasError) {
          return const Center(
            child: Text('Error loading image'),
          );
        } else {
          return Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
          );
        }
      },
    );
  }
}
