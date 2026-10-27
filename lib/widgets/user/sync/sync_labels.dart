import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/widgets/user/edit/edit_labels.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/sync_errors.dart';

/// Texts of the sync screens, read from `S` at build time so a language change
/// applies at once.

/// "Watching · 7.5 · Ep. 12": what an entry holds, in a line.
String entrySummary(SyncEntry e,
    {required bool isAnime, bool withStatus = true}) {
  final parts = <String>[
    if (withStatus && e.status != null) statusLabel(e.status),
    if (e.hasScore) SyncScores.format(e.score!),
    if (e.progress != null && e.progress! > 0)
      isAnime
          ? S.current.Sync_Summary_Episodes(e.progress!)
          : S.current.Sync_Summary_Chapters(e.progress!),
  ];
  return parts.join(' · ');
}

/// Why a sync or a load failed, in the user's words.
String syncErrorMessage(Object error, AccountType tracker) {
  final name = TrackerSyncService.trackerName(tracker);
  if (error is SyncAuthRequired) {
    return error.tracker == AccountType.myanimelist
        ? S.current.Sync_Mal_Not_Connected
        : S.current.Sync_Sign_In_Again(
            TrackerSyncService.trackerName(error.tracker));
  }
  if (error is SyncSourceEmpty) {
    return S.current
        .Sync_Source_Empty(TrackerSyncService.trackerName(error.tracker));
  }
  if (error is SyncUnsupported) return S.current.Sync_Manga_Unsupported(name);
  return S.current.Sync_Failed;
}

/// A tracker's logo at a fixed size, decoded at that size.
class TrackerLogo extends StatelessWidget {
  const TrackerLogo(this.tracker, {super.key, this.size = 28});

  final AccountType tracker;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: Image.asset(
        TrackerSyncService.trackerLogo(tracker),
        width: size,
        height: size,
        cacheWidth: (size * dpr).round(),
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => Icon(Icons.link, size: size),
      ),
    );
  }
}
