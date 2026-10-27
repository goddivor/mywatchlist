import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_videos.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/MAL/content/media_platforms.dart';

/// Load state of the main MyAnimeList details (the scraped page and the
/// videos are optional extras and never block the screen).
enum DetailLoadState { loading, loaded, failed }

/// Immutable snapshot of everything the detail screen knows about one
/// anime/manga. The screen replaces it with [copyWith] each time a source
/// answers; the parsed lists below are computed once per snapshot, not on
/// every build.
@immutable
class DetailData {
  final int id;

  /// `anime` or `manga`.
  final String category;

  /// The card the user tapped (title and cover shown while loading).
  final Anime? node;
  final String? heroTag;

  /// MyAnimeList API details; null while loading or after a failure.
  final MalAnime? content;

  /// Scraped MAL page (`MwlApi.getAnimeDetailedHtml`): adaptations,
  /// characters, staff, interest stacks, links.
  final Map<String, dynamic>? html;

  /// Jikan videos (anime only).
  final AnimeVideos? videos;

  /// Related links of the airing schedule. Never filled yet: the
  /// `detail-synopsis-media` unit wires it (`_scheduleData` bug).
  final RelatedLinks? scheduleLinks;

  final DetailLoadState state;

  /// Error of the last failed MyAnimeList load.
  final Object? error;

  DetailData({
    required this.id,
    required this.category,
    this.node,
    this.heroTag,
    this.content,
    this.html,
    this.videos,
    this.scheduleLinks,
    this.state = DetailLoadState.loading,
    this.error,
  });

  DetailData copyWith({
    MalAnime? content,
    Map<String, dynamic>? html,
    AnimeVideos? videos,
    DetailLoadState? state,
    Object? error,
  }) {
    return DetailData(
      id: id,
      category: category,
      node: node,
      heroTag: heroTag,
      content: content ?? this.content,
      html: html ?? this.html,
      videos: videos ?? this.videos,
      scheduleLinks: scheduleLinks,
      state: state ?? this.state,
      error: error,
    );
  }

  bool get isManga => category == 'manga';
  bool get isAnime => !isManga;
  bool get hasContent => content != null;

  /// Title used by section links (forum, featured articles).
  String get title => content?.title ?? node?.title ?? '';

  /// Cover of the tapped card first (it is already in the image cache),
  /// then the API cover.
  String get coverUrl {
    final nodeUrl = node?.imageUrl;
    if (nodeUrl != null && nodeUrl.isNotEmpty) return nodeUrl;
    return content?.mainPicture?.large ?? '';
  }

  /// Cover then every API picture, for the zoomable gallery.
  late final List<String> galleryUrls = [
    coverUrl,
    ...?content?.pictures?.map((e) => e.large).whereType<String>(),
  ];

  late final List<AdaptNode> adaptations =
      _parseList(html?['adaptation'], AdaptNode.fromJson);

  late final List<CharactersVoiceActors> charactersVoiceActors =
      _parseList(html?['charactersVoiceActors'], CharactersVoiceActors.fromJson);

  late final List<MangaCharacters> mangaCharacters =
      _parseList(html?['mangaCharacters'], MangaCharacters.fromJson);

  late final List<CharacterNode> staff =
      _parseList(html?['staff'], CharacterNode.fromJson);

  late final List<InterestStack> interestStacks =
      _parseList(html?['interestStacks'], InterestStack.fromJson);

  /// Streaming, "available at" and resource links of the scraped page.
  late final List<AnimeLink> links = _parseLinks();

  bool get isAnimeVideosBlank {
    if (videos == null && content == null) return true;
    return nullOrEmpty(videos?.episodes) &&
        nullOrEmpty(videos?.musicVideos) &&
        nullOrEmpty(videos?.promo) &&
        nullOrEmpty(content?.openingSongs) &&
        nullOrEmpty(content?.endingSongs);
  }

  bool get isStreamingBlank {
    return html == null ||
        (nullOrEmpty(html!['availableAt']) &&
            nullOrEmpty(html!['resources']) &&
            nullOrEmpty(html!['streamingPlatforms']));
  }

  static List<T> _parseList<T>(
      dynamic raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw is! List) return const [];
    final result = <T>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) result.add(fromJson(item));
    }
    return result;
  }

  List<AnimeLink> _parseLinks() {
    final source = html;
    if (source == null) return const [];
    final links = <AnimeLink>[];
    void add(dynamic list, LinkType type) {
      if (list is! List) return;
      for (final item in list) {
        if (item is! Map) continue;
        final name = item['name']?.toString();
        final url = item['url']?.toString();
        if (name == null || url == null || name.isEmpty || url.isEmpty) {
          continue;
        }
        links.add(AnimeLink(
          name: name,
          url: url,
          imageUrl: item['imageUrl']?.toString(),
          linkType: type,
        ));
      }
    }

    add(source['availableAt'], LinkType.availableAt);
    add(source['resources'], LinkType.resources);
    add(source['streamingPlatforms'], LinkType.streaming);
    return links;
  }
}
