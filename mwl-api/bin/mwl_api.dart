import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:mwl_api/handlers/environment.dart';
import 'package:mwl_api/mwl_local_api.dart';

/// Standalone MWL API server entry point.
///
/// Run with: `dart run bin/mwl_api.dart`
/// Listens on 0.0.0.0:8080.
void main() async {
  // Initialize environment from system env vars
  Environment.i.initFromEnv();

  final handler = MwlLocalApi.handler;
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final server = await shelf_io.serve(handler, '0.0.0.0', port);

  print('MWL API server running at http://${server.address.host}:${server.port}');
}
