import 'package:flutter/widgets.dart';
import 'package:mywatchlist/constants/constants.dart' show SB, TabType, nullOrEmpty;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_videos.dart';
import 'package:mywatchlist/widgets/MAL/content/media_platforms.dart';
import 'package:mywatchlist/widgets/MAL/content/videowidget.dart';

/// Streaming / resource links, then videos and theme songs (anime only).
/// Without Jikan's videos, the PV of the scraped MAL page stands in.
DetailSection? mediaSection(DetailData data) {
  final videos = mediaVideos(data);
  final videosBlank = _videosBlank(data, videos);
  final visible = data.isManga
      ? !data.isStreamingBlank
      : (data.hasContent && !videosBlank) || !data.isStreamingBlank;
  if (!visible) return null;
  return DetailSection(TabType.Media, _mediaBody(data, videos, videosBlank));
}

/// Jikan's videos, or the MAL page's promotion video (`html['trailer']`)
/// when Jikan has no promo to show (down, or nothing listed).
AnimeVideos? mediaVideos(DetailData data) {
  final jikan = data.videos;
  if (data.isManga || !nullOrEmpty(jikan?.promo)) return jikan;
  final trailer = data.html?['trailer'];
  if (trailer is! Map) return jikan;
  final url = trailer['url'];
  if (url is! String || url.trim().isEmpty) return jikan;
  final title = trailer['title'];
  final promo = PromoVideo(
    title: title is String && title.trim().isNotEmpty ? title.trim() : null,
    trailer: _trailerOf(url.trim()),
  );
  return AnimeVideos(
    promo: [promo],
    episodes: jikan?.episodes,
    musicVideos: jikan?.musicVideos,
  );
}

/// MAL links YouTube embeds (`youtube-nocookie.com/embed/<id>?…`): the tile
/// builds the watch URL and thumbnail from it; any other link opens as is.
Trailer _trailerOf(String url) =>
    url.contains('/embed/') ? Trailer(embedUrl: url) : Trailer(url: url);

bool _videosBlank(DetailData data, AnimeVideos? videos) {
  if (videos == null && data.content == null) return true;
  return nullOrEmpty(videos?.episodes) &&
      nullOrEmpty(videos?.musicVideos) &&
      nullOrEmpty(videos?.promo) &&
      nullOrEmpty(data.content?.openingSongs) &&
      nullOrEmpty(data.content?.endingSongs);
}

Widget _mediaBody(DetailData data, AnimeVideos? videos, bool videosBlank) {
  final platforms = AddtionalMediaPlatforms(
    data.links,
    relatedLinks: data.scheduleLinks,
  );
  final videoWidget = VideosWidget(
    videos: videos,
    fallbackImageUrl: data.coverUrl,
    horizPadding: detailHorizPadding,
    endingSongs: data.content?.endingSongs,
    openingSongs: data.content?.openingSongs,
  );
  if (videosBlank) return platforms;
  if (data.isStreamingBlank) return videoWidget;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [platforms, SB.h20, videoWidget],
  );
}
