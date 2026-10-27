import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// The longest side, in pixels, the captured graph may have. A big franchise at a fixed high
/// pixel ratio would ask for an image of hundreds of megabytes; this bounds it.
const double kGraphShareMaxSide = 4096;

/// The pixel ratio to capture a [width] x [height] graph at: sharp on a small graph (up to 3x),
/// bounded by [kGraphShareMaxSide] on a big one, never below 0.25.
double graphCaptureRatio(double width, double height) {
  final longest = math.max(width, height);
  if (longest <= 0) return 1;
  return (kGraphShareMaxSide / longest).clamp(0.25, 3.0);
}

/// Height of the branding strip under a graph that is [graphHeight] pixels tall.
double graphFooterHeight(int graphHeight) =>
    (graphHeight * 0.12).clamp(120.0, 360.0);

/// Draws [graph] on a [background] sheet with a branding strip under it (the app [logo], when
/// given, and the [brand] text), and returns the PNG bytes.
Future<Uint8List?> composeGraphPng({
  required ui.Image graph,
  required Color background,
  required Color footerColor,
  required Color footerTextColor,
  required String brand,
  ui.Image? logo,
}) async {
  final width = graph.width;
  final footer = graphFooterHeight(graph.height);
  final height = graph.height + footer.round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
      recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

  canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), graph.height.toDouble()),
      Paint()..color = background);
  canvas.drawImage(
      graph, Offset.zero, Paint()..filterQuality = FilterQuality.high);

  final footerTop = graph.height.toDouble();
  canvas.drawRect(Rect.fromLTWH(0, footerTop, width.toDouble(), footer),
      Paint()..color = footerColor);

  final pad = footer * 0.3;
  var textX = pad;
  if (logo != null) {
    final size = footer * 0.6;
    final rect =
        Rect.fromLTWH(pad, footerTop + (footer - size) / 2, size, size);
    paintImage(
        canvas: canvas,
        rect: rect,
        image: logo,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high);
    textX = pad + size + pad * 0.7;
  }
  final painter = TextPainter(
    text: TextSpan(
      text: brand,
      style: TextStyle(
          color: footerTextColor,
          fontSize: footer * 0.28,
          fontWeight: FontWeight.w700),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: math.max(1, width - textX - pad));
  painter.paint(
      canvas, Offset(textX, footerTop + (footer - painter.height) / 2));
  painter.dispose();

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}

/// Captures the graph under [boundary], brands it, writes it to a temporary file and opens the
/// share sheet. Returns false when no image could be made.
///
/// [logoAsset] is the asset path of the app logo drawn in the strip.
Future<bool> shareGraphImage({
  required RenderRepaintBoundary boundary,
  required String fileStem,
  required Color background,
  required Color footerColor,
  required Color footerTextColor,
  required String brand,
  String? logoAsset,
}) async {
  ui.Image? captured;
  ui.Image? logo;
  try {
    final size = boundary.size;
    captured = await boundary.toImage(
        pixelRatio: graphCaptureRatio(size.width, size.height));
    if (logoAsset != null) {
      try {
        final bytes = await rootBundle.load(logoAsset);
        final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List(),
            targetWidth: 256);
        logo = (await codec.getNextFrame()).image;
        codec.dispose();
      } catch (e) {
        debugPrint('Graph share: logo not loaded: $e');
      }
    }
    final png = await composeGraphPng(
      graph: captured,
      background: background,
      footerColor: footerColor,
      footerTextColor: footerTextColor,
      brand: brand,
      logo: logo,
    );
    if (png == null) return false;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${safeFileStem(fileStem)}.png');
    await file.writeAsBytes(png, flush: true);
    await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')]);
    return true;
  } catch (e) {
    debugPrint('Graph share failed: $e');
    return false;
  } finally {
    captured?.dispose();
    logo?.dispose();
  }
}

/// [value] reduced to letters, digits and underscores, so it is safe as a file name.
String safeFileStem(String value) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (cleaned.isEmpty) return 'anime_graph';
  return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
}
