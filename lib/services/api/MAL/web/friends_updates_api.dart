import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html;
import 'package:mwl_commons/mwl_commons.dart' show ContentUpdateHtml, PageParsers;
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';

/// Which members of the stats page's "Recently Updated By" table are listed.
enum FriendsSource {
  /// "My Friends": the default page of a signed-in viewer.
  friends(''),

  /// "My Top Friends" (`?m=top`).
  top('?m=top');

  final String query;
  const FriendsSource(this.query);
}

/// The friends' rows of one title, read from MAL's own stats page with the website session.
@immutable
class FriendsUpdates {
  final List<ContentUpdateHtml> updates;

  /// MAL printed its "My Friends" tab: the page was served to a signed-in viewer.
  final bool signedIn;

  const FriendsUpdates({this.updates = const [], this.signedIn = false});
}

/// The rows of a stats page read for a signed-in viewer. [signedIn] is true when the page
/// has the "My Top Friends | My Friends | All Members" header (absent without a session). Never throws.
FriendsUpdates parseFriendsUpdates(String raw, {DateTime? now}) {
  final doc = html.parse(raw);
  // The current tab is plain text, the others links: look at the tabs header's text.
  final header = doc.querySelectorAll('span').where((e) => e.text.contains('All Members'));
  final signedIn = header.any((e) => e.text.contains('My Friends') && e.text.contains('My Top Friends'));
  // Live header cells are links, which the shared row parser would read as a member
  // called "Member": drop the header row first.
  for (final row in doc.querySelectorAll('table.table-recently-updated tr')) {
    if (row.querySelector('td.fw-b') != null) row.remove();
  }
  final page = PageParsers.parseRecentUpdates(doc, now: now);
  return FriendsUpdates(updates: page.updates, signedIn: signedIn);
}

/// Friends' list updates of a title (anime or manga), `GET /{category}/{id}/_/stats` with
/// the website session. Read only: nothing is written to MAL.
class FriendsUpdatesApi {
  FriendsUpdatesApi({MalWebClient? client}) : _client = client;

  final MalWebClient? _client;
  MalWebClient get _web => _client ?? MalWebClient.instance;

  /// True when a MAL website session is connected.
  Future<bool> get hasSession async {
    final session = _web.session;
    await session.ensureLoaded();
    return session.isConnected;
  }

  /// Throws [MalWebNoSession] without a session and [MalWebSessionExpired] when MAL
  /// refuses it; a page without the friends tabs gives [FriendsUpdates.signedIn] false.
  Future<FriendsUpdates> fetch(String category, int id, FriendsSource source, {DateTime? now}) async {
    if (!await hasSession) throw const MalWebNoSession();
    final kind = category == 'manga' ? 'manga' : 'anime';
    final response = await _web.get('/$kind/$id/_/stats${source.query}');
    if (response.statusCode != 200) {
      throw MalWebActionFailed(statusCode: response.statusCode);
    }
    return parseFriendsUpdates(response.body, now: now);
  }
}
