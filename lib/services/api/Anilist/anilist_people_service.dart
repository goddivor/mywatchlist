import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';

List<AnilistPersonRef> _refs(Object? v) => v is List
    ? [for (final e in v) AnilistPersonRef.fromJson(e)].whereType<AnilistPersonRef>().toList()
    : const [];

int _int(Object? v) => v is num ? v.toInt() : 0;

String? _strOrNull(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

List<String> _strings(Object? v) =>
    v is List ? [for (final e in v) if (_strOrNull(e) != null) e as String] : const [];

/// A date AniList may know only in part (`year`, `month`, `day` each nullable).
@immutable
class AnilistFuzzyDate {
  final int? year;
  final int? month;
  final int? day;

  const AnilistFuzzyDate({this.year, this.month, this.day});

  static const String fields = '{ year month day }';

  static AnilistFuzzyDate? fromJson(Object? json) {
    if (json is! Map) return null;
    final date = AnilistFuzzyDate(
      year: (json['year'] as num?)?.toInt(),
      month: (json['month'] as num?)?.toInt(),
      day: (json['day'] as num?)?.toInt(),
    );
    return date.isEmpty ? null : date;
  }

  bool get isEmpty => year == null && month == null && day == null;

  @override
  bool operator ==(Object other) =>
      other is AnilistFuzzyDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// The names of a character or a staff member.
@immutable
class AnilistPersonNames {
  /// The name in the user's preferred form (`userPreferred`).
  final String display;
  final String? full;
  final String? native;
  final List<String> alternative;

  /// Alternative names AniList marks as spoilers: shown only after a tap.
  final List<String> spoiler;

  const AnilistPersonNames({
    required this.display,
    this.full,
    this.native,
    this.alternative = const [],
    this.spoiler = const [],
  });

  static const String fields = '{ userPreferred full native alternative }';
  static const String characterFields = '{ userPreferred full native alternative alternativeSpoiler }';

  factory AnilistPersonNames.fromJson(Object? json) {
    if (json is! Map) return const AnilistPersonNames(display: '');
    final full = _strOrNull(json['full']);
    return AnilistPersonNames(
      display: _strOrNull(json['userPreferred']) ?? full ?? _strOrNull(json['native']) ?? '',
      full: full,
      native: _strOrNull(json['native']),
      alternative: _strings(json['alternative']),
      spoiler: _strings(json['alternativeSpoiler']),
    );
  }
}

/// A character, staff member or studio as a list row shows it.
@immutable
class AnilistPersonRef {
  final int id;
  final String name;
  final String? imageUrl;

  /// The voice actor's language (`languageV2`), when known.
  final String? language;

  /// Favourites count, when the query asked for it.
  final int? favourites;

  const AnilistPersonRef({
    required this.id,
    required this.name,
    this.imageUrl,
    this.language,
    this.favourites,
  });

  /// Query fragment: pass the node's name/image selection through [fields].
  static const String fields =
      'id name { userPreferred full native } image { medium } languageV2 favourites';

  /// [fields] for a character node: `Character` has no `languageV2`, and asking it makes
  /// AniList reject the whole request.
  static const String characterFields =
      'id name { userPreferred full native } image { medium } favourites';

  static AnilistPersonRef? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _int(json['id']);
    if (id == 0) return null;
    final image = json['image'];
    return AnilistPersonRef(
      id: id,
      name: AnilistPersonNames.fromJson(json['name']).display,
      imageUrl: image is Map ? image['medium'] as String? ?? image['large'] as String? : null,
      language: _strOrNull(json['languageV2']),
      favourites: (json['favourites'] as num?)?.toInt(),
    );
  }
}

/// A title as a character, staff or studio page lists it.
@immutable
class AnilistPeopleMedia {
  final int id;

  /// `anime` or `manga`.
  final String category;
  final String title;
  final String? coverUrl;
  final String? format;
  final int? year;
  final String? status;

  /// The signed-in user's list status for it (`mediaListEntry.status`), when on their list.
  final String? listStatus;

  const AnilistPeopleMedia({
    required this.id,
    required this.category,
    required this.title,
    this.coverUrl,
    this.format,
    this.year,
    this.status,
    this.listStatus,
  });

  static const String fields = '''
    id type format status seasonYear startDate { year }
    title { userPreferred } coverImage { large } mediaListEntry { status }
  ''';

  static AnilistPeopleMedia? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _int(json['id']);
    if (id == 0) return null;
    final title = json['title'];
    final cover = json['coverImage'];
    final entry = json['mediaListEntry'];
    final start = json['startDate'];
    return AnilistPeopleMedia(
      id: id,
      category: json['type'] == 'MANGA' ? 'manga' : 'anime',
      title: title is Map ? (title['userPreferred'] as String? ?? '') : '',
      coverUrl: cover is Map ? cover['large'] as String? : null,
      format: _strOrNull(json['format']),
      year: (json['seasonYear'] as num?)?.toInt() ??
          (start is Map ? (start['year'] as num?)?.toInt() : null),
      status: _strOrNull(json['status']),
      listStatus: entry is Map ? _strOrNull(entry['status']) : null,
    );
  }
}

