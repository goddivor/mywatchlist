import 'package:shelf/shelf.dart';

import 'handlers/handler_core.dart';

/// Sets up the Shelf pipeline for the MWL local API server.
class MwlLocalApi {
  static Handler get handler {
    final handlerCore = HandlerCore();

    return const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(handlerCore.handleRequest);
  }
}
