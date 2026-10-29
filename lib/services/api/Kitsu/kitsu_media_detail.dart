import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';

/// Reads for the native Kitsu title page, on top of [KitsuGraphql] (anonymous, read-only).
///
/// One request returns the record with its first page of every section; the rating histogram
/// is a second, separate request (GraphQL does not expose it) and may fail without losing the
/// page. Answers are kept for [ttl] so reopening a title, or coming back from a related one, is
/// instant; pull to refresh passes `force`.
class KitsuMediaDetailService {
  KitsuMediaDetailService({KitsuGraphql? graphql, this.ttl = const Duration(minutes: 10)})
      : _graphql = graphql;

  /// Replaced by tests.
  static KitsuMediaDetailService instance = KitsuMediaDetailService();

  final KitsuGraphql? _graphql;
  final Duration ttl;
  final Map<String, ({DateTime at, Object value})> _cache = {};

  KitsuGraphql get _gql => _graphql ?? KitsuGraphql.instance;

  static String detailKey(KitsuMediaKind kind, String key) => 'detail:${kind.path}:$key';
  static String ratingsKey(KitsuMediaKind kind, String id) => 'ratings:${kind.path}:$id';

  /// The cached value of [key], even if it is older than [ttl] (a page shows it at once, then
  /// refreshes). Null when never loaded.
  T? peek<T extends Object>(String key) {
    final v = _cache[key]?.value;
    return v is T ? v : null;
  }

  Future<T> _cached<T extends Object>(String key, bool force, Future<T> Function() load) async {
    final hit = _cache[key];
    if (!force && hit != null && hit.value is T && DateTime.now().difference(hit.at) < ttl) {
      return hit.value as T;
    }
    final value = await load();
    _cache[key] = (at: DateTime.now(), value: value);
    return value;
  }

  /// The title by [id] (preferred) or [slug], with the first page of every section. Null when
  /// Kitsu has no such title. Throws on network and server errors.
  Future<KitsuMediaDetail?> detail(KitsuMediaKind kind, {String? id, String? slug, bool force = false}) async {
    assert(id != null || slug != null, 'give an id or a slug');
    final key = id ?? slug!;
    final hit = _cache[detailKey(kind, key)];
    if (!force && hit != null && hit.value is KitsuMediaDetail && DateTime.now().difference(hit.at) < ttl) {
      return hit.value as KitsuMediaDetail;
    }
    final found = await _gql.mediaDetail(kind, id: id, slug: id == null ? slug : null);
    if (found == null) return null;
    final at = DateTime.now();
    // Known under both keys: a tile opens by id, a related title by slug.
    _cache[detailKey(kind, found.id)] = (at: at, value: found);
    _cache[detailKey(kind, found.slug)] = (at: at, value: found);
    return found;
  }

  /// The rating histogram of [id]; empty when nobody rated it. Throws on errors.
  Future<KitsuRatingFrequencies> ratings(KitsuMediaKind kind, String id, {bool force = false}) =>
      _cached(ratingsKey(kind, id), force, () => _gql.ratingFrequencies(kind, id));

  /// A page of episodes (anime) or chapters (manga).
  Future<KitsuConnection<KitsuUnit>> units(KitsuMediaKind kind, String id, KitsuPageArgs page) =>
      _gql.mediaUnits(kind, id, page);

  Future<KitsuConnection<KitsuReaction>> reactions(KitsuMediaKind kind, String id, KitsuPageArgs page) =>
      _gql.mediaReactions(kind, id, page);

  Future<KitsuConnection<KitsuCharacterRole>> characters(KitsuMediaKind kind, String id, KitsuPageArgs page) =>
      _gql.mediaCharacters(kind, id, page);

  Future<KitsuConnection<KitsuStaffMember>> staff(KitsuMediaKind kind, String id, KitsuPageArgs page) =>
      _gql.mediaStaff(kind, id, page);
}
