import 'package:equatable/equatable.dart';
import 'package:mywatchlist/user/preferences/content_card_props.dart';
import 'package:mywatchlist/user/preferences/json_read.dart';

/// Category the user list opens on (DAL `defaultTab`).
enum ListCategory { none, anime, manga }

/// User list preferences (DAL "List preferences").
class ListPreferences extends Equatable {
  /// Value of [defaultAnimeTab] / [defaultMangaTab] when no tab is forced.
  static const String noDefaultTab = 'none';

  /// [ListCategory.none] keeps the list's own choice.
  final ListCategory defaultCategory;

  /// Status tab the anime (manga) list opens on, as a MAL list status (`watching`, `all`…)
  /// or [noDefaultTab].
  final String defaultAnimeTab;
  final String defaultMangaTab;

  /// Custom card layouts of the list; empty = the built-in display types only.
  final List<ContentCardProps> cardProfiles;

  const ListPreferences({
    this.defaultCategory = ListCategory.none,
    this.defaultAnimeTab = noDefaultTab,
    this.defaultMangaTab = noDefaultTab,
    this.cardProfiles = const [],
  });

  ListPreferences copyWith({
    ListCategory? defaultCategory,
    String? defaultAnimeTab,
    String? defaultMangaTab,
    List<ContentCardProps>? cardProfiles,
  }) =>
      ListPreferences(
        defaultCategory: defaultCategory ?? this.defaultCategory,
        defaultAnimeTab: defaultAnimeTab ?? this.defaultAnimeTab,
        defaultMangaTab: defaultMangaTab ?? this.defaultMangaTab,
        cardProfiles: cardProfiles != null ? List.unmodifiable(cardProfiles) : this.cardProfiles,
      );

  /// The card profile with [id], or null.
  ContentCardProps? cardProfile(String id) {
    for (final profile in cardProfiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'defaultCategory': defaultCategory.name,
        'defaultAnimeTab': defaultAnimeTab,
        'defaultMangaTab': defaultMangaTab,
        'cardProfiles': cardProfiles.map((e) => e.toJson()).toList(),
      };

  factory ListPreferences.fromJson(Map<String, dynamic> json) {
    const d = ListPreferences();
    return ListPreferences(
      defaultCategory: readEnum(json, 'defaultCategory', ListCategory.values, d.defaultCategory),
      defaultAnimeTab: readString(json, 'defaultAnimeTab', d.defaultAnimeTab),
      defaultMangaTab: readString(json, 'defaultMangaTab', d.defaultMangaTab),
      cardProfiles: List.unmodifiable(
          readMapList(json, 'cardProfiles').map(ContentCardProps.fromJson)),
    );
  }

  @override
  List<Object?> get props => [defaultCategory, defaultAnimeTab, defaultMangaTab, cardProfiles];
}
