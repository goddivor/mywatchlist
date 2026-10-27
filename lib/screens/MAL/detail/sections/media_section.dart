import 'package:flutter/widgets.dart';
import 'package:mywatchlist/constants/constants.dart' show SB, TabType;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/content/media_platforms.dart';
import 'package:mywatchlist/widgets/MAL/content/videowidget.dart';

/// Streaming / resource links, then videos and theme songs (anime only).
DetailSection? mediaSection(DetailData data) {
  final visible = data.isManga
      ? !data.isStreamingBlank
      : (data.hasContent && !data.isAnimeVideosBlank) || !data.isStreamingBlank;
  if (!visible) return null;
  return DetailSection(TabType.Media, _mediaBody(data));
}

Widget _mediaBody(DetailData data) {
  final platforms = AddtionalMediaPlatforms(
    data.links,
    relatedLinks: data.scheduleLinks,
  );
  final videos = VideosWidget(
    videos: data.videos,
    horizPadding: detailHorizPadding,
    endingSongs: data.content?.endingSongs,
    openingSongs: data.content?.openingSongs,
  );
  if (data.isAnimeVideosBlank) return platforms;
  if (data.isStreamingBlank) return videos;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [platforms, SB.h20, videos],
  );
}
