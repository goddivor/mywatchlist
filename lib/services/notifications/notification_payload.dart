import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;

/// What a tapped notification opens, on its tracker.
///
/// Each kind is written as its [token] in the payload.
enum PayloadKind {
  /// The tracker's own anime page; [NotificationPayload.id] = the tracker's anime id.
  anime('anime'),

  /// The tracker's own manga page; [NotificationPayload.id] = the tracker's manga id.
  manga('manga'),

  /// The tracker's calendar.
  calendar('calendar'),

  /// The tracker's bookmarks.
  bookmarks('bookmarks'),

  /// The tracker's notifications screen (MAL hub screen, AniList inbox, Kitsu once built).
  notifications('notifications'),

  /// One MAL hub item: [NotificationPayload.id] = the hub item id (may be null),
  /// [NotificationPayload.extra] = its target url (may be null). A url pointing to
  /// `mymessages.php` is a private message thread or box (`MalMessageLink.parse`), as today.
  hub('hub'),

  /// One private message thread: [NotificationPayload.id] = the message id,
  /// [NotificationPayload.extra] = the thread id when known.
  message('message'),

  /// The private message inbox.
  messages('messages');

  const PayloadKind(this.token);

  final String token;

  static PayloadKind? fromToken(String token) {
    for (final k in values) {
      if (k.token == token) return k;
    }
    return null;
  }
}

/// A tracker-tagged notification payload: the one string format every notification of the
/// app carries (`flutter_local_notifications` payload), written by the notification units and
/// parsed by the router (`AppRoutes.openFromNotification`).
///
/// ## Format (frozen)
///
/// `<tracker>:<kind>[:<id>[:<extra>]]`
///
/// * `<tracker>` = [AccountType.name] (`myanimelist`, `anilist`, `kitsu`, `simkl`), the same
///   token as the per-tracker preference keys (`TrackerScope.key`). `none` is never valid.
/// * `<kind>` = [PayloadKind.token].
/// * `<id>` has no `:`; it may be empty when an `<extra>` follows. Positive integer for
///   [PayloadKind.anime], [PayloadKind.manga] and [PayloadKind.message].
/// * `<extra>` is everything after the third `:` (it may hold `:`, e.g. a url).
///
/// Examples: `anilist:anime:21`, `kitsu:calendar`, `simkl:anime:39587`,
/// `myanimelist:message:123:456`, `myanimelist:hub:98:https://myanimelist.net/forum/?topicid=1`,
/// `anilist:notifications`.
///
/// ## Legacy payloads (alarms and shade entries written before this format), read as MAL
///
/// * `anime:<id>` / `manga:<id>` → MAL [PayloadKind.anime] / [PayloadKind.manga].
/// * `calendar` / `bookmarks` → MAL [PayloadKind.calendar] / [PayloadKind.bookmarks].
/// * `malhub:` → MAL [PayloadKind.notifications] (the hub screen).
/// * `malhub:<itemId>|<url>` → MAL [PayloadKind.hub] (item id, url; private message links
///   included, read with `MalMessageLink.parse(extra)`); an item id holding `:` is dropped).
/// * `anilist:notifications` is already in the new format (AniList inbox).
///
/// [parse] never throws: an empty, unknown or malformed payload is null (the tap does nothing).
/// [isLegacy] tells a legacy payload from a new one.
///
/// ## Opening rule (owner, 2026-10-29)
///
/// A tap on a payload of tracker T switches the active account to T first (when T is
/// connected), then opens T's own screen for [kind].
@immutable
class NotificationPayload {
  const NotificationPayload._(this.tracker, this.kind, {this.id, this.extra, this.isLegacy = false});

  /// The tracker whose screen opens; never [AccountType.none].
  final AccountType tracker;
  final PayloadKind kind;

  /// The content, message or hub item id; null when the kind has none.
  final String? id;

  /// Free tail (hub url, message thread id); null when absent.
  final String? extra;

  /// Read from a legacy payload (see the class doc); always false for a built one.
  final bool isLegacy;

  /// [id] as a positive integer, else null.
  int? get intId => _positive(id);

  /// [extra] as a positive integer (a message's thread id), else null.
  int? get intExtra => _positive(extra);

  /// The tracker's anime page of [id] (the tracker's own anime id).
  factory NotificationPayload.anime(AccountType tracker, int id) =>
      NotificationPayload._content(tracker, PayloadKind.anime, id);

  /// The tracker's manga page of [id] (the tracker's own manga id).
  factory NotificationPayload.manga(AccountType tracker, int id) =>
      NotificationPayload._content(tracker, PayloadKind.manga, id);

  factory NotificationPayload._content(AccountType tracker, PayloadKind kind, int id) {
    _checkTracker(tracker);
    if (id <= 0) throw ArgumentError.value(id, 'id', 'must be positive');
    return NotificationPayload._(tracker, kind, id: '$id');
  }

  /// The tracker's calendar.
  factory NotificationPayload.calendar(AccountType tracker) =>
      NotificationPayload._plain(tracker, PayloadKind.calendar);

  /// The tracker's bookmarks.
  factory NotificationPayload.bookmarks(AccountType tracker) =>
      NotificationPayload._plain(tracker, PayloadKind.bookmarks);

  /// The tracker's notifications screen.
  factory NotificationPayload.notifications(AccountType tracker) =>
      NotificationPayload._plain(tracker, PayloadKind.notifications);

