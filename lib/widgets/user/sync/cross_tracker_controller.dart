import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/sync_errors.dart';

enum SlotPhase {
  /// Looking for the link and the entry.
  loading,

  /// No link yet, the user can search or link by hand.
  unlinked,

  /// Linked; [TrackerSlot.entry] is null when the media is not on the list.
  linked,

  /// The tracker has no usable session.
  authRequired,

  /// The tracker cannot hold this category (Simkl and manga).
  unsupported,

  /// Loading failed; retry.
  failed,
}

/// What one tracker card shows. Immutable: a change is a new value.
@immutable
class TrackerSlot {
  final AccountType tracker;
  final SlotPhase phase;
  final String? linkId;
  final SyncEntry? entry;

  /// The entry was read (it may still be null: not on the list).
  final bool entryLoaded;

  /// A write (remove...) is running on this tracker.
  final bool busy;

  const TrackerSlot(
    this.tracker,
    this.phase, {
    this.linkId,
    this.entry,
    this.entryLoaded = false,
    this.busy = false,
  });

  bool get isLinked => linkId != null;

  TrackerSlot copyWith({
    SlotPhase? phase,
    String? linkId,
    SyncEntry? entry,
    bool? busy,
    bool? entryLoaded,
    bool clearEntry = false,
    bool clearLink = false,
  }) =>
      TrackerSlot(
        tracker,
        phase ?? this.phase,
        linkId: clearLink ? null : (linkId ?? this.linkId),
        entry: clearEntry ? null : (entry ?? this.entry),
        entryLoaded: entryLoaded ?? this.entryLoaded,
        busy: busy ?? this.busy,
      );
}

/// Loads, per tracker and in parallel, the link and the entry of one
/// MyAnimeList media, and keeps one [ValueNotifier] per tracker so that a card
/// rebuilds alone. Nothing here touches MyAnimeList: it is loaded only when
/// the user opens the sync dialog.
class CrossTrackerController {
  CrossTrackerController({
    required this.service,
    required this.trackers,
    required this.malId,
    required this.category,
  }) {
    for (final t in trackers) {
      slots[t] = ValueNotifier(TrackerSlot(t, SlotPhase.loading));
    }
  }

  final TrackerSyncService service;
  final List<AccountType> trackers;
  final int malId;
  final String category;
  final Map<AccountType, ValueNotifier<TrackerSlot>> slots = {};

  bool _disposed = false;
  int _generation = 0;

  bool get isAnime => category == 'anime';

  /// Loads every tracker at once; each card turns up as soon as its own
  /// answer arrives.
  Future<void> loadAll() => Future.wait([for (final t in trackers) load(t)]);

  Future<void> load(AccountType tracker) async {
    final generation = _generation;
    _set(tracker, (s) => TrackerSlot(tracker, SlotPhase.loading), generation);
    final client = service.clientFor(tracker);
    if (client == null || !client.supports(isAnime: isAnime)) {
      _set(tracker, (s) => TrackerSlot(tracker, SlotPhase.unsupported),
          generation);
      return;
    }
    try {
      final id = await service.resolveLink(malId, category, tracker);
      if (id == null) {
        _set(tracker, (s) => TrackerSlot(tracker, SlotPhase.unlinked),
            generation);
        return;
      }
      _set(tracker, (s) => TrackerSlot(tracker, SlotPhase.linked, linkId: id),
          generation);
      final entry =
          await service.readTracker(tracker, id, category, malId: malId);
      _set(
          tracker,
          (s) => TrackerSlot(tracker, SlotPhase.linked,
              linkId: id, entry: entry, entryLoaded: true),
          generation);
    } on SyncAuthRequired {
      _set(tracker, (s) => TrackerSlot(tracker, SlotPhase.authRequired),
          generation);
    } on SyncUnsupported {
      _set(tracker, (s) => TrackerSlot(tracker, SlotPhase.unsupported),
          generation);
    } catch (e) {
      debugPrint('Loading ${tracker.name} failed (${e.runtimeType})');
      _set(
          tracker,
          (s) => TrackerSlot(tracker, SlotPhase.failed, linkId: s.linkId),
          generation);
    }
  }

  /// Stores a link the user picked and reads the entry behind it.
  Future<void> link(AccountType tracker, String trackerId) async {
    await service.saveLinkId(malId, category, tracker, trackerId);
    await load(tracker);
  }

  Future<void> unlink(AccountType tracker) async {
    await service.removeLinkId(malId, category, tracker);
    _set(tracker, (s) => TrackerSlot(tracker, SlotPhase.unlinked),
        _generation);
  }

  /// Shows [entry] as the tracker's current state (after a save or a sync).
  void applyEntry(AccountType tracker, SyncEntry entry) =>
      _set(tracker, (s) => s.copyWith(entry: entry, entryLoaded: true, busy: false), _generation);

  void setBusy(AccountType tracker, bool busy) =>
      _set(tracker, (s) => s.copyWith(busy: busy), _generation);

  void clearEntry(AccountType tracker) => _set(
      tracker, (s) => s.copyWith(clearEntry: true, entryLoaded: true, busy: false), _generation);

  /// Reloads everything for another media.
  Future<void> reset() {
    _generation++;
    return loadAll();
  }

  void _set(AccountType tracker, TrackerSlot Function(TrackerSlot) next,
      int generation) {
    if (_disposed || generation != _generation) return;
    final notifier = slots[tracker];
    if (notifier == null) return;
    notifier.value = next(notifier.value);
  }

  void dispose() {
    _disposed = true;
    for (final n in slots.values) {
      n.dispose();
    }
  }
}
