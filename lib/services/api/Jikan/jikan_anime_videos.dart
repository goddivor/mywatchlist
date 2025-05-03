class AnimeVideos {
  final List<PromoVideo>? promo;
  final List<EpisodeVideo>? episodes;
  final List<MusicVideo>? musicVideos;

  AnimeVideos({
    this.promo,
    this.episodes,
    this.musicVideos,
  });

  factory AnimeVideos.fromJson(Map<String, dynamic> json) {
    return AnimeVideos(
      promo: json['promo'] != null
          ? (json['promo'] as List).map((e) => PromoVideo.fromJson(e)).toList()
          : null,
      episodes: json['episodes'] != null
          ? (json['episodes'] as List).map((e) => EpisodeVideo.fromJson(e)).toList()
          : null,
      musicVideos: json['music_videos'] != null
          ? (json['music_videos'] as List).map((e) => MusicVideo.fromJson(e)).toList()
          : null,
    );
  }
}

class PromoVideo {
  final String? title;
  final Trailer? trailer;

  PromoVideo({
    this.title,
    this.trailer,
  });

  factory PromoVideo.fromJson(Map<String, dynamic> json) {
    return PromoVideo(
      title: json['title'],
      trailer: json['trailer'] != null ? Trailer.fromJson(json['trailer']) : null,
    );
  }
}

class Trailer {
  final String? youtubeId;
  final String? url;
  final String? embedUrl;
  final TrailerImages? images;

  Trailer({
    this.youtubeId,
    this.url,
    this.embedUrl,
    this.images,
  });

  factory Trailer.fromJson(Map<String, dynamic> json) {
    return Trailer(
      youtubeId: json['youtube_id'],
      url: json['url'],
      embedUrl: json['embed_url'],
      images: json['images'] != null ? TrailerImages.fromJson(json['images']) : null,
    );
  }
}

class TrailerImages {
  final String? imageUrl;
  final String? smallImageUrl;
  final String? mediumImageUrl;
  final String? largeImageUrl;
  final String? maximumImageUrl;

  TrailerImages({
    this.imageUrl,
    this.smallImageUrl,
    this.mediumImageUrl,
    this.largeImageUrl,
    this.maximumImageUrl,
  });

  factory TrailerImages.fromJson(Map<String, dynamic> json) {
    return TrailerImages(
      imageUrl: json['image_url'],
      smallImageUrl: json['small_image_url'],
      mediumImageUrl: json['medium_image_url'],
      largeImageUrl: json['large_image_url'],
      maximumImageUrl: json['maximum_image_url'],
    );
  }
}

class EpisodeVideo {
  final int? malId;
  final String? url;
  final String? title;
  final String? episode;
  final Images? images;

  EpisodeVideo({
    this.malId,
    this.url,
    this.title,
    this.episode,
    this.images,
  });

  factory EpisodeVideo.fromJson(Map<String, dynamic> json) {
    return EpisodeVideo(
      malId: json['mal_id'],
      url: json['url'],
      title: json['title'],
      episode: json['episode'],
      images: json['images'] != null ? Images.fromJson(json['images']) : null,
    );
  }
}

class Images {
  final ImageFormat? jpg;

  Images({this.jpg});

  factory Images.fromJson(Map<String, dynamic> json) {
    return Images(
      jpg: json['jpg'] != null ? ImageFormat.fromJson(json['jpg']) : null,
    );
  }
}

class ImageFormat {
  final String? imageUrl;

  ImageFormat({this.imageUrl});

  factory ImageFormat.fromJson(Map<String, dynamic> json) {
    return ImageFormat(
      imageUrl: json['image_url'],
    );
  }
}

class MusicVideo {
  final String? title;
  final Trailer? video;
  final Meta? meta;

  MusicVideo({
    this.title,
    this.video,
    this.meta,
  });

  factory MusicVideo.fromJson(Map<String, dynamic> json) {
    return MusicVideo(
      title: json['title'],
      video: json['video'] != null ? Trailer.fromJson(json['video']) : null,
      meta: json['meta'] != null ? Meta.fromJson(json['meta']) : null,
    );
  }
}

class Meta {
  final String? title;
  final String? author;

  Meta({
    this.title,
    this.author,
  });

  factory Meta.fromJson(Map<String, dynamic> json) {
    return Meta(
      title: json['title'],
      author: json['author'],
    );
  }
}