/// One title a character appears in, with its role and voice actors.
@immutable
class AnilistAppearance {
  final AnilistPeopleMedia media;

  /// `MAIN`, `SUPPORTING` or `BACKGROUND`.
  final String? role;
  final List<AnilistPersonRef> voiceActors;

  const AnilistAppearance({required this.media, this.role, this.voiceActors = const []});
}

/// A character a staff member voiced in a title.
@immutable
class AnilistVoiceRole {
  final AnilistPeopleMedia media;
  final String? role;
  final List<AnilistPersonRef> characters;

  const AnilistVoiceRole({required this.media, this.role, this.characters = const []});
}

/// A production role of a staff member in a title (`staffRole`: "Director", "Script"…).
@immutable
class AnilistStaffRole {
  final AnilistPeopleMedia media;
  final String? role;

  const AnilistStaffRole({required this.media, this.role});
}

/// A studio's production, with whether the studio is its main one.
@immutable
class AnilistStudioWork {
  final AnilistPeopleMedia media;
  final bool isMain;

  const AnilistStudioWork({required this.media, this.isMain = false});
}

/// One page of a paged answer.
@immutable
class AnilistPeoplePage<T> {
  final List<T> items;
  final bool hasNext;

  const AnilistPeoplePage(this.items, {this.hasNext = false});
}

@immutable
class AnilistCharacterDetail {
  final int id;
  final AnilistPersonNames names;
  final String? imageUrl;

  /// HTML (`asHtml: true`), spoilers as AniList's spoiler markup.
  final String? descriptionHtml;
  final String? gender;
  final String? age;
  final String? bloodType;
  final AnilistFuzzyDate? birthday;
  final int favourites;
  final bool isFavourite;

  const AnilistCharacterDetail({
    required this.id,
    required this.names,
    this.imageUrl,
    this.descriptionHtml,
    this.gender,
    this.age,
    this.bloodType,
    this.birthday,
    this.favourites = 0,
    this.isFavourite = false,
  });

  AnilistCharacterDetail copyWith({bool? isFavourite, int? favourites}) => AnilistCharacterDetail(
        id: id,
        names: names,
        imageUrl: imageUrl,
        descriptionHtml: descriptionHtml,
        gender: gender,
        age: age,
        bloodType: bloodType,
        birthday: birthday,
        favourites: favourites ?? this.favourites,
        isFavourite: isFavourite ?? this.isFavourite,
      );

