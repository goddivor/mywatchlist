// lib/widgets/review/review_filters.dart (suite)

enum ReviewSortType {
  dateDesc,
  dateAsc,
  scoreDesc,
  scoreAsc
}

enum ReviewFilterType {
  recommended,
  mixedFeelings,
  notRecommended,
  nice,
  loveIt,
  funny,
  confusing,
  informative,
  wellWritten,
  creative,
  preliminary,
  spoiler
}

extension ReviewFilterTypeExtension on ReviewFilterType {
  String get displayName {
    switch (this) {
      case ReviewFilterType.recommended:
        return 'Recommandé';
      case ReviewFilterType.mixedFeelings:
        return 'Avis mitigé';
      case ReviewFilterType.notRecommended:
        return 'Non recommandé';
      case ReviewFilterType.nice:
        return 'Nice';
      case ReviewFilterType.loveIt:
        return 'Love it';
      case ReviewFilterType.funny:
        return 'Funny';
      case ReviewFilterType.confusing:
        return 'Confusing';
      case ReviewFilterType.informative:
        return 'Informative';
      case ReviewFilterType.wellWritten:
        return 'Well-written';
      case ReviewFilterType.creative:
        return 'Creative';
      case ReviewFilterType.preliminary:
        return 'Preliminary';
      case ReviewFilterType.spoiler:
        return 'Spoiler';
    }
  }
}