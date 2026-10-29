/// Where MAL takes a recommendation pair. The form is MAL's own page: its fields were not
/// captured from a signed-in session, so the app opens the page instead of posting a guessed
/// request.
class RecommendationWriteApi {
  const RecommendationWriteApi._();

  static const String _base = 'https://myanimelist.net';

  /// The page of the title's recommendations, where MAL offers its form to a signed-in member.
  static String pageUrl({required String category, required int id}) =>
      '$_base/${category == 'manga' ? 'manga' : 'anime'}/$id/_/userrecs';
}
