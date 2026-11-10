import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Build a successful JSON response.
Response okResponse(Map<String, dynamic> data) {
  return Response.ok(
    jsonEncode(data),
    headers: {'Content-Type': 'application/json; charset=utf-8'},
  );
}

/// Build an error JSON response.
Response errorResponse([String message = 'Internal Server Error']) {
  return Response.internalServerError(
    body: jsonEncode({'error': true, 'message': message}),
    headers: {'Content-Type': 'application/json; charset=utf-8'},
  );
}

/// Build a 400 JSON response for a missing or invalid parameter.
Response badRequestResponse(String message) {
  return Response.badRequest(
    body: jsonEncode(badRequestBody(message)),
    headers: {'Content-Type': 'application/json; charset=utf-8'},
  );
}

/// Error body of a 400 answer, shared by the HTTP and in-process entry points.
Map<String, dynamic> badRequestBody(String message) =>
    {'error': true, 'status': 400, 'message': message};

/// Extract a query parameter from a URI, with optional default value.
T? queryParams<T>(Uri uri, String key, [T? defaultValue]) {
  final value = uri.queryParameters[key];
  if (value == null) return defaultValue;

  if (T == bool) {
    return (value.toLowerCase() == 'true') as T;
  }
  if (T == int) {
    return (int.tryParse(value) ?? defaultValue) as T?;
  }
  if (T == double) {
    return (double.tryParse(value) ?? defaultValue) as T?;
  }
  return value as T;
}

/// Build a query string from a map, filtering out null values.
String buildQueryParams(Map<String, dynamic> params) {
  final entries = params.entries
      .where((e) => e.value != null)
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}');
  return entries.join('&');
}