  static AnilistCharacterDetail? fromJson(Object? json) {
    if (json is! Map) return null;
    final image = json['image'];
    return AnilistCharacterDetail(
      id: _int(json['id']),
      names: AnilistPersonNames.fromJson(json['name']),
      imageUrl: image is Map ? image['large'] as String? : null,
      descriptionHtml: _strOrNull(json['description']),
      gender: _strOrNull(json['gender']),
      age: _strOrNull(json['age']),
      bloodType: _strOrNull(json['bloodType']),
      birthday: AnilistFuzzyDate.fromJson(json['dateOfBirth']),
      favourites: _int(json['favourites']),
      isFavourite: json['isFavourite'] == true,
    );
  }
}

@immutable
class AnilistStaffDetail {
  final int id;
  final AnilistPersonNames names;
  final String? imageUrl;
  final String? descriptionHtml;
  final String? language;
  final List<String> occupations;
  final String? gender;
  final int? age;
  final String? bloodType;
  final AnilistFuzzyDate? birthday;
  final AnilistFuzzyDate? death;

  /// One year (still active from then) or two (from, to).
  final List<int> yearsActive;
  final String? homeTown;
  final int favourites;
  final bool isFavourite;

  const AnilistStaffDetail({
    required this.id,
    required this.names,
    this.imageUrl,
    this.descriptionHtml,
    this.language,
    this.occupations = const [],
    this.gender,
    this.age,
    this.bloodType,
    this.birthday,
    this.death,
    this.yearsActive = const [],
    this.homeTown,
    this.favourites = 0,
    this.isFavourite = false,
  });

  AnilistStaffDetail copyWith({bool? isFavourite, int? favourites}) => AnilistStaffDetail(
        id: id,
        names: names,
        imageUrl: imageUrl,
        descriptionHtml: descriptionHtml,
        language: language,
        occupations: occupations,
        gender: gender,
        age: age,
        bloodType: bloodType,
        birthday: birthday,
        death: death,
        yearsActive: yearsActive,
        homeTown: homeTown,
        favourites: favourites ?? this.favourites,
        isFavourite: isFavourite ?? this.isFavourite,
      );

  static AnilistStaffDetail? fromJson(Object? json) {
    if (json is! Map) return null;
    final image = json['image'];
    final years = json['yearsActive'];
    return AnilistStaffDetail(
      id: _int(json['id']),
      names: AnilistPersonNames.fromJson(json['name']),
      imageUrl: image is Map ? image['large'] as String? : null,
      descriptionHtml: _strOrNull(json['description']),
      language: _strOrNull(json['languageV2']),
      occupations: _strings(json['primaryOccupations']),
      gender: _strOrNull(json['gender']),
      age: (json['age'] as num?)?.toInt(),
      bloodType: _strOrNull(json['bloodType']),
      birthday: AnilistFuzzyDate.fromJson(json['dateOfBirth']),
      death: AnilistFuzzyDate.fromJson(json['dateOfDeath']),
      yearsActive: years is List ? [for (final y in years) if (y is num) y.toInt()] : const [],
      homeTown: _strOrNull(json['homeTown']),
      favourites: _int(json['favourites']),
      isFavourite: json['isFavourite'] == true,
    );
  }
}

@immutable
class AnilistStudioDetail {
  final int id;
  final String name;
  final bool isAnimationStudio;
  final int favourites;
  final bool isFavourite;

  const AnilistStudioDetail({
    required this.id,
    required this.name,
    this.isAnimationStudio = true,
    this.favourites = 0,
    this.isFavourite = false,
  });

  AnilistStudioDetail copyWith({bool? isFavourite, int? favourites}) => AnilistStudioDetail(
        id: id,
        name: name,
        isAnimationStudio: isAnimationStudio,
        favourites: favourites ?? this.favourites,
        isFavourite: isFavourite ?? this.isFavourite,
      );

  static AnilistStudioDetail? fromJson(Object? json) {
    if (json is! Map) return null;
    return AnilistStudioDetail(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
      isAnimationStudio: json['isAnimationStudio'] != false,
      favourites: _int(json['favourites']),
      isFavourite: json['isFavourite'] == true,
    );
  }
}

