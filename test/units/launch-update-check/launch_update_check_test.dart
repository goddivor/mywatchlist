import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/updater/release_service.dart';
import 'package:mywatchlist/services/updater/update_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeReleases extends ReleaseService {
  int calls = 0;
  Object? error;
  ReleaseInfo? release = const ReleaseInfo(tag: '2026.11.0', url: 'https://example.test/r');

  @override
  Future<ReleaseInfo?> latest() async {
    calls++;
    if (error != null) throw error!;
    return release;
  }
}

void main() {
  late _FakeReleases fake;
  late DateTime clock;
  late SharedPreferences prefs;

  LaunchUpdateCheck build({bool enabled = true}) => LaunchUpdateCheck(
        releases: fake,
        currentVersion: '2026.10.1',
        enabled: enabled,
        now: () => clock,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fake = _FakeReleases();
    clock = DateTime(2026, 10, 28, 9);
  });

  test('announces a newer release', () async {
    final release = await build().run(prefs);
    expect(release?.tag, '2026.11.0');
  });

  test('asks GitHub once per day', () async {
    await build().run(prefs);
    clock = clock.add(const Duration(hours: 23));
    expect(await build().run(prefs), isNull);
    expect(fake.calls, 1);
    clock = clock.add(const Duration(hours: 2));
    expect(await build().run(prefs), isNotNull);
    expect(fake.calls, 2);
  });

  test('offers a release only once', () async {
    final check = build();
    final release = await check.run(prefs);
    await check.markNotified(prefs, release!.tag);
    clock = clock.add(const Duration(days: 2));
    expect(await build().run(prefs), isNull);
  });

  test('is silent when up to date, without release, offline or disabled', () async {
    fake.release = const ReleaseInfo(tag: '2026.10.1', url: 'u');
    expect(await build().run(prefs), isNull);
    clock = clock.add(const Duration(days: 2));
    fake.release = null;
    expect(await build().run(prefs), isNull);
    clock = clock.add(const Duration(days: 2));
    fake.error = Exception('offline');
    expect(await build().run(prefs), isNull);
    final calls = fake.calls;
    expect(await build(enabled: false).run(prefs), isNull);
    expect(fake.calls, calls);
  });

  test('a failed check is retried at the next launch', () async {
    fake.error = Exception('offline');
    await build().run(prefs);
    fake.error = null;
    expect(await build().run(prefs), isNotNull);
  });

  test('the dialog reads the prefetched release without a second request', () async {
    final release = (await build().run(prefs))!;
    final wrapped = LaunchUpdateCheck.prefetched(fake, release);
    expect(await wrapped.latest(), same(release));
    expect(fake.calls, 1);
    await wrapped.latest();
    expect(fake.calls, 2);
  });
}
