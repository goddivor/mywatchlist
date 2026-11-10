import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';

/// AniList's score formats (`ScoreFormat`). Scores are stored as a raw 0-100 value
/// (`scoreRaw`); each format shows and takes it on its own scale.
enum AnilistScoreFormat {
  /// 0-100.
  point100('POINT_100'),

  /// 0-10 with one decimal (7.5).
  point10Decimal('POINT_10_DECIMAL'),

  /// 0-10, whole points.
  point10('POINT_10'),

  /// 1-5 stars.
  point5('POINT_5'),

  /// 1-3 smileys (sad, neutral, happy).
  point3('POINT_3');

  const AnilistScoreFormat(this.value);

  /// The GraphQL `ScoreFormat` value.
  final String value;

  /// Unknown or missing values read as POINT_10 (AniList's default).
  static AnilistScoreFormat parse(Object? value) =>
      values.where((f) => f.value == value).firstOrNull ?? point10;

  /// Highest value of the scale.
  double get max => switch (this) {
        point100 => 100,
        point10Decimal || point10 => 10,
        point5 => 5,
        point3 => 3,
      };

  /// Step of the input.
  double get step => this == point10Decimal ? 0.1 : 1;

  /// Advanced scores exist for these two formats only (AniList hides them for the others).
  bool get allowsAdvanced => this == point100 || this == point10Decimal;

  /// [raw] (0-100) on this scale; 0 = not scored.
  double fromRaw(int raw) {
    if (raw <= 0) return 0;
    return switch (this) {
      point100 => raw.toDouble(),
      point10Decimal => raw / 10,
      point10 => (raw / 10).round().toDouble(),
      // AniList: 1 star from 1, 5 stars from 90.
      point5 => ((raw + 10) / 20).floor().clamp(1, 5).toDouble(),
      // AniList: sad up to 35, neutral up to 60, happy above.
      point3 => raw <= 35
          ? 1
          : raw <= 60
              ? 2
              : 3,
    };
  }

  /// [value] on this scale as AniList's raw 0-100; 0 = not scored.
  int toRaw(double value) {
    if (value <= 0) return 0;
    return switch (this) {
      point100 => value.round().clamp(0, 100),
      point10Decimal => (value * 10).round().clamp(0, 100),
      point10 => (value.round() * 10).clamp(0, 100),
      point5 => (value.round() * 20).clamp(0, 100),
      point3 => switch (value.round()) {
          1 => 35,
          2 => 60,
          _ => 85,
        },
    };
  }

  /// [raw] written the way AniList shows it in this format (`7.5`, `73`, `4`); empty when
  /// not scored. Stars and smileys are drawn by the widgets, this is their number.
  String format(int raw) {
    final v = fromRaw(raw);
    if (v <= 0) return '';
    return this == point10Decimal ? v.toStringAsFixed(1).replaceAll('.0', '') : '${v.round()}';
  }
}

/// AniList `FuzzyDateInput` of a `yyyy-MM-dd` / `yyyy-MM` / `yyyy` text; an empty map (every
/// part null) clears the date, as AniList's own editor does.
Map<String, int?> anilistFuzzyDate(String? date) {
  final parts = (date ?? '').split('-');
  int? at(int i) => i < parts.length ? int.tryParse(parts[i]) : null;
  return {'year': at(0), 'month': at(1), 'day': at(2)};
}

/// Every field `SaveMediaListEntry` takes (16). A null field is not sent, so AniList keeps
/// what it has: a quick +1 sends the progress alone and never touches the score.
@immutable
class AnilistEntryInput {
  /// The list entry id (an existing entry) and the media id (create or update).
  final int? id;
  final int? mediaId;

  /// `MediaListStatus`: CURRENT, PLANNING, COMPLETED, DROPPED, PAUSED, REPEATING.
  final String? status;

  /// Score on the user's own scale (`score`); [scoreRaw] (0-100) is preferred.
  final double? score;
  final int? scoreRaw;
  final int? progress;
  final int? progressVolumes;
  final int? repeat;
  final int? priority;
  final bool? private;
  final String? notes;
  final bool? hiddenFromStatusLists;

  /// The custom lists the entry is on (every other custom list is left).
  final List<String>? customLists;

  /// One value per advanced scoring category, in the user's category order.
  final List<double>? advancedScores;

  /// `yyyy-MM-dd` text; '' clears the date.
  final String? startedAt;
  final String? completedAt;

  const AnilistEntryInput({
    this.id,
    this.mediaId,
    this.status,
    this.score,
    this.scoreRaw,
    this.progress,
    this.progressVolumes,
    this.repeat,
    this.priority,
    this.private,
    this.notes,
    this.hiddenFromStatusLists,
    this.customLists,
    this.advancedScores,
    this.startedAt,
    this.completedAt,
  }) : assert(id != null || mediaId != null);

  /// GraphQL types of the arguments, in AniList's order.
  static const Map<String, String> types = {
    'id': 'Int',
    'mediaId': 'Int',
    'status': 'MediaListStatus',
    'score': 'Float',
    'scoreRaw': 'Int',
    'progress': 'Int',
    'progressVolumes': 'Int',
    'repeat': 'Int',
    'priority': 'Int',
    'private': 'Boolean',
    'notes': 'String',
    'hiddenFromStatusLists': 'Boolean',
    'customLists': '[String]',
    'advancedScores': '[Float]',
    'startedAt': 'FuzzyDateInput',
    'completedAt': 'FuzzyDateInput',
  };

