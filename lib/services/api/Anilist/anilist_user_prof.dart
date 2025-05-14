/// A class representing a user's profile on Anilist.
class AnilistUserProf {
  /// The unique ID of the user.
  final int id;

  /// The name of the user.
  final String name;

  /// The URL of the user's avatar image.
  final String avatarUrl;

  /// The URL of the user's banner image (optional).
  final String? bannerImage;

  /// A brief description or bio of the user (optional).
  final String? about;

  /// Indicates whether the current user is following this user.
  final bool isFollowing;

  /// Indicates whether this user is blocked.
  final bool isBlocked;

  /// A list of bans associated with the user.
  final List<String> bans;

  /// Constructor for creating an instance of [AnilistUserProf].
  AnilistUserProf({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.bannerImage,
    this.about,
    required this.isFollowing,
    required this.isBlocked,
    required this.bans,
  });

  /// Factory constructor to create an [AnilistUserProf] instance from a JSON object.
  ///
  /// Parses the JSON data and maps it to the corresponding fields of the class.
  factory AnilistUserProf.fromJson(Map<String, dynamic> json) {
    return AnilistUserProf(
      id: json['id'], // Maps the 'id' field from JSON.
      name: json['name'], // Maps the 'name' field from JSON.
      avatarUrl: json['avatar']['large'], // Maps the 'avatar' field's 'large' property from JSON.
      bannerImage: json['bannerImage'], // Maps the 'bannerImage' field from JSON.
      about: json['about'], // Maps the 'about' field from JSON.
      isFollowing: json['isFollowing'], // Maps the 'isFollowing' field from JSON.
      isBlocked: json['isBlocked'], // Maps the 'isBlocked' field from JSON.
      bans: List<String>.from(json['bans']), // Converts the 'bans' field to a list of strings.
    );
  }
}
