import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';

/// A utility class for connecting to HTTP resources and parsing HTML responses.
/// Uses MalConnect.retryGet for automatic retry on transient failures.
class HttpConnect {
  static Future<Map<String, dynamic>?> htmlPage(
    String url, [
    dynamic Function(Document)? fromHtml,
    Map<String, String>? headers,
  ]) async {
    final response = await MalConnect.retryGet(url, headers ?? {});
    if (response.statusCode == 200) {
      final document = Document.html(response.body);
      if (fromHtml != null) {
         final parsed = fromHtml(document);
         return toJson(parsed);
      } else {
        return {'html': response.body};
      }
    } else {
      debugPrint('HttpConnect error: ${response.statusCode} for $url');
      throw Exception('Failed to load page (${response.statusCode})');
    }
  }

  static Map<String, dynamic>? toJson(dynamic data) {
    try {
      return data?.toJson();
    } catch (e) {
      if (e is NoSuchMethodError) {
        return data;
      } else {
        return null;
      }
    }
  }
}
