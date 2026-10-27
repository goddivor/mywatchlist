import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/no_network.dart';

void main() {
  test('package:http calls fail fast instead of reaching the network',
      () async {
    await expectLater(
      http.get(Uri.parse('https://api.myanimelist.net/v2/anime/1')),
      throwsA(isA<NetworkAccessInTest>()),
    );
  });

  test('dart:io HttpClient calls fail fast too', () async {
    final client = HttpClient();
    await expectLater(
      client.getUrl(Uri.parse('https://graphql.anilist.co')),
      throwsA(isA<NetworkAccessInTest>()),
    );
  });
}
