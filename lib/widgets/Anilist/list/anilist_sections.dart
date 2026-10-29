import 'package:flutter/foundation.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_status.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart' show mediaTypeLabel;

/// What a tab of the AniList list holds.
enum AnilistSectionKind { all, status, custom }

/// One tab of the AniList list, as anilist.co draws the list: All, then the sections in the
/// account's `sectionOrder` (Watching, Rewatching, Completed, possibly split by format,
/// Paused, Dropped, Planning, and the custom lists).
@immutable
class AnilistSection {
  final AnilistSectionKind kind;

  /// The AniList status of a status section (CURRENT, REPEATING…).
  final String? status;

  /// The media format of a split Completed section (TV, MOVIE…), null = every format.
  final String? format;

  /// The custom list name of a custom section.
  final String? customList;

  const AnilistSection._(this.kind, {this.status, this.format, this.customList});

  static const AnilistSection all = AnilistSection._(AnilistSectionKind.all);

  const AnilistSection.status(String status, {String? format})
      : this._(AnilistSectionKind.status, status: status, format: format);

  const AnilistSection.custom(String name)
      : this._(AnilistSectionKind.custom, customList: name);

  /// Stable key (saved as the last opened tab).
  String get key => switch (kind) {
        AnilistSectionKind.all => 'all',
        AnilistSectionKind.status => format == null ? 'status:$status' : 'status:$status:$format',
        AnilistSectionKind.custom => 'custom:$customList',
      };

  /// The shared status of the section, for the status badge and the status cache.
  ListEntryStatus? get listStatus => kind == AnilistSectionKind.status ? anilistStatus(status) : null;

  /// Whether the section is one status only (cards then hide the status badge).
  bool get isStatus => kind == AnilistSectionKind.status;

  String label({required bool isAnime}) => switch (kind) {
        AnilistSectionKind.all => S.current.UserList_All,
        AnilistSectionKind.custom => customList!,
        AnilistSectionKind.status => format == null
            ? anilistStatusLabel(status, isAnime: isAnime)
            : S.current.Alf_Completed_Format(anilistFormatLabel(format!)),
      };

  /// Whether [detail] is listed in this section. Entries hidden from the status lists only
  /// show in All and in their custom lists, as on anilist.co.
  bool contains(AnilistListEntry detail) => switch (kind) {
        AnilistSectionKind.all => true,
        AnilistSectionKind.custom => detail.customLists.contains(customList),
        AnilistSectionKind.status => !detail.hiddenFromStatusLists &&
            detail.status == status &&
            (format == null || anilistFormatGroup(detail.format) == format),
      };

  @override
  bool operator ==(Object other) => other is AnilistSection && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// AniList's media formats in the order of its split Completed sections.
const List<String> anilistFormatOrder = [
  'TV', 'TV_SHORT', 'MOVIE', 'SPECIAL', 'OVA', 'ONA', 'MUSIC', 'MANGA', 'NOVEL', 'ONE_SHOT',
];

/// The format a split Completed section groups [format] under (unknown formats together).
String anilistFormatGroup(String? format) =>
    format != null && anilistFormatOrder.contains(format) ? format : 'OTHER';

/// Translated name of an AniList format.
String anilistFormatLabel(String format) => switch (format) {
      'TV_SHORT' => S.current.Alf_Format_Tv_Short,
      'OTHER' => S.current.Alf_Format_Other,
      _ => mediaTypeLabel(anilistMediaType(format) ?? format.toLowerCase()),
    };

/// AniList's names of the status sections in `sectionOrder`, per category.
String? _statusOfSectionName(String name, {required bool isAnime}) => switch (name) {
      'Watching' when isAnime => 'CURRENT',
      'Reading' when !isAnime => 'CURRENT',
      'Rewatching' when isAnime => 'REPEATING',
      'Rereading' when !isAnime => 'REPEATING',
      'Completed' => 'COMPLETED',
      'Paused' => 'PAUSED',
      'Dropped' => 'DROPPED',
      'Planning' => 'PLANNING',
      _ => null,
    };

/// AniList's default order when the account has none.
const List<String> _defaultStatusOrder = [
  'CURRENT', 'REPEATING', 'COMPLETED', 'PAUSED', 'DROPPED', 'PLANNING',
];

/// The tabs of one category: All first, then the account's section order. Status sections
/// missing from that order follow in AniList's default order, then the custom lists that are
/// not in it. Rewatching shows only when it has entries; with "split completed by format"
/// Completed becomes one section per format present.
List<AnilistSection> anilistSections(
  AnilistListOptions options,
  Iterable<AnilistListEntry> details, {
  required bool isAnime,
}) {
  final statuses = <String>[];
  final order = <Object>[]; // a status (String) or a custom list (AnilistSection)
  for (final name in options.sectionOrder) {
    final status = _statusOfSectionName(name, isAnime: isAnime);
    if (status != null) {
      if (!statuses.contains(status)) {
        statuses.add(status);
        order.add(status);
      }
    } else if (options.customLists.contains(name) &&
        !order.contains(AnilistSection.custom(name))) {
      order.add(AnilistSection.custom(name));
    }
  }
  for (final s in _defaultStatusOrder) {
    if (!statuses.contains(s)) {
      statuses.add(s);
      order.add(s);
    }
  }
  for (final name in options.customLists) {
    final section = AnilistSection.custom(name);
    if (!order.contains(section)) order.add(section);
  }

  final list = details.toList();
  final out = <AnilistSection>[AnilistSection.all];
  for (final item in order) {
    if (item is AnilistSection) {
      out.add(item);
      continue;
    }
    final status = item as String;
    if (status == 'REPEATING' &&
        !list.any((d) => d.status == 'REPEATING' && !d.hiddenFromStatusLists)) {
      continue;
    }
    if (status == 'COMPLETED' && options.splitCompletedSectionByFormat) {
      final formats = {
        for (final d in list)
          if (d.status == 'COMPLETED' && !d.hiddenFromStatusLists) anilistFormatGroup(d.format),
      };
      final ordered = [
        for (final f in [...anilistFormatOrder, 'OTHER'])
          if (formats.contains(f)) f,
      ];
      if (ordered.isNotEmpty) {
        out.addAll([for (final f in ordered) AnilistSection.status(status, format: f)]);
        continue;
      }
    }
    out.add(AnilistSection.status(status));
  }
  return out;
}

/// Entries of each section of [sections] among [details].
Map<AnilistSection, int> anilistSectionCounts(
        List<AnilistSection> sections, Iterable<AnilistListEntry> details) =>
    {for (final s in sections) s: details.where(s.contains).length};
