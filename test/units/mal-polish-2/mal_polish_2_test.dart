import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/screens/manage_accounts_page.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/services/auth/mal_auth_v2.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Settings > Accounts opens the manage accounts page', () {
    expect(AppRoutes.settingsPageFor(SettingsSection.accounts), isA<ManageAccountsPage>());
  });

  group('Supporter badge of other users', () {
    test('the profile page flag reaches the merged profile', () {
      final data = UserProfileRepository.merge('kuro', jikan: {'is_supporter': true});
      expect(data.isSupporter, isTrue);
    });

    test('no flag, no badge', () {
      expect(UserProfileRepository.merge('kuro', jikan: {}).isSupporter, isFalse);
      expect(UserProfileRepository.merge('kuro').isSupporter, isFalse);
    });
  });

  group('a MAL sign in that does not finish', () {
    final user = UserMalV2.instance;

    setUp(() {
      SharedPreferences.setMockInitialValues({'mal_code_challenge': 'verifier'});
      user.authResponse = AuthResponse(accessToken: 'old', refreshToken: 'r');
      user.status = AuthStatus.AUTHENTICATED;
    });

    tearDown(() {
      user.authResponse = null;
      user.status = AuthStatus.UNAUTHENTICATED;
    });

    test('a refused token exchange keeps the signed-in account signed in', () async {
      final auth = MalAuthV2(
        httpClient: MockClient((_) async => http.Response(jsonEncode({'error': 'x'}), 400)),
      );
      // The redirect comes back while the second sign in is running.
      user.setStatus(AuthStatus.INPROGRESS);
      final ok = await auth.checkIfSignIn(Uri.parse('mywatchlist://callback?code=abc'));
      expect(ok, isFalse);
      expect(user.getStatus(), AuthStatus.AUTHENTICATED);
      expect(user.accessToken, 'old');
    });

    test('a network failure keeps it too', () async {
      final auth = MalAuthV2(httpClient: MockClient((_) async => throw http.ClientException('down')));
      user.setStatus(AuthStatus.INPROGRESS);
      await auth.checkIfSignIn(Uri.parse('mywatchlist://callback?code=abc'));
      expect(user.getStatus(), AuthStatus.AUTHENTICATED);
    });

    test('a sign in the platform refuses (cancel) keeps the account signed in', () async {
      final auth = MalAuthV2(httpClient: MockClient((_) async => http.Response('{}', 500)));
      final ok = await auth.handleSignIn();
      expect(ok, isFalse);
      expect(user.getStatus(), AuthStatus.AUTHENTICATED);
    });

    test('without tokens a failed sign in ends signed out', () async {
      user.authResponse = null;
      user.status = AuthStatus.INPROGRESS;
      final auth = MalAuthV2(httpClient: MockClient((_) async => http.Response('{}', 500)));
      await auth.checkIfSignIn(Uri.parse('mywatchlist://callback?code=abc'));
      expect(user.getStatus(), AuthStatus.UNAUTHENTICATED);
    });
  });
}
