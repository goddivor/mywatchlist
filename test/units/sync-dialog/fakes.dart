import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/widgets/user/sync/mal_side.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_clients.dart';

/// In-memory ends of a sync: no tracker is ever reached.
class FakeMal implements MalEntrySide {
  FakeMal(this.entry, {this.connected = true});
  SyncEntry? entry;
  @override
  bool connected;
  final writes = <SyncEntry>[];
  void Function()? onRead;

  @override
  Future<SyncEntry?> read(int malId, {required bool isAnime}) async {
    onRead?.call();
    return entry;
  }

  @override
  Future<SyncEntry> write(int malId, SyncEntry e,
      {required bool isAnime}) async {
    writes.add(e);
    return entry = e;
  }
}

class FakeClient implements TrackerEntryClient {
  FakeClient(this.entry, {this.anime = true, this.found});
  SyncEntry? entry;
  final bool anime;
  final String? found;
  final writes = <SyncEntry>[];
  int finds = 0;

  @override
  AccountType get tracker => AccountType.anilist;
  @override
  bool supports({required bool isAnime}) => isAnime == anime || anime;
  @override
  Future<SyncEntry?> read(String mediaId,
          {required bool isAnime, int? malId}) async =>
      entry;
  @override
  Future<SyncEntry> write(String mediaId, SyncEntry e,
      {required bool isAnime, int? malId}) async {
    writes.add(e);
    return entry = e;
  }

  @override
  Future<void> delete(String mediaId,
      {required bool isAnime, int? malId}) async {
    entry = null;
  }

  @override
  Future<String?> findByMalId(int malId, {required bool isAnime}) async {
    finds++;
    return found;
  }
}
