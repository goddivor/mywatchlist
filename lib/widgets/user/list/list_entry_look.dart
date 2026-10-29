import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// A score as one tracker writes it: the [text] on the card ("8", "88%", "3.5", "Good"), an
/// optional [icon] that replaces the card's default one, and what a screen reader says.
@immutable
class ListScoreText {
  final String text;

  /// Null keeps the icon of the place that draws it (a star, the "my score" person).
  final IconData? icon;

  /// Read by screen readers instead of [text] ("3.5 stars"); null = [text].
  final String? spoken;

  const ListScoreText(this.text, {this.icon, this.spoken});

  @override
  bool operator ==(Object other) =>
      other is ListScoreText && other.text == text && other.icon == icon && other.spoken == spoken;

  @override
  int get hashCode => Object.hash(text, icon, spoken);
}

/// A small tracker-specific mark on a card (the user's Kitsu reaction): an [icon], a short
/// [label] for the rows that have room, and the full [detail] for tooltips and screen readers.
@immutable
class ListCardBadge {
  final IconData icon;
  final String label;
  final String detail;

  const ListCardBadge({required this.icon, required this.label, required this.detail});

  @override
  bool operator ==(Object other) =>
      other is ListCardBadge && other.icon == icon && other.label == label && other.detail == detail;

  @override
  int get hashCode => Object.hash(icon, label, detail);
}

/// How one tracker words and draws its list entries: status names, the user's score, the
/// community score and the card badges. `UserListAdapter` extends it, so every adapter
/// overrides the hooks it needs; the defaults are MyAnimeList's wording and 0-10 scores.
///
/// The cards read it through [ListEntryLookScope.of]: a list built outside a `UserListTab`
/// (seasons, profile sections) keeps the defaults.
class ListEntryLook {
  const ListEntryLook();

  /// Name of [status] on the tabs, the status pills and the screen-reader labels.
  String statusLabel(ListEntryStatus status, {required bool isAnime}) =>
      status.label(isAnime: isAnime);

  /// Short code of [status] in the grid card's status chip ("CW", "CMP").
  String statusShortLabel(ListEntryStatus status, {required bool isAnime}) =>
      status.shortLabel(isAnime: isAnime);

  /// The user's own score of [entry], null when not scored.
  ListScoreText? userScore(ListEntryView entry) => entry.score > 0
      ? ListScoreText('${entry.score}', spoken: S.current.UserList_My_Score_Value(entry.score))
      : null;

  /// The community score of [entry], null when unknown.
  ListScoreText? meanScore(ListEntryView entry) {
    final mean = entry.meanScore;
    if (mean == null || mean <= 0) return null;
    return ListScoreText(mean.toStringAsFixed(2));
  }

  /// Tracker-specific marks of [entry] (none by default).
  List<ListCardBadge> cardBadges(ListEntryView entry) => const [];
}

/// Gives the cards below it the [look] of the tracker whose list they belong to.
class ListEntryLookScope extends InheritedWidget {
  final ListEntryLook look;

  const ListEntryLookScope({super.key, required this.look, required super.child});

  /// The nearest scope's look, MyAnimeList's defaults when there is none.
  static ListEntryLook of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ListEntryLookScope>()?.look ?? const ListEntryLook();

  @override
  bool updateShouldNotify(ListEntryLookScope oldWidget) => !identical(look, oldWidget.look);
}
