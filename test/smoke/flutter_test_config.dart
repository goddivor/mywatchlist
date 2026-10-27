import 'dart:async';

import '../helpers/no_network.dart';

/// Applies to every test under `test/smoke/`: any real network access fails.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  forbidNetwork();
  await testMain();
}
