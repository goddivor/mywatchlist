// lib/widgets/review/review_filters.dart

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
  funny,
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
        return 'Recommended';
      case ReviewFilterType.mixedFeelings:
        return 'Mixed Feelings';
      case ReviewFilterType.notRecommended:
        return 'Not Recommended';
      case ReviewFilterType.funny:
        return 'Funny';
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