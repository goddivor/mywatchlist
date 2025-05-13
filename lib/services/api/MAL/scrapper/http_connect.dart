import 'package:html/dom.dart';
import 'package:http/http.dart' as http;

/// A utility class for connecting to HTTP resources and parsing HTML responses.
class HttpConnect {
  static Future<Map<String, dynamic>?> htmlPage(
    String url, [
    dynamic Function(Document)? fromHtml,
    Map<String, String>? headers,
  ]) async {
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final document = Document.html(response.body);
      if (fromHtml != null) {
         final parsed = fromHtml(document);
         return toJson(parsed);
      } else {
        return {'html': response.body};
      }
    } else {
      throw Exception('Failed to load page');
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