import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/models/search_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheManager {
  static const String homepageService = 'homepage';

  static CacheManager instance = new CacheManager();
  static SharedPreferences? pref;

  CacheManager() {
    SharedPreferences.getInstance().then((value) => pref = value);
  }

  Future<SharedPreferences> get _pref async =>
      pref ?? await SharedPreferences.getInstance();

  Future<bool> checkIfExists(String url) async {
    try {
      pref = pref ?? await SharedPreferences.getInstance();
      return pref!.containsKey(url);
    } catch (e) {
      // logDal(e);
    }
    return false;
  }

  Future<dynamic> getCachedContent(String url) async {
    try {
      pref = pref ?? await SharedPreferences.getInstance();
      if (!(await checkIfExists(url))) {
        return null;
      }
      Map<String, dynamic> _map = jsonDecode(pref?.getString(url) ?? "{}");
      return _map.isEmpty ? null : _map;
    } catch (e) {
      // logDal(e);
    }
    return null;
  }

  Future<bool> setCachedJson(String url, dynamic result,
      {SharedPreferences? pref}) async {
    try {
      pref = pref ?? await SharedPreferences.getInstance();
      return await pref.setString(url, jsonEncode(result));
    } catch (e) {
      // logDal(e);
    }
    return false;
  }

  Future<void> resetData() async {
    pref = pref ?? await SharedPreferences.getInstance();
    await pref?.clear();
  }

  Future<String?> getValue(String key) async {
    return (pref ?? await SharedPreferences.getInstance()).getString(key);
  }

  Future<void> setValue(String key, String value) async {
    (pref ?? await SharedPreferences.getInstance()).setString(key, value);
  }

  Future<String?> getValueForService(String serviceName, String key) async {
    return getValue("$serviceName - $key");
  }

  Future<String?> getValueForServiceAutoExpire(
    String serviceName,
    String key, [
    int expiresIn = 60 * 60 * 24,
  ]) async {
    final value = await getValue("$serviceName - $key");
    if (value != null) {
      final map = jsonDecode(value);
      if (map is Map) {
        final time = map["time"];
        if (time is int) {
          final now = DateTime.now().millisecondsSinceEpoch;
          expiresIn *= 1000;
          if ((now - time) < expiresIn) {
            return map['value'];
          }
        }
      }
    }
    return null;
  }

  Future<void> setValueForServiceAutoExpireIn(
      String serviceName, String key, String? value) async {
    if (value == null) {
      await pref?.remove("$serviceName - $key");
    } else {
      await setValueForService(
          serviceName,
          key,
          jsonEncode({
            "time": DateTime.now().millisecondsSinceEpoch,
            "value": value,
          }));
    }
  }

  Future<void> setValueForService(
      String serviceName, String key, String value) async {
    setValue("$serviceName - $key", value);
  }

  Future<String?> getUserImage(String? username) async {
    if (username == null) return null;
    return await CacheManager.instance
        .getValueForService("cached-user-image", username);
  }

  Future<void> setUserImage(String? username, String? url) async {
    if (username != null && url != null)
      await CacheManager.instance
          .setValueForService("cached-user-image", username, url);
  }

  Future<String> getBackUpData() async {
    final pref = await _pref;
    final allData = <String, String>{};
    final keys = [
      'user',
      // StreamUtils.i.key(StreamType.book_marks),
      // '${UserContentBuilder.serviceName} - anime-@me',
      // '${UserContentBuilder.serviceName} - manga-@me',
    ];
    for (var key in keys) {
      String? data = pref.get(key)?.toString();
      if (data != null) {
        allData[key] = data;
      }
    }
    return jsonEncode(allData);
  }

  Future<bool> restoreData(String data) async {
    try {
      final pref = await _pref;
      final map = jsonDecode(data);
      if (map is Map) {
        final keys = map.keys;
        for (var key in keys) {
          final value = map[key];
          if (value != null) {
            pref.setString(key, value);
          }
        }
      } else {
        throw Error();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isFirstTime(String key) async {
    final value = await getValue(key);
    if (value == null) {
      setValue(key, "true");
      return true;
    }
    return false;
  }

  void setFirstTime(String s) {
    setValue(s, "true");
  }

  // --- Homepage cache helpers ---

  Future<void> cacheAnimeList(String sectionKey, List<Anime> animeList) async {
    final jsonList = animeList.map((a) => a.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await setValueForServiceAutoExpireIn(homepageService, sectionKey, jsonString);
  }

  Future<List<Anime>?> getCachedAnimeList(
      String sectionKey, [int expiresInSeconds = 7200]) async {
    final jsonString = await getValueForServiceAutoExpire(
        homepageService, sectionKey, expiresInSeconds);
    if (jsonString == null) return null;
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => Anime.fromMAlJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Cache error (anime) $sectionKey: $e');
      return null;
    }
  }

  Future<void> cacheNewsList(
      String sectionKey, List<Map<String, String>> news) async {
    final jsonString = jsonEncode(news);
    await setValueForServiceAutoExpireIn(homepageService, sectionKey, jsonString);
  }

  Future<List<Map<String, String>>?> getCachedNewsList(
      String sectionKey, [int expiresInSeconds = 28800]) async {
    final jsonString = await getValueForServiceAutoExpire(
        homepageService, sectionKey, expiresInSeconds);
    if (jsonString == null) return null;
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((item) => Map<String, String>.from(item as Map))
          .toList();
    } catch (e) {
      debugPrint('Cache error (news) $sectionKey: $e');
      return null;
    }
  }

  /// Cache a SearchResult with auto-expiry.
  Future<void> cacheSearchResult(String sectionKey, SearchResult result) async {
    final jsonString = jsonEncode(result.toJson());
    await setValueForServiceAutoExpireIn(homepageService, sectionKey, jsonString);
  }

  /// Get a cached SearchResult.
  Future<SearchResult?> getCachedSearchResult(
      String sectionKey, [int expiresInSeconds = 7200]) async {
    final jsonString = await getValueForServiceAutoExpire(
        homepageService, sectionKey, expiresInSeconds);
    if (jsonString == null) return null;
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return SearchResult.fromJson(jsonMap);
    } catch (e) {
      debugPrint('Cache error (searchResult) $sectionKey: $e');
      return null;
    }
  }

  Future<void> clearHomepageCache() async {
    pref = pref ?? await SharedPreferences.getInstance();
    final keys =
        pref!.getKeys().where((key) => key.startsWith('$homepageService - '));
    for (final key in keys) {
      await pref!.remove(key);
    }
  }
}
