import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/auth/simkl_authresp.dart';

/// Simkl AUTH V2 (OAuth 2.0 authorization code with PKCE S256, refresh tokens, scopes),
/// the protocol only: URLs, PKCE, request bodies, token answers. No UI, no storage.
///
/// Reference: https://api.simkl.org/api-reference/auth-v2 and
/// https://api.simkl.org/guides/migrating-v1-to-v2 (AUTH V1 retires around April 2027).
///
/// V2 is a separate Simkl app registration ("Mobile, desktop & browser apps": no secret) with its
/// own client id, read from `SIMKL_V2_CLIENT_ID` in `assets/.env`. A V1 client id is refused by
/// every `/oauth2/*` URL, and a token only works with the client id it was issued for, so the
/// client id and these URLs are kept together here. Without `SIMKL_V2_CLIENT_ID` the app keeps
/// signing in through V1.
class SimklOAuth2 {
  SimklOAuth2._();

  // V2 endpoints. The consent page is on simkl.com, the token and revoke calls on api.simkl.com.
  static const String _authorizeUrl = 'https://simkl.com/oauth2/authorize';
  static const String _tokenUrl = 'https://api.simkl.com/oauth2/token';
  static const String _revokeUrl = 'https://api.simkl.com/oauth2/revoke';

  /// The `iss` Simkl adds to the redirect (RFC 9207).
  static const String issuer = 'https://simkl.com';

  /// Read and write: omitting `scope` (or misspelling it) grants read only.
  static const String scopes = 'media:read media:write';

  /// A V2 access token starts with this; a V1 token is 64 hex characters without prefix.
  static const String accessTokenPrefix = 'simkl_at_';

  /// `POST /oauth2/token` (code, refresh).
  static Uri get tokenUri => Uri.parse(_tokenUrl);

  /// `POST /oauth2/revoke` (ends the whole grant).
  static Uri get revokeUri => Uri.parse(_revokeUrl);

  /// Tests set the V2 client id here instead of loading an env file.
  static String? clientIdOverride;

  /// The V2 app's client id, empty when the app has none configured.
  static String get clientId {
    final forced = clientIdOverride;
    if (forced != null) return forced;
    try {
      return dotenv.env['SIMKL_V2_CLIENT_ID']?.trim() ?? '';
    } catch (_) {
      return ''; // env file not loaded
    }
  }

  /// Whether new sign ins go through V2.
  static bool get isConfigured => clientId.isNotEmpty;

  /// Whether [accessToken] was issued by AUTH V2 (no API call needed).
  static bool isV2Token(String? accessToken) =>
      accessToken != null && accessToken.startsWith(accessTokenPrefix);

  static const String _unreserved =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  /// A random string of [length] characters from the PKCE unreserved set (verifier: 43 to 128).
  static String randomToken([int length = 64, Random? random]) {
    final rnd = random ?? Random.secure();
    return String.fromCharCodes(
        Iterable.generate(length, (_) => _unreserved.codeUnitAt(rnd.nextInt(_unreserved.length))));
  }

  /// `code_challenge` of [verifier]: base64url SHA-256, no padding.
  static String challengeOf(String verifier) =>
      base64Url.encode(sha256Of(ascii.encode(verifier))).replaceAll('=', '');

  /// The consent page URL to open in the browser.
  static Uri authorizeUri({
    required String clientId,
    required String redirectUri,
    required String state,
    required String codeChallenge,
  }) =>
      Uri.parse(_authorizeUrl).replace(queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'scope': scopes,
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      });

  /// Body of the authorization code grant. The code is consumed by the first exchange, even a
  /// failed one: never send it twice.
  static Map<String, String> codeGrant({
    required String code,
    required String codeVerifier,
    required String clientId,
    required String redirectUri,
  }) =>
      {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
      };

  /// Body of the refresh grant. Simkl returns the same refresh token (180 days, slid forward) and
  /// a new access token; the previous access token stops working at once.
  static Map<String, String> refreshGrant({required String refreshToken, required String clientId}) =>
      {
        'grant_type': 'refresh_token',
        'client_id': clientId,
        'refresh_token': refreshToken,
      };

  /// Form-encoded POST, as RFC 6749 defines it (Simkl also accepts JSON).
  static Future<http.Response> postForm(http.Client client, Uri uri, Map<String, String> body) =>
      client.post(uri, headers: const {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      }, body: body);

  /// The tokens of a 200 answer of `/oauth2/token`, null when the answer is not usable.
  static SimklAuthResponse? parseToken(http.Response response, {DateTime? now}) {
    if (response.statusCode != 200) return null;
    final Object? data;
    try {
      data = json.decode(response.body);
    } catch (_) {
      return null;
    }
    if (data is! Map<String, dynamic>) return null;
    final access = data['access_token'];
    if (access is! String || access.isEmpty) return null;
    return SimklAuthResponse.fromJson({...data, 'created_time': (now ?? DateTime.now()).toIso8601String()});
  }

  /// The `error` code of an OAuth error answer (`invalid_grant`, `invalid_client`...), if any.
  static String? errorOf(http.Response response) {
    try {
      final data = json.decode(response.body);
      final error = data is Map ? data['error'] : null;
      return error is String ? error : null;
    } catch (_) {
      return null;
    }
  }
}

/// SHA-256 of [message] (FIPS 180-4). Written here because `crypto` is not a direct dependency of
/// the app; PKCE hashes a 64-character verifier, so speed does not matter.
Uint8List sha256Of(List<int> message) {
  const k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];
  const mask = 0xFFFFFFFF;
  int rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & mask;

  final bitLength = message.length * 8;
  final padded = BytesBuilder(copy: false)
    ..add(message)
    ..addByte(0x80);
  var length = message.length + 1;
  while (length % 64 != 56) {
    padded.addByte(0);
    length++;
  }
  final lengthBytes = ByteData(8)..setUint64(0, bitLength);
  padded.add(lengthBytes.buffer.asUint8List());
  final data = padded.toBytes();

  final h = <int>[
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];
  final w = List<int>.filled(64, 0);
  for (var offset = 0; offset < data.length; offset += 64) {
    for (var i = 0; i < 16; i++) {
      final j = offset + i * 4;
      w[i] = (data[j] << 24) | (data[j + 1] << 16) | (data[j + 2] << 8) | data[j + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & mask;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e & mask) & g);
      final t1 = (hh + s1 + ch + k[i] + w[i]) & mask;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & mask;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & mask;
    }
    h[0] = (h[0] + a) & mask;
    h[1] = (h[1] + b) & mask;
    h[2] = (h[2] + c) & mask;
    h[3] = (h[3] + d) & mask;
    h[4] = (h[4] + e) & mask;
    h[5] = (h[5] + f) & mask;
    h[6] = (h[6] + g) & mask;
    h[7] = (h[7] + hh) & mask;
  }
  final out = ByteData(32);
  for (var i = 0; i < 8; i++) {
    out.setUint32(i * 4, h[i]);
  }
  return out.buffer.asUint8List();
}
