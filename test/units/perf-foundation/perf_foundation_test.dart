import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

import '../../helpers/pump_app.dart';

Widget _shimmerGrid(int count) => Wrap(
      children: [
        for (var i = 0; i < count; i++)
          const ShimmerColor(SizedBox(width: 20, height: 20, child: ColoredBox(color: Colors.white))),
      ],
    );

void main() {
  group('SizedDecodeImage.targetSize', () {
    test('cover keeps the aspect ratio and still covers the slot', () {
      // 1000×500 landscape file in a 200×200 slot: height is the limiting side.
      final size = SizedDecodeImage.targetSize(1000, 500, width: 200, height: 200);
      expect(size.width, 400);
      expect(size.height, 200);
    });

    test('contain fits inside the slot', () {
      final size =
          SizedDecodeImage.targetSize(1000, 500, width: 200, height: 200, cover: false);
      expect(size.width, 200);
      expect(size.height, 100);
    });

    test('never upscales a file smaller than the slot', () {
      final size = SizedDecodeImage.targetSize(100, 150, width: 300, height: 450);
      expect(size.width, isNull);
      expect(size.height, isNull);
    });

    test('one known side is enough', () {
      final size = SizedDecodeImage.targetSize(800, 1200, width: 200);
      expect(size.width, 200);
      expect(size.height, 300);
    });
  });

  group('AppImage.provider', () {
    test('decodes at logical size × device pixel ratio, rounded up to 32 px', () {
      final provider = AppImage.provider(
        'https://cdn.myanimelist.net/images/anime/1/1.jpg',
        logicalWidth: 110,
        logicalHeight: 160,
        devicePixelRatio: 2.75,
      ) as SizedDecodeImage;
      // 110 × 2.75 = 302.5 -> 303 -> 320; 160 × 2.75 = 440 -> 448.
      expect(provider.width, 320);
      expect(provider.height, 448);
      expect(provider.cover, isTrue);
      expect(provider.imageProvider, isA<CachedNetworkImageProvider>());
    });

    test('contain and scaleDown fit inside the slot', () {
      final provider = AppImage.provider('https://x/y.jpg',
          logicalWidth: 100, fit: BoxFit.contain) as SizedDecodeImage;
      expect(provider.cover, isFalse);
    });

    test('without any size it falls back to the cached provider', () {
      expect(AppImage.provider('https://x/y.jpg'), isA<CachedNetworkImageProvider>());
      expect(
        AppImage.provider('https://x/y.jpg', logicalWidth: 100, fit: BoxFit.none),
        isA<CachedNetworkImageProvider>(),
      );
    });

    test('same slot gives equal providers (one decoded copy in the image cache)', () {
      final a = AppImage.provider('https://x/y.jpg', logicalWidth: 110, devicePixelRatio: 2);
      final b = AppImage.provider('https://x/y.jpg', logicalWidth: 112, devicePixelRatio: 2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('shared shimmer ticker', () {
    testWidgets('38 shimmers run on one ticker and stop when gone', (tester) async {
      final clock = ShimmerClock.instance;
      await pumpInApp(tester, _shimmerGrid(38));
      expect(clock.listenerCount, 38);
      expect(clock.isTicking, isTrue);
      expect(SchedulerBinding.instance.transientCallbackCount, 1);

      final before = clock.value;
      await tester.pump(const Duration(milliseconds: 300));
      expect(clock.value, isNot(before));

      await pumpInApp(tester, const SizedBox());
      expect(clock.listenerCount, 0);
      expect(clock.isTicking, isFalse);
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('a shimmer in a disabled TickerMode does not keep the clock running',
        (tester) async {
      await pumpInApp(tester, TickerMode(enabled: false, child: _shimmerGrid(5)));
      expect(ShimmerClock.instance.listenerCount, 0);
      expect(ShimmerClock.instance.isTicking, isFalse);

      await pumpInApp(tester, TickerMode(enabled: true, child: _shimmerGrid(5)));
      expect(ShimmerClock.instance.listenerCount, 5);
      await pumpInApp(tester, const SizedBox());
    });
  });

  group('widgets', () {
    testWidgets('AppImage without URL shows the flat placeholder, offline', (tester) async {
      await pumpInApp(tester, const AppImage(url: null, width: 50, height: 70));
      expect(find.byType(ColoredBox), findsWidgets);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('AvatarWidget has no blurred shadow', (tester) async {
      await pumpInApp(tester, const AvatarWidget(isNetworkImage: false));
      final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      for (final box in boxes) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration) {
          expect(decoration.boxShadow, anyOf(isNull, isEmpty));
        }
      }
    });
  });
}