/// How the titles of a character, a staff member or a studio are sorted (`MediaSort`).
enum AnilistPeopleSort {
  popularity('POPULARITY_DESC'),
  startDate('START_DATE_DESC'),
  score('SCORE_DESC');

  const AnilistPeopleSort(this.value);
  final String value;
}

/// AniList's characters, staff and studios: the three people pages, their favourite toggles
/// and the home loaders (birthdays today, most favourited). Reads carry the token when an
/// account is signed in (`isFavourite`, `mediaListEntry` and the "on my list" filter need it).
class AnilistPeopleService {
  AnilistPeopleService({AnilistGraphql? client, AnilistActions? actions, bool? signedIn})
      : _client = client,
        _actions = actions,
        _signedIn = signedIn;

  /// The service every page uses; tests replace it.
  static AnilistPeopleService instance = AnilistPeopleService();

  /// Rows a media page asks for.
  static const int pageSize = 25;

  final AnilistGraphql? _client;
  final AnilistActions? _actions;
  final bool? _signedIn;
  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;
  AnilistActions get _write => _actions ?? AnilistActions.instance;

  bool get signedIn => _signedIn ?? UserAnilistV2.instance.status == AuthStatus.AUTHENTICATED;

  Future<Map<String, dynamic>> _read(String query, Map<String, dynamic> variables) =>
      _gql.query(query, variables: variables, auth: signedIn);

  static bool _hasNext(Object? page) {
    if (page is! Map) return false;
    final info = page['pageInfo'];
    return info is Map && info['hasNextPage'] == true;
  }

  static List<Map> _edges(Object? connection) {
    if (connection is! Map) return const [];
    final edges = connection['edges'];
    return edges is List ? [for (final e in edges) if (e is Map) e] : const [];
  }

  // ---------------------------------------------------------------- character

  Future<AnilistCharacterDetail> character(int id) async {
    final data = await _read('''
      query (\$id: Int) {
        Character(id: \$id) {
          id name ${AnilistPersonNames.characterFields} image { large }
          description(asHtml: true) gender age bloodType dateOfBirth ${AnilistFuzzyDate.fields}
          favourites isFavourite
        }
      }
    ''', {'id': id});
    return AnilistCharacterDetail.fromJson(data['Character']) ??
        (throw const AnilistError(404, 'Character not found'));
  }

  /// The titles of the character of [type] (`ANIME` | `MANGA`) with the voice actors of
  /// [language] (a `StaffLanguage`, e.g. `JAPANESE`; manga has none).
  Future<AnilistPeoplePage<AnilistAppearance>> characterMedia(
    int id, {
    required String type,
    int page = 1,
    AnilistPeopleSort sort = AnilistPeopleSort.popularity,
    bool onList = false,
    String language = 'JAPANESE',
  }) async {
    final voices = type == 'ANIME'
        ? 'voiceActors(language: \$language) { ${AnilistPersonRef.fields} }'
        : '';
    final data = await _read('''
      query (\$id: Int, \$page: Int, \$perPage: Int, \$type: MediaType,
          \$sort: [MediaSort], \$onList: Boolean${type == 'ANIME' ? ', \$language: StaffLanguage' : ''}) {
        Character(id: \$id) {
          media(page: \$page, perPage: \$perPage, type: \$type, sort: \$sort, onList: \$onList) {
            pageInfo { hasNextPage }
            edges { characterRole node { ${AnilistPeopleMedia.fields} } $voices }
          }
        }
      }
    ''', {
      'id': id,
      'page': page,
      'perPage': pageSize,
      'type': type,
      'sort': [sort.value],
      'onList': onList ? true : null,
      if (type == 'ANIME') 'language': language,
    });
    final media = (data['Character'] as Map?)?['media'];
    final items = <AnilistAppearance>[];
    for (final edge in _edges(media)) {
      final node = AnilistPeopleMedia.fromJson(edge['node']);
      if (node == null) continue;
      final actors = edge['voiceActors'];
      items.add(AnilistAppearance(
        media: node,
        role: _strOrNull(edge['characterRole']),
        voiceActors: _refs(actors),
      ));
    }
    return AnilistPeoplePage(items, hasNext: _hasNext(media));
  }

