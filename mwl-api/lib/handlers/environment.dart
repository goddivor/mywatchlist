import 'dart:io';

/// Runtime environment configuration for the backend.
///
/// In standalone mode, reads from system environment variables.
/// In Flutter in-process mode, values are injected before HandlerCore is used.
class Environment {
  static final Environment i = Environment._();
  Environment._();

  String? malClientId;

  /// Initialize from system environment variables (standalone server mode).
  void initFromEnv() {
    malClientId = Platform.environment['MAL_CLIENT_ID'] ?? '';
    if (malClientId!.isEmpty) {
      print('WARNING: MAL_CLIENT_ID not set in environment');
    }
  }

  /// Initialize from provided values (Flutter in-process mode).
  void initFromValues({required String malClientId}) {
    this.malClientId = malClientId;
  }
}
