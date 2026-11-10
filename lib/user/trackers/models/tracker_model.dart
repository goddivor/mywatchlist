import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// Static facts about one tracker: brand name (never translated), logo, brand color and
/// the one-line pitch. The state of the account lives in the user singletons.
class TrackerInfo {
  final AccountType type;
  final String name;
  final String logoAsset;
  final Color color;

  const TrackerInfo._(this.type, this.name, this.logoAsset, this.color);

  static const TrackerInfo myAnimeList = TrackerInfo._(AccountType.myanimelist,
      'MyAnimeList', 'assets/images/mal-icon.png', Color(0xFF2E51A2));
  static const TrackerInfo aniList = TrackerInfo._(AccountType.anilist,
      'AniList', 'assets/images/anilist-icon.png', Color(0xFF02A9FF));
  static const TrackerInfo kitsu = TrackerInfo._(AccountType.kitsu, 'Kitsu',
      'assets/images/kitsu-icon.png', Color(0xFFEF5D5D));
  static const TrackerInfo simkl = TrackerInfo._(AccountType.simkl, 'Simkl',
      'assets/images/simkl-icon.png', Color(0xFFCA1960));

  /// The four trackers, in display order.
  static const List<TrackerInfo> all = [myAnimeList, aniList, kitsu, simkl];

  /// Info of [type]; null for [AccountType.none].
  static TrackerInfo? of(AccountType type) {
    for (final info in all) {
      if (info.type == type) return info;
    }
    return null;
  }

  /// Kitsu signs in with a username and a password; the others open their web sign in.
  bool get usesPassword => type == AccountType.kitsu;

  /// One line about the service, in the current language.
  String get description {
    switch (type) {
      case AccountType.myanimelist:
        return S.current.Acc_Desc_Mal;
      case AccountType.anilist:
        return S.current.Acc_Desc_Anilist;
      case AccountType.kitsu:
        return S.current.Acc_Desc_Kitsu;
      case AccountType.simkl:
        return S.current.Acc_Desc_Simkl;
      case AccountType.none:
        return '';
    }
  }
}
