import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/cache/dub_info.dart';
import 'package:mywatchlist/widgets/common/dub_icon.dart';

import '../../helpers/pump_app.dart';

void main() {
  test('parseDubJson accepts numbers and numeric strings, ignores junk', () {
    final data = parseDubJson('{"dubbed":[1,"2","x"],"partial":[3]}');
    expect(data.dubbed, {1, 2});
    expect(data.partial, {3});
    expect(parseDubJson('not json').total, 0);
    expect(parseDubJson('[1,2]').total, 0);
  });

  test('confidence slug follows the minimum source count', () {
    expect(DubInfo.confidenceSlug(1), 'low');
    expect(DubInfo.confidenceSlug(2), 'normal');
    expect(DubInfo.confidenceSlug(3), 'high');
    expect(DubInfo.confidenceSlug(4), 'very-high');
  });

  test('a network failure with no cache ends in failed, then Retry recovers', () async {
    var online = false;
    final info = DubInfo(
      fetch: (_) async => online ? '{"dubbed":[7],"partial":[]}' : null,
      readCache: (key, {required allowStale}) async => null,
      writeCache: (_, __) async {},
      parse: (body) async => parseDubJson(body),
    );
    await info.ensureLoaded();
    expect(info.state, DubLoadState.failed);
    online = true;
    await info.ensureLoaded(force: true);
    expect(info.state, DubLoadState.ready);
    expect(info.data.dubbed, {7});
  });

  test('a stale cache is used when the network fails', () async {
    final info = DubInfo(
      fetch: (_) async => null,
      readCache: (key, {required allowStale}) async =>
          allowStale ? '{"dubbed":[5]}' : null,
      writeCache: (_, __) async {},
      parse: (body) async => parseDubJson(body),
    );
    await info.ensureLoaded();
    expect(info.state, DubLoadState.ready);
    expect(info.data.dubbed, {5});
  });

  testWidgets('badge builds nothing while the dub icon is disabled', (tester) async {
    await pumpInApp(tester, const DubStatusBadge(animeId: 1));
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('style glyphs clamp to the four styles', (tester) async {
    expect(DubIcons.clampStyle(9), 3);
    expect(DubIcons.clampStyle(-1), 0);
    await pumpInApp(
        tester, const DubGlyph(status: DubStatus.partial, style: 2, color: Colors.red));
    await tester.pump();
    expect(find.byType(Icon), findsOneWidget);
  });
}