  /// The variables to send: only the fields that are set.
  Map<String, Object?> toVariables() => {
        if (id != null) 'id': id,
        if (mediaId != null) 'mediaId': mediaId,
        if (status != null) 'status': status,
        if (score != null) 'score': score,
        if (scoreRaw != null) 'scoreRaw': scoreRaw,
        if (progress != null) 'progress': progress,
        if (progressVolumes != null) 'progressVolumes': progressVolumes,
        if (repeat != null) 'repeat': repeat,
        if (priority != null) 'priority': priority,
        if (private != null) 'private': private,
        if (notes != null) 'notes': notes,
        if (hiddenFromStatusLists != null) 'hiddenFromStatusLists': hiddenFromStatusLists,
        if (customLists != null) 'customLists': customLists,
        if (advancedScores != null) 'advancedScores': advancedScores,
        if (startedAt != null) 'startedAt': anilistFuzzyDate(startedAt),
        if (completedAt != null) 'completedAt': anilistFuzzyDate(completedAt),
      };
}

/// The fields `UpdateMediaListEntries` changes on several entries at once (bulk edit). Null
/// fields are not sent.
@immutable
class AnilistBulkInput {
  final String? status;
  final int? scoreRaw;
  final int? priority;
  final bool? private;
  final bool? hiddenFromStatusLists;

  const AnilistBulkInput({
    this.status,
    this.scoreRaw,
    this.priority,
    this.private,
    this.hiddenFromStatusLists,
  });

  bool get isEmpty =>
      status == null &&
      scoreRaw == null &&
      priority == null &&
      private == null &&
      hiddenFromStatusLists == null;

  Map<String, Object?> toVariables() => {
        if (status != null) 'status': status,
        if (scoreRaw != null) 'scoreRaw': scoreRaw,
        if (priority != null) 'priority': priority,
        if (private != null) 'private': private,
        if (hiddenFromStatusLists != null) 'hiddenFromStatusLists': hiddenFromStatusLists,
      };

  static const Map<String, String> types = {
    'status': 'MediaListStatus',
    'scoreRaw': 'Int',
    'priority': 'Int',
    'private': 'Boolean',
    'hiddenFromStatusLists': 'Boolean',
  };
}

/// Writes to the signed-in user's AniList list, through [AnilistGraphql.mutate] (signed in,
/// sent once, behind the shared rate limiter). Each call answers the entries as AniList
/// holds them afterwards, in the selection of [entryFields].
class AnilistListWrite {
  AnilistListWrite({AnilistGraphql? client}) : _client = client;

  static AnilistListWrite instance = AnilistListWrite();

  final AnilistGraphql? _client;
  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;

  /// What every write answers: the list fields of the entry (same names as the list read).
  static const String entryFields = '''
    id mediaId status progress progressVolumes repeat priority private notes
    hiddenFromStatusLists updatedAt createdAt
    scoreRaw: score(format: POINT_100)
    score(format: POINT_10_DECIMAL)
    customLists(asArray: true) advancedScores
    startedAt { year month day }
    completedAt { year month day }
  ''';

  /// Creates or updates one entry with the set fields of [input]; answers the saved entry.
  Future<Map<String, dynamic>> save(AnilistEntryInput input) async {
    final vars = input.toVariables();
    final names = [
      for (final k in AnilistEntryInput.types.keys)
        if (vars.containsKey(k)) k
    ];
    final declared = names.map((n) => '\$$n: ${AnilistEntryInput.types[n]}').join(', ');
    final args = names.map((n) => '$n: \$$n').join(', ');
    final data = await _gql.mutate(
      'mutation ($declared) { SaveMediaListEntry($args) { $entryFields } }',
      variables: vars,
    );
    final saved = data['SaveMediaListEntry'];
    if (saved is! Map<String, dynamic>) throw const AnilistError(200, 'No entry in the answer');
    return saved;
  }

  /// Deletes the list entry [entryId] (not the media id). True when AniList deleted it.
  Future<bool> delete(int entryId) async {
    final data = await _gql.mutate(
      r'mutation ($id: Int) { DeleteMediaListEntry(id: $id) { deleted } }',
      variables: {'id': entryId},
    );
    return (data['DeleteMediaListEntry'] as Map?)?['deleted'] == true;
  }

  /// Applies [input] to every list entry of [entryIds] in one request.
  Future<List<Map<String, dynamic>>> updateMany(
      List<int> entryIds, AnilistBulkInput input) async {
    if (entryIds.isEmpty || input.isEmpty) return const [];
    final vars = {...input.toVariables(), 'ids': entryIds};
    final names = [
      for (final k in AnilistBulkInput.types.keys)
        if (vars.containsKey(k)) k
    ];
    final declared = [
      for (final n in names) '\$$n: ${AnilistBulkInput.types[n]}',
      r'$ids: [Int]',
    ].join(', ');
    final args = [for (final n in names) '$n: \$$n', r'ids: $ids'].join(', ');
    final data = await _gql.mutate(
      'mutation ($declared) { UpdateMediaListEntries($args) { $entryFields } }',
      variables: vars,
    );
    return [
      for (final e in (data['UpdateMediaListEntries'] as List? ?? const []))
        if (e is Map<String, dynamic>) e,
    ];
  }
}