  factory NotificationPayload._plain(AccountType tracker, PayloadKind kind) {
    _checkTracker(tracker);
    return NotificationPayload._(tracker, kind);
  }

  /// A MAL private message thread: message [id], its [threadId] when known.
  factory NotificationPayload.malMessage(int id, {int? threadId}) {
    if (id <= 0) throw ArgumentError.value(id, 'id', 'must be positive');
    return NotificationPayload._(AccountType.myanimelist, PayloadKind.message,
        id: '$id', extra: threadId != null && threadId > 0 ? '$threadId' : null);
  }

  /// The MAL private message inbox (several messages at once).
  factory NotificationPayload.malMessages() =>
      const NotificationPayload._(AccountType.myanimelist, PayloadKind.messages);

  /// One MAL hub item: its [itemId] (no `:`) and target [url], each optional.
  factory NotificationPayload.malHub({String? itemId, String? url}) {
    final id = _blankToNull(itemId);
    if (id != null && id.contains(':')) {
      throw ArgumentError.value(itemId, 'itemId', 'must not contain ":"');
    }
    return NotificationPayload._(AccountType.myanimelist, PayloadKind.hub,
        id: id, extra: _blankToNull(url));
  }

  /// The payload string (always the new format, also for a payload read as legacy).
  String encode() {
    final head = '${tracker.name}:${kind.token}';
    if (extra != null) return '$head:${id ?? ''}:$extra';
    if (id != null) return '$head:$id';
    return head;
  }

  @override
  String toString() => encode();

  /// Reads [payload]; null when it is empty, unknown or malformed (see the class doc).
  static NotificationPayload? parse(String? payload) {
    final value = payload?.trim();
    if (value == null || value.isEmpty) return null;
    return _legacy(value) ?? _current(value);
  }

  static const String _malHubPrefix = 'malhub:';

  static NotificationPayload? _legacy(String value) {
    const mal = AccountType.myanimelist;
    if (value == 'calendar') {
      return const NotificationPayload._(mal, PayloadKind.calendar, isLegacy: true);
    }
    if (value == 'bookmarks') {
      return const NotificationPayload._(mal, PayloadKind.bookmarks, isLegacy: true);
    }
    if (value.startsWith(_malHubPrefix)) {
      final rest = value.substring(_malHubPrefix.length);
      if (rest.isEmpty) {
        return const NotificationPayload._(mal, PayloadKind.notifications, isLegacy: true);
      }
      final bar = rest.indexOf('|');
      // An item id with `:` cannot be re-encoded; the url still opens the item.
      final rawId = _blankToNull(bar < 0 ? rest : rest.substring(0, bar));
      final id = rawId != null && rawId.contains(':') ? null : rawId;
      final url = bar < 0 ? null : _blankToNull(rest.substring(bar + 1));
      if (id == null && url == null) {
        return const NotificationPayload._(mal, PayloadKind.notifications, isLegacy: true);
      }
      return NotificationPayload._(mal, PayloadKind.hub, id: id, extra: url, isLegacy: true);
    }
    final parts = value.split(':');
    if (parts.length == 2 && (parts[0] == 'anime' || parts[0] == 'manga')) {
      final id = _positive(parts[1]);
      if (id == null) return null;
      return NotificationPayload._(
          mal, parts[0] == 'anime' ? PayloadKind.anime : PayloadKind.manga,
          id: '$id', isLegacy: true);
    }
    return null;
  }

  static NotificationPayload? _current(String value) {
    final first = value.indexOf(':');
    if (first <= 0) return null;
    final tracker = _trackerOf(value.substring(0, first));
    if (tracker == null) return null;
    final rest = value.substring(first + 1);
    final second = rest.indexOf(':');
    final kind = PayloadKind.fromToken(second < 0 ? rest : rest.substring(0, second));
    if (kind == null) return null;
    String? id;
    String? extra;
    if (second >= 0) {
      final tail = rest.substring(second + 1);
      final third = tail.indexOf(':');
      id = _blankToNull(third < 0 ? tail : tail.substring(0, third));
      extra = third < 0 ? null : _blankToNull(tail.substring(third + 1));
    }
    switch (kind) {
      case PayloadKind.anime:
      case PayloadKind.manga:
        if (_positive(id) == null || extra != null) return null;
      case PayloadKind.message:
        if (_positive(id) == null) return null;
      case PayloadKind.hub:
        break;
      case PayloadKind.calendar:
      case PayloadKind.bookmarks:
      case PayloadKind.notifications:
      case PayloadKind.messages:
        if (id != null || extra != null) return null;
    }
    return NotificationPayload._(tracker, kind, id: id, extra: extra);
  }

  static AccountType? _trackerOf(String token) {
    for (final t in AccountType.values) {
      if (t != AccountType.none && t.name == token) return t;
    }
    return null;
  }

  static void _checkTracker(AccountType tracker) {
    if (tracker == AccountType.none) {
      throw ArgumentError.value(tracker, 'tracker', 'a payload names a tracker');
    }
  }

  static String? _blankToNull(String? s) => s == null || s.isEmpty ? null : s;

  static int? _positive(String? s) {
    final n = s == null ? null : int.tryParse(s);
    return n != null && n > 0 ? n : null;
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPayload &&
      other.tracker == tracker &&
      other.kind == kind &&
      other.id == id &&
      other.extra == extra &&
      other.isLegacy == isLegacy;

  @override
  int get hashCode => Object.hash(tracker, kind, id, extra, isLegacy);
}