  // ---------------------------------------------------------------- staff

  Future<AnilistStaffDetail> staff(int id) async {
    final data = await _read('''
      query (\$id: Int) {
        Staff(id: \$id) {
          id name ${AnilistPersonNames.fields} languageV2 image { large }
          description(asHtml: true) primaryOccupations gender age bloodType
          dateOfBirth ${AnilistFuzzyDate.fields} dateOfDeath ${AnilistFuzzyDate.fields}
          yearsActive homeTown favourites isFavourite
        }
      }
    ''', {'id': id});
    return AnilistStaffDetail.fromJson(data['Staff']) ??
        (throw const AnilistError(404, 'Staff not found'));
  }

  /// The characters the staff member voiced, one row per title.
  Future<AnilistPeoplePage<AnilistVoiceRole>> staffVoiceRoles(
    int id, {
    int page = 1,
    AnilistPeopleSort sort = AnilistPeopleSort.startDate,
    bool onList = false,
  }) async {
    final data = await _read('''
      query (\$id: Int, \$page: Int, \$perPage: Int, \$sort: [MediaSort], \$onList: Boolean) {
        Staff(id: \$id) {
          characterMedia(page: \$page, perPage: \$perPage, sort: \$sort, onList: \$onList) {
            pageInfo { hasNextPage }
            edges {
              characterRole
              node { ${AnilistPeopleMedia.fields} }
              characters { id name { userPreferred full native } image { medium } }
            }
          }
        }
      }
    ''', {
      'id': id,
      'page': page,
      'perPage': pageSize,
      'sort': [sort.value],
      'onList': onList ? true : null,
    });
    final media = (data['Staff'] as Map?)?['characterMedia'];
    final items = <AnilistVoiceRole>[];
    for (final edge in _edges(media)) {
      final node = AnilistPeopleMedia.fromJson(edge['node']);
      if (node == null) continue;
      final characters = edge['characters'];
      items.add(AnilistVoiceRole(
        media: node,
        role: _strOrNull(edge['characterRole']),
        characters: _refs(characters),
      ));
    }
    return AnilistPeoplePage(items, hasNext: _hasNext(media));
  }

  /// The production roles of the staff member.
  Future<AnilistPeoplePage<AnilistStaffRole>> staffRoles(
    int id, {
    int page = 1,
    AnilistPeopleSort sort = AnilistPeopleSort.startDate,
    bool onList = false,
  }) async {
    final data = await _read('''
      query (\$id: Int, \$page: Int, \$perPage: Int, \$sort: [MediaSort], \$onList: Boolean) {
        Staff(id: \$id) {
          staffMedia(page: \$page, perPage: \$perPage, sort: \$sort, onList: \$onList) {
            pageInfo { hasNextPage }
            edges { staffRole node { ${AnilistPeopleMedia.fields} } }
          }
        }
      }
    ''', {
      'id': id,
      'page': page,
      'perPage': pageSize,
      'sort': [sort.value],
      'onList': onList ? true : null,
    });
    final media = (data['Staff'] as Map?)?['staffMedia'];
    final items = <AnilistStaffRole>[];
    for (final edge in _edges(media)) {
      final node = AnilistPeopleMedia.fromJson(edge['node']);
      if (node == null) continue;
      items.add(AnilistStaffRole(media: node, role: _strOrNull(edge['staffRole'])));
    }
    return AnilistPeoplePage(items, hasNext: _hasNext(media));
  }

  // ---------------------------------------------------------------- studio

