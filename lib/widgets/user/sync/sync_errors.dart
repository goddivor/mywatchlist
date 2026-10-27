import 'package:mywatchlist/constants/constants.dart';

/// The tracker has no usable session (signed out, or the session died).
class SyncAuthRequired implements Exception {
  final AccountType tracker;
  const SyncAuthRequired(this.tracker);
  @override
  String toString() => 'SyncAuthRequired(${tracker.name})';
}

/// The tracker answered with an error.
class SyncRequestFailed implements Exception {
  final AccountType tracker;
  final int? statusCode;
  final String detail;
  const SyncRequestFailed(this.tracker, this.statusCode, [this.detail = '']);
  @override
  String toString() => 'SyncRequestFailed(${tracker.name}, $statusCode)';
}

/// This tracker (or this category) cannot do what was asked.
class SyncUnsupported implements Exception {
  final AccountType tracker;
  const SyncUnsupported(this.tracker);
  @override
  String toString() => 'SyncUnsupported(${tracker.name})';
}

/// The user pressed Cancel.
class SyncCancelled implements Exception {
  const SyncCancelled();
  @override
  String toString() => 'SyncCancelled';
}

/// Shared flag between the dialog and a running sync.
///
/// A request already on the wire cannot be recalled, so cancelling stops the
/// sync at its next step: a write that was not sent yet is never sent.
class SyncCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;

  /// Throws [SyncCancelled] once cancelled.
  void check() {
    if (_cancelled) throw const SyncCancelled();
  }
}

/// The side to copy from has no entry for this media.
class SyncSourceEmpty implements Exception {
  final AccountType tracker;
  const SyncSourceEmpty(this.tracker);
  @override
  String toString() => 'SyncSourceEmpty(${tracker.name})';
}
