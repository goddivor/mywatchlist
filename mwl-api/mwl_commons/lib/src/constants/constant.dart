/// Content type for anime/manga and related categories.
enum ContentType { anime, manga, character, characters, people, news, featured }

/// Shared API endpoint constants for MyWatchList.
class Constants {
  Constants._();

  // MAL API v2
  static const String malEndPoint = 'https://api.myanimelist.net/v2/';
  static const String malClientHeader = 'X-MAL-Client-ID';

  // Jikan API v4
  static const String jikanV4 = 'https://api.jikan.moe/v4/';

  // Tenrai: free MyAnimeList API following Jikan v4's schema, used when Jikan
  // is down (public tier, no key).
  static const String tenraiV1 = 'https://api.tenrai.org/v1/';

  // MAL website (for HTML scraping)
  static const String malBaseUrl = 'https://myanimelist.net';
  static const String malnewsUrl = '$malBaseUrl/news';
  static const String malfeaturedUrl = '$malBaseUrl/featured';

  /// Fields for anime details requests (MAL API v2).
  static const String animeFields =
      '?fields=id,title,main_picture,alternative_titles,ending_themes,opening_themes,'
      'start_date,end_date,synopsis,mean,rank,popularity,num_list_users,'
      'num_scoring_users,nsfw,created_at,updated_at,media_type,status,genres,'
      'my_list_status{is_rewatching,is_rereading,num_times_rewatched,num_times_reread,'
      'priority,rewatch_value,reread_value,start_date,finish_date,tags,comments},'
      'num_episodes,start_season,broadcast,source,average_episode_duration,rating,'
      'pictures,background,related_anime{mean,num_list_users},'
      'related_manga,recommendations{mean,num_list_users},studios,statistics';

  /// Fields for manga details requests (MAL API v2).
  static const String mangaFields =
      '?fields=id,title,main_picture,alternative_titles,start_date,end_date,'
      'synopsis,mean,rank,popularity,num_list_users,num_scoring_users,nsfw,'
      'created_at,updated_at,media_type,status,genres,'
      'my_list_status{is_rewatching,is_rereading,num_times_rewatched,num_times_reread,'
      'priority,rewatch_value,reread_value,start_date,finish_date,tags,comments},'
      'num_volumes,num_chapters,authors{first_name,last_name},pictures,background,'
      'related_anime,related_manga{mean,num_list_users},'
      'recommendations{mean,num_list_users},serialization{name}';
}

/// Log function for backend (no Flutter dependency).
void logMwl(dynamic message) {
  print('[MWL-API] $message');
}

/// Generate a CDN asset URL for streaming/platform logos.
String getDomainAsset(String e, [String domain = 'streaming']) =>
    'https://dailyanimelist.web.app/assets/$domain/${e.trim()}.png';
