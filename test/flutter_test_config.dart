import 'dart:async';

import 'helpers/no_network.dart';

/// Applies to every test under `test/` (smoke and `test/units/**`):
/// any real network access fails with [NetworkAccessInTest].
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  forbidNetwork();
  await testMain();
}
