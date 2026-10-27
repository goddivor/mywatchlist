import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/accounts/account_selection.dart';
import 'package:mywatchlist/user/base_user.dart' as base;
import 'package:mywatchlist/user/user.dart' as legacy;

void main() {
  const mal = AccountType.myanimelist;
  const ani = AccountType.anilist;
  const kitsu = AccountType.kitsu;

  group('resolveSelection', () {
    test('keeps the current tracker while it is connected', () {
      expect(resolveSelection(current: ani, connected: [mal, ani], expired: []), ani);
    });

    test('keeps a tracker whose session died (the app asks to sign in again)', () {
      expect(resolveSelection(current: ani, connected: [mal], expired: [ani]), ani);
    });

    test('falls back to the first connected tracker, no picker', () {
      expect(resolveSelection(current: AccountType.none, connected: [ani, kitsu], expired: []), ani);
      expect(resolveSelection(current: kitsu, connected: [mal], expired: []), mal);
    });

    test('nothing connected means the sign-in screen', () {
      expect(resolveSelection(current: mal, connected: [], expired: []), AccountType.none);
      expect(resolveSelection(current: AccountType.none, connected: [], expired: [mal]), AccountType.none);
    });
  });

  group('autoSelectNewConnection', () {
    test('first sign in activates the new tracker', () {
      expect(autoSelectNewConnection(current: AccountType.none, before: [], connected: [kitsu]), kitsu);
    });

    test('never switches an active account behind the user back', () {
      expect(autoSelectNewConnection(current: mal, before: [mal], connected: [mal, ani]), isNull);
    });

    test('a tracker that was already connected is not a new connection', () {
      expect(autoSelectNewConnection(current: AccountType.none, before: [mal], connected: [mal]), isNull);
    });
  });

  test('one AuthStatus enum for the whole app', () {
    // Both libraries expose the same type: a status set through one compares with the other.
    const a = base.AuthStatus.AUTHENTICATED;
    const legacy.AuthStatus b = a;
    expect(a == b, isTrue);
  });
}
