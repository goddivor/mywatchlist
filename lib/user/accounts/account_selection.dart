import 'package:mywatchlist/constants/constants.dart';

/// Which tracker is the active account, given what is signed in.
///
/// * the current tracker stays when it is still connected, or when only its session died
///   (the app keeps showing it and asks to sign in again), or while it signs in again
///   ([connecting]: the website login puts a connected tracker in progress for a moment);
/// * otherwise the first connected tracker takes over (no picker, no "Continue" step);
/// * with nothing connected the answer is [AccountType.none] (the sign-in screen).
AccountType resolveSelection({
  required AccountType current,
  required List<AccountType> connected,
  required List<AccountType> expired,
  List<AccountType> connecting = const [],
}) {
  if (current != AccountType.none &&
      (connected.contains(current) ||
          expired.contains(current) ||
          connecting.contains(current))) {
    return current;
  }
  if (connected.isNotEmpty) return connected.first;
  return AccountType.none;
}

/// The tracker to activate right after a connection: the first of [connected] that was not
/// connected before, but only while no account is active (a user who already works with one
/// account is never switched behind their back).
AccountType? autoSelectNewConnection({
  required AccountType current,
  required List<AccountType> before,
  required List<AccountType> connected,
}) {
  if (current != AccountType.none) return null;
  for (final tracker in connected) {
    if (!before.contains(tracker)) return tracker;
  }
  return null;
}