  Future<AnilistStudioDetail> studio(int id) async {
    final data = await _read(
      'query (\$id: Int) { Studio(id: \$id) { id name isAnimationStudio favourites isFavourite } }',
      {'id': id},
    );
    return AnilistStudioDetail.fromJson(data['Studio']) ??
        (throw const AnilistError(404, 'Studio not found'));
  }

  /// The productions of the studio. AniList's `START_DATE_DESC` puts undated titles first:
  /// they are moved after the dated ones of the page.
  Future<AnilistPeoplePage<AnilistStudioWork>> studioMedia(
    int id, {
    int page = 1,
    AnilistPeopleSort sort = AnilistPeopleSort.startDate,
    bool mainOnly = false,
    bool onList = false,
  }) async {
    final data = await _read('''
      query (\$id: Int, \$page: Int, \$perPage: Int, \$sort: [MediaSort], \$isMain: Boolean,
          \$onList: Boolean) {
        Studio(id: \$id) {
          media(page: \$page, perPage: \$perPage, sort: \$sort, isMain: \$isMain, onList: \$onList) {
            pageInfo { hasNextPage }
            edges { isMainStudio node { ${AnilistPeopleMedia.fields} } }
          }
        }
      }
    ''', {
      'id': id,
      'page': page,
      'perPage': pageSize,
      'sort': [sort.value],
      'isMain': mainOnly ? true : null,
      'onList': onList ? true : null,
    });
    final media = (data['Studio'] as Map?)?['media'];
    final items = <AnilistStudioWork>[];
    for (final edge in _edges(media)) {
      final node = AnilistPeopleMedia.fromJson(edge['node']);
      if (node == null) continue;
      items.add(AnilistStudioWork(media: node, isMain: edge['isMainStudio'] == true));
    }
    if (sort == AnilistPeopleSort.startDate) {
      items.sort((a, b) => (a.media.year == null ? 1 : 0).compareTo(b.media.year == null ? 1 : 0));
    }
    return AnilistPeoplePage(items, hasNext: _hasNext(media));
  }

  // ---------------------------------------------------------------- favourites

  /// Adds the item to the favourites, or removes it (the caller flips what it shows).
  Future<void> toggleFavourite(AnilistFavouriteKind kind, int id) =>
      _write.toggleFavourite(kind, id);

  // ---------------------------------------------------------------- home loaders

  Future<AnilistPeoplePage<AnilistPersonRef>> _people(
    String field,
    String args,
    int page,
    int perPage,
  ) async {
    final data = await _read('''
      query (\$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { hasNextPage }
          $field($args) { ${field == 'characters' ? AnilistPersonRef.characterFields : AnilistPersonRef.fields} }
        }
      }
    ''', {'page': page, 'perPage': perPage});
    final result = data['Page'];
    final rows = result is Map ? result[field] : null;
    return AnilistPeoplePage(
      _refs(rows),
      hasNext: _hasNext(result),
    );
  }

  /// Characters born today, the most favourited first (home row).
  Future<AnilistPeoplePage<AnilistPersonRef>> birthdayCharacters({int page = 1, int perPage = 20}) =>
      _people('characters', 'isBirthday: true, sort: FAVOURITES_DESC', page, perPage);

  /// Staff born today, the most favourited first (home row).
  Future<AnilistPeoplePage<AnilistPersonRef>> birthdayStaff({int page = 1, int perPage = 20}) =>
      _people('staff', 'isBirthday: true, sort: FAVOURITES_DESC', page, perPage);

  /// The most favourited characters of all time.
  Future<AnilistPeoplePage<AnilistPersonRef>> topCharacters({int page = 1, int perPage = 20}) =>
      _people('characters', 'sort: FAVOURITES_DESC', page, perPage);

  /// The most favourited staff of all time.
  Future<AnilistPeoplePage<AnilistPersonRef>> topStaff({int page = 1, int perPage = 20}) =>
      _people('staff', 'sort: FAVOURITES_DESC', page, perPage);
}
