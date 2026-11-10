import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/user/theme/theme_bloc.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Fades a picture into [color] from top ([start] alpha, 0-255) to bottom ([end]).
class FadingEffect extends CustomPainter {
  final Color color;
  final int start;
  final int end;

  FadingEffect({required this.color, required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: start / 255), color.withValues(alpha: end / 255)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  // Repaint when the theme changes the page colour (it used to keep the old one).
  @override
  bool shouldRepaint(covariant FadingEffect oldDelegate) =>
      oldDelegate.color != color || oldDelegate.start != start || oldDelegate.end != end;
}

/// A page background picture fading into the page colour.
///
/// Shown when the "background image" theme setting is on, or always with [forceBg] (pictures
/// that are the page's content, e.g. a character's portrait) or a local file. The picture is
/// decoded at the size it is painted, never at the file's full resolution.
class Background extends StatelessWidget {
  final BuildContext context;
  final String? url;
  final double? height;
  final double? width;
  final bool isNetworkImage;
  final bool showLocalFile;
  final bool forceBg;
  final Color? bgColor;

  static const String fallbackAsset = 'assets/images/fall.jpg';

  const Background({
    super.key,
    required this.context,
    this.url,
    this.height,
    this.showLocalFile = false,
    this.forceBg = false,
    this.bgColor,
    this.isNetworkImage = true,
    this.width = double.infinity,
  });

  /// The background setting, true when no [ThemeBloc] is above (tests, isolated previews).
  static bool _settingOn(BuildContext context) {
    try {
      return context.select<ThemeBloc, bool>((bloc) => bloc.state.showBackground);
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = bgColor ?? Theme.of(context).scaffoldBackgroundColor;
    final show = forceBg || showLocalFile || _settingOn(context);
    final screen = MediaQuery.sizeOf(context);
    final paintedHeight = height ?? screen.height / 1.9;
    final paintedWidth = width != null && width!.isFinite ? width! : screen.width;

    return Stack(
      children: [
        // Fills the space given to the background (as before), the picture sits on top.
        Container(color: color),
        if (show)
          SizedBox(
            width: width,
            height: paintedHeight,
            child: CustomPaint(
              foregroundPainter: FadingEffect(color: color, start: 200, end: 255),
              child: _picture(context, paintedWidth, paintedHeight),
            ),
          ),
      ],
    );
  }

  Widget _picture(BuildContext context, double w, double h) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final url = this.url;
    if (url != null && isNetworkImage && !showLocalFile) {
      return AppImage(url: url, width: w, height: h, errorAsset: fallbackAsset);
    }
    final ImageProvider source = showLocalFile && url != null
        ? FileImage(File(url))
        : AssetImage(url ?? fallbackAsset);
    return Image(
      image: SizedDecodeImage(
        source,
        width: (w * dpr).ceil(),
        height: (h * dpr).ceil(),
      ),
      width: w,
      height: h,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Image(
        image: SizedDecodeImage(
          const AssetImage(fallbackAsset),
          width: (w * dpr).ceil(),
          height: (h * dpr).ceil(),
        ),
        width: w,
        height: h,
        fit: BoxFit.cover,
      ),
    );
  }
}
