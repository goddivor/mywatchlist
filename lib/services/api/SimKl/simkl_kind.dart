/// The three catalogues of Simkl. Each one has its own paths in the API, its own key in the
/// list and sync bodies, and its own folder on simkl.com:
///
/// | kind  | API (`/{api}/{id}`) | sync body / list key | activities | search  | site      |
/// |-------|---------------------|----------------------|------------|---------|-----------|
/// | tv    | `tv`                | `shows`              | `tv_shows` | `tv`    | `tv`      |
/// | anime | `anime`             | `anime`              | `anime`    | `anime` | `anime`   |
/// | movie | `movies`            | `movies`             | `movies`   | `movie` | `movies`  |
enum SimklKind {
  tv,
  anime,
  movie;

  /// Path segment of the catalogue endpoints (`/tv/{id}`, `/movies/trending`...).
  String get api => switch (this) { tv => 'tv', anime => 'anime', movie => 'movies' };

  /// Key of the list in `/sync/all-items/{key}` and of the items in the sync bodies.
  String get syncKey => switch (this) { tv => 'shows', anime => 'anime', movie => 'movies' };

  /// Key of the catalogue in `GET /sync/activities`.
  String get activitiesKey => switch (this) { tv => 'tv_shows', anime => 'anime', movie => 'movies' };

  /// `GET /search/{key}`.
  String get searchKey => switch (this) { tv => 'tv', anime => 'anime', movie => 'movie' };

  /// Folder of the title pages on simkl.com.
  String get site => switch (this) { tv => 'tv', anime => 'anime', movie => 'movies' };

  /// Key of the title inside a list item (`show` for shows and anime, `movie` for movies).
  String get itemKey => this == movie ? 'movie' : 'show';

  /// `ListEntryView.category` of the catalogue.
  String get category => switch (this) { tv => 'tv', anime => 'anime', movie => 'movie' };

  /// A movie is one viewing: no episodes, no watching, no on hold.
  bool get hasEpisodes => this != movie;

  /// The kind of a list category (`tv` | `anime` | `movie`); anime for anything else.
  static SimklKind ofCategory(String? category) => switch (category) {
        'tv' || 'show' || 'shows' => tv,
        'movie' || 'movies' => movie,
        _ => anime,
      };

  /// The kind of an `endpoint_type` / `type` field of the API (`tv`, `show`, `movies`, `movie`,
  /// `anime`); null when it says nothing.
  static SimklKind? ofType(Object? type) => switch (type) {
        'tv' || 'show' || 'shows' => tv,
        'movie' || 'movies' => movie,
        'anime' => anime,
        _ => null,
      };

  /// `https://simkl.com/{site}/{id}/{slug}` (no trailing slash: that form redirects).
  String pageUrl(int id, [String? slug]) =>
      'https://simkl.com/$site/$id${slug == null || slug.isEmpty ? '' : '/$slug'}';
}
