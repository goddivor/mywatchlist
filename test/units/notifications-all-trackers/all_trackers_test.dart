import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/notifications/notification_service.dart';
import 'package:mywatchlist/user/preferences/notification_preferences.dart';

AiringCandidate _c(int id, String status) => AiringCandidate(malId: id, title: 'T$id', status: status);

void main() {
  test('every connected tracker feeds the reminders unless its switch is off (#351)', () {
    bool connected(AccountType t) => t != AccountType.kitsu;
    expect(NotificationService.feedingTrackers(connected, const NotificationPreferences()),
        [AccountType.myanimelist, AccountType.anilist, AccountType.simkl]);
    final off = const NotificationPreferences().withAiring('anilist', false);
    expect(NotificationService.feedingTrackers(connected, off), [AccountType.myanimelist, AccountType.simkl]);
    expect(off.withAiring('anilist', true).airingFrom('anilist'), isTrue);
  });

  test('a title on several lists notifies once, as Watching when one list watches it', () {
    final merged = NotificationService.mergeCandidates([
      [_c(1, 'plan_to_watch'), _c(2, 'watching')],
      [_c(1, 'watching'), _c(3, 'plan_to_watch')],
    ]);
    expect(merged.map((c) => c.malId).toSet(), {1, 2, 3});
    expect(merged.firstWhere((c) => c.malId == 1).status, 'watching');
  });

  test('the tracker switches survive a JSON round trip', () {
    final p = const NotificationPreferences().withAiring('kitsu', false).withAiring('simkl', false);
    final back = NotificationPreferences.fromJson(p.toJson());
    expect(back, p);
    expect(back.airingFrom('kitsu'), isFalse);
    expect(back.airingFrom('myanimelist'), isTrue);
  });
}
