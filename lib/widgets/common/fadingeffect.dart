import 'package:flutter/cupertino.dart';

class FadingEffect extends CustomPainter {
  final Color color;
  int start, end;
  double widthOffset, heightOffset;
  final double extend;
  FadingEffect(
      {required this.color,
      this.widthOffset = 0,
      this.heightOffset = 0,
      this.start = 200,
      this.end = 255,
      this.extend = 10});
  @override
  void paint(Canvas canvas, Size size) {
    final red = (color.r * 255.0).round() & 0xff;
    final green = (color.g * 255.0).round() & 0xff;
    final blue = (color.b * 255.0).round() & 0xff;
    Rect rect = Rect.fromPoints(Offset(widthOffset, heightOffset),
        Offset(size.width, size.height + extend));
    LinearGradient lg = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromARGB(start, red, green, blue),
          Color.fromARGB(end, red, green, blue)
        ]);
    Paint paint = Paint()..shader = lg.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  // ignore: avoid_renaming_method_parameters
  bool shouldRepaint(FadingEffect linePainter) => false;
}
