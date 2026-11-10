/// Where MAL takes a review. The form is MAL's own page (`myreviews.php`, linked from every
/// anime and manga page): its fields were not captured from a signed-in session, so the app
/// opens the page instead of posting a guessed request.
class ReviewWriteApi {
  const ReviewWriteApi._();

  static const String _base = 'https://myanimelist.net';

  /// The "write a review" page of an anime (`seriesid`) or a manga (`mid`), as the title's
  /// own page links it.
  static String writeUrl({required String category, required int id}) => category == 'manga'
      ? '$_base/myreviews.php?mid=$id&go=write'
      : '$_base/myreviews.php?seriesid=$id&go=write';
}
