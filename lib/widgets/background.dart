// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FadingEffect extends CustomPainter {
  final Color color;
  final int start;
  final int end;

  FadingEffect({required this.color, required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(start / 255), color.withOpacity(end / 255)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class Background extends StatelessWidget {
  final BuildContext context;
  final String? url;
  final double? height;
  final double? width;
  final bool isNetworkImage;
  final bool showLocalFile;
  final bool forceBg;
  final Color? bgColor;

  const Background({super.key, 
    required this.context,
    this.url,
    this.height,
    this.showLocalFile = false,
    this.forceBg = false,
    this.bgColor,
    this.isNetworkImage = true,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: bgColor ?? Theme.of(context).scaffoldBackgroundColor,
        ),
        SizedBox(
          width: width,
          height: showLocalFile
              ? null
              : (height ?? MediaQuery.of(context).size.height / 1.9),
          child: CustomPaint(
            foregroundPainter: FadingEffect(
              color: bgColor ?? Theme.of(context).scaffoldBackgroundColor,
              start: 200,
              end: 255,
            ),
            child: showLocalFile
                ? Image.file(
                    File(url!),
                    fit: BoxFit.cover,
                  )
                : url == null || !isNetworkImage
                    ? Image.asset(
                        url ?? "assets/images/fall.jpg",
                        fit: BoxFit.cover,
                      )
                    : CachedNetworkImage(
                        imageUrl: url!,
                        fit: BoxFit.cover,
                      ),
          ),
        )
      ],
    );
  }
}
