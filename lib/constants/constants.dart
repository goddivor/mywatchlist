// ignore_for_file: deprecated_member_use, unnecessary_const, unnecessary_null_comparison, unnecessary_this, constant_identifier_names

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'dart:ui' as ui;

import 'package:mywatchlist/widgets/shimmercolor.dart';
import 'package:mywatchlist/widgets/slivers.dart';

enum AccountType {
  none,
  myanimelist,
  anilist,
  kitsu,
  simkl,
}

enum LinkType {
  resources,
  availableAt,
  streaming,
  otherLists,
}

enum ContentType { anime, manga, character, characters, people, news, featured }

enum DisplayType { list_vert, grid, list_horiz }

enum DisplaySubType { compact, comfortable, cover_only_grid, spacious, custom }

enum TitleLang { en, ja, ro }

class Constants {
  static const String chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890-._~';

  //myanimelist client id and redirecturi
  static const String malclientId = '2954f0a5d477b5f83c468bad0d3f7052';
  static const String malredirectUri = 'mywatchlist://callback';

  //anilist client id, secret and redirecturi
  static const String anilistClientId = '19606';
  static const String anilistClientSecret =
      '9NzyEe0bYpVb6T7xfZowoW1XsG2fmU3qAoyGQLbd';
  static const String anilistRedirectUri = 'mywatchlist://callback';

  //simkl client id, secret and redirecturi
  static const String simklClientId =
      '651c592199dadfe077ad844067becd03c64bdb72d5e7be704c9b3a0ae179224d';
  static const String simklClientSecret =
      'cea29efcdef0ed917bc5250c37eb1cd29211b3e69710e74f5d58bab6b776e7e0';
  static const String simklRedirectUri = 'mywatchlist://callback';

  //myanimelist api endpoints...
  static const String malapiUrl = 'https://api.myanimelist.net/v2';
  static const String maloauthEndPoint =
      'https://myanimelist.net/v1/oauth2/authorize';
  static const String maltokenEndPoint =
      'https://myanimelist.net/v1/oauth2/token';
  static const String maluserEndPoint =
      'https://api.myanimelist.net/v2/users/@me';
  static const String maluserBaseEndPoint =
      'https://api.myanimelist.net/v2/users';
  static const String malanimeEndPoint = 'https://api.myanimelist.net/v2/anime';
  static const String malanimeRankingEndPoint =
      'https://api.myanimelist.net/v2/anime/ranking';
  static const String malmangaRankingEndPoint =
      'https://api.myanimelist.net/v2/manga/ranking';
  static const String malanimeSeasonalEndPoint =
      'https://api.myanimelist.net/v2/anime/season';
  static const String malanimeSuggestedEndPoint =
      'https://api.myanimelist.net/v2/anime/suggestions';
  static const String malmangaSuggestedEndPoint =
      'https://api.myanimelist.net/v2/manga/suggestions';

  //anilist api endpoints...
  static const String anilistOAuthEndPoint =
      'https://anilist.co/api/v2/oauth/authorize';
  static const String anilistTokenEndPoint =
      'https://anilist.co/api/v2/oauth/token';

  //simkl api endpoints...
  static const String simklapiUrl = 'https://api.simkl.com/';
  static const String simklOAuthEndPoint = 'https://simkl.com/oauth/authorize';
  static const String simklTokenEndPoint = 'https://api.simkl.com/oauth/token';
  static const String simkUserSettingEndPoint =
      'https://api.simkl.com/users/settings';

  //stantard things on all api
  static const String refreshToken = 'refreshToken';
  static const String expiresAt = 'expiresAt';

  //myanimelist scrapping endpoints...
  static const String malnewsUrl = 'https://myanimelist.net/news';
  static const String malfeaturedUrl = 'https://myanimelist.net/featured';
  static const String malfeaturedTagsUrl =
      'https://myanimelist.net/featured/tag';
  static const String malnewsTagsUrl = 'https://myanimelist.net/news/tag';
  static const String malanimeUrl = 'https://myanimelist.net/anime';
  static const String malmangaUrl = 'https://myanimelist.net/manga';
  static const String malanimeGenreUrl = 'https://myanimelist.net/anime/genre';
  static const String malanimeGenrephp = 'https://myanimelist.net/manga/genre';
  static const String malproducerUrl = 'https://myanimelist.net/anime/producer';
  static const String malmagazineUrl = 'https://myanimelist.net/manga/magazine';
  static const String maluserHistoryUrl = 'https://myanimelist.net/history';
  static const String maluserProfileUrl = 'https://myanimelist.net/profile';
  static const String malcharacterUrl = 'https://myanimelist.net/character.php';
  static const String malcdnEndPoint = "https://cdn.myanimelist.net/";

  static const String malclientHeader = 'X-MAL-CLIENT-ID';

  static const String jikanV4 = "https://api.jikan.moe/v4";
  static const String jikanV4anime = "https://api.jikan.moe/v4/anime";
  static const String jikanSeasonGetNow =
      "https://api.jikan.moe/v4/seasons/now";
  static const String jikanSeasonUpcoming =
      "https://api.jikan.moe/v4/seasons/upcoming";
  static const String jikanTopAnime = "https://api.jikan.moe/v4/top/anime";
  static const String jikanTopManga = "https://api.jikan.moe/v4/top/manga";

  static const String malAnimeFields =
      'id,title,main_picture,alternative_titles,ending_themes,opening_themes,start_date,end_date,synopsis,mean,rank,popularity,num_list_users,num_scoring_users,nsfw,created_at,updated_at,media_type,status,genres,my_list_status{is_rewatching,is_rereading,num_times_rewatched,num_times_reread,priority,rewatch_value,reread_value,start_date,finish_date,tags,comments},num_episodes,start_season,broadcast,source,average_episode_duration,rating,pictures,background,related_anime{my_list_status,mean,num_list_users},related_manga,recommendations{my_list_status,mean,num_list_users},studios,statistics';
}

Future<T?> gotoPage<T>(
    {required BuildContext context, required Widget newPage}) {
  return Navigator.push<T>(
    context,
    MaterialPageRoute(
      builder: (context) =>
          Directionality(textDirection: ui.TextDirection.ltr, child: newPage),
    ),
  );
}

Widget title(
  String? title, {
  double fontSize = 13,
  double opacity = 1,
  int? colorVal,
  TextOverflow? textOverflow,
  TextStyle? textStyle,
  FontStyle? fontStyle = FontStyle.normal,
  TextAlign? align = TextAlign.left,
  FontWeight? fontWeight = FontWeight.normal,
  bool selectable = false,
  double? scaleFactor,
}) {
  title = title ?? '';
  textStyle ??= TextStyle();
  if (selectable) {
    return SelectableText(
      title,
      textAlign: align,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: colorVal == null ? null : Color(colorVal).withOpacity(opacity),
      ),
    );
  } else {
    return Text(
      title,
      // overflow: TextOverflow.ellipsis,
      overflow: textOverflow,
      textAlign: align,
      textScaleFactor: scaleFactor,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: colorVal == null ? null : Color(colorVal).withOpacity(opacity),
      ),
    );
  }
}

Widget text(String? title, {double? fontSize}) {
  return Text(
    title ?? "",
    style: TextStyle(fontSize: fontSize ?? 16),
  );
}

Widget heading(String text,
    {double fontSize = 32, AlignmentGeometry alignment = Alignment.topLeft}) {
  return Container(
    alignment: alignment,
    padding: EdgeInsets.only(left: 20),
    child: title(text, opacity: 1, fontSize: fontSize),
  );
}

Widget cardLoading({
  double radius = 1.0,
  BorderRadius? borderRadius,
  double height = 150,
  double width = 100,
}) {
  return ShimmerColor(SizedBox(
    height: height,
    width: width,
    child: Material(
      borderRadius: borderRadius ?? BorderRadius.circular(radius),
    ),
  ));
}

Widget iconAndText(
  IconData iconData,
  String? text, {
  double width = 10.0,
  double fontSize = 13,
  int? colorVal,
  int? iconColorVal,
  double iconSize = 16,
  bool reverse = false,
  FontStyle? fontStyle = FontStyle.normal,
  MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
  MainAxisSize mainAxisSize = MainAxisSize.max,
  TextOverflow? overflow,
}) {
  final iconColor = iconColorVal ?? colorVal;
  var content = [
    Icon(
      iconData,
      size: iconSize,
      color: iconColor == null ? null : Color(iconColor),
    ),
    SizedBox(
      width: width,
    ),
    Text(
      text ?? '',
      style: TextStyle(
        fontSize: fontSize,
        color: colorVal == null ? null : Color(colorVal),
        fontStyle: fontStyle,
        overflow: overflow,
      ),
      textAlign: TextAlign.start,
    )
  ];
  if (reverse) {
    content = content.reversed.toList();
  }
  return Row(
    mainAxisAlignment: mainAxisAlignment,
    // alignment: WrapAlignment.center,
    mainAxisSize: mainAxisSize,
    children: content,
  );
}

/// SizedBOX & Sliver SizedBox
class SB {
  /// const SizedBox(height: 5)
  static const h5 = const SizedBox(height: 5);

  /// const SizedBox(height: 10)
  static const h10 = const SizedBox(height: 10);

  /// const SizedBox(height: 15)
  static var h15 = const SizedBox(height: 15);

  /// const SizedBox(height: 20)
  static const h20 = const SizedBox(height: 20);

  /// const SizedBox(height: 30)
  static const h30 = const SizedBox(height: 30);
  static const h35 = const SizedBox(height: 35);

  /// const SizedBox(height: 40)
  static const h40 = const SizedBox(height: 40);

  /// const SizedBox(height: 60)
  static const h60 = const SizedBox(height: 60);

  /// const SizedBox(height: 80)
  static const h80 = const SizedBox(height: 80);

  /// const SizedBox()
  static const z = const SizedBox();

  /// const SizedBox(height: 120)
  static const h120 = const SizedBox(height: 120);

  /// const SizedBox(height: 200)
  static const h200 = const SizedBox(height: 200);

  /// const SizedBox(width: 5)
  static const w5 = const SizedBox(width: 5);

  /// const SizedBox(width: 10)
  static const w10 = const SizedBox(width: 10);

  /// const SizedBox(width: 10)
  static const w15 = const SizedBox(width: 15);

  /// const SizedBox(width: 20)
  static const w20 = const SizedBox(width: 20);

  /// const SizedBox(width: 30)
  static const w30 = const SizedBox(width: 30);

  /// const SizedBox(width: 40)
  static const w40 = const SizedBox(width: 40);

  /// const SizedBox(width: 60)
  static const w60 = const SizedBox(width: 60);

  static const lz = const SliverWrapper(z);
  static const lh10 = const SliverWrapper(h10);
  static const lh20 = const SliverWrapper(h20);
  static const lh30 = const SliverWrapper(h30);
  static const lh35 = const SliverWrapper(h35);
  static const lh40 = const SliverWrapper(h40);
  static const lh60 = const SliverWrapper(h60);
  static const lh80 = const SliverWrapper(h80);
  static const lh120 = const SliverWrapper(h120);
  static const lw10 = const SliverWrapper(w10);
  static const lw20 = const SliverWrapper(w20);
  static const lw40 = const SliverWrapper(w40);
  static const lw60 = const SliverWrapper(w60);
}

Widget showNoContent({
  String? text,
  MainAxisAlignment mainAxisAlignment = MainAxisAlignment.center,
  CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
}) {
  text ??= S.current.No_Content;
  return Column(
    mainAxisAlignment: mainAxisAlignment,
    crossAxisAlignment: crossAxisAlignment,
    children: [
      const SizedBox(height: 20),
      Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13),
      ),
      const SizedBox(height: 20),
    ],
  );
}

Widget showNoContentSliver() {
  return SliverList(
    delegate: SliverChildListDelegate(
      [
        const SizedBox(height: 20),
        Text(
          S.current.No_Content,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13),
        ),
      ],
    ),
  );
}

Widget showEmptySliverWidget() {
  return SliverList(
    delegate: SliverChildListDelegate([]),
  );
}

extension StringExtension on String {
  static final RegExp numberRegExp = RegExp(r'\d');
  static final RegExp alphaDigitExp = RegExp('^[a-zA-Zd]\$');

  String substringToN(int n) {
    if (n >= this.length) {
      return this; // Return the original string if n is greater than or equal to the string's length.
    } else {
      return this.substring(0, n);
    }
  }

  String? capitalize() {
    if (this == null) return null;
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }

  String? capitalizeAll() {
    if (this == null) return null;
    var split = this.split(" ");
    var result = "";
    for (var str in split) {
      result += '${StringExtension(str).capitalize()} ';
    }
    return result.substring(0, result.length - 1);
  }

  String titleCase() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }

  bool equals(String? other) {
    if (other == null) return false;
    return compareTo(other) == 0;
  }

  bool notEquals(String? other) {
    return !equals(other);
  }

  bool equalsIgnoreCase(String? other) {
    if (other == null) return false;
    return toLowerCase().compareTo(other.toLowerCase()) == 0;
  }

  String? standardize() {
    return StringExtension(replaceAll("_", " ")).capitalize();
  }

  String? standardizeLower() {
    return replaceAll(" ", "_").toLowerCase();
  }

  String? toDate() {
    if (this == null) return null;
    return substring(0, indexOf(":") - 2);
  }

  bool isAlphaDigit() {
    return (alphaDigitExp.hasMatch(this));
  }

  bool isDigit() {
    return (numberRegExp.hasMatch(this));
  }

  String formattedTitleforSearch() {
    String formattedTitle = "";
    for (int i = 0; i < length; ++i) {
      if (this[i] == ".") {
        continue;
      }
      if (this[i] == " ") {
        formattedTitle += "_";
      } else {
        formattedTitle += this[i];
      }
    }
    return formattedTitle;
  }

  String? getFormattedTitleForHtml([bool includeDigits = false]) {
    if (this == null) return null;
    String formattedTitle = "";
    for (int i = 0; i < length; ++i) {
      if (includeDigits && codeUnitAt(i) ^ 0x30 <= 9) {
        formattedTitle += this[i];
      } else if (this[i].isAlphaDigit()) {
        formattedTitle += this[i];
      } else {
        formattedTitle += "_";
      }
    }
    return formattedTitle;
  }

  String? getOnlyDigits() {
    if (this == null) return null;
    String formattedTitle = "";
    for (int i = 0; i < length; ++i) {
      if (this[i].isDigit()) {
        formattedTitle += this[i];
      }
    }
    return formattedTitle;
  }

  String getAlphabets() {
    String output = "";
    for (int i = 0; i < length; ++i) {
      if (this[i].isAlphaDigit()) {
        output += this[i];
      }
    }
    return output;
  }

  int countAll(String string) {
    int count = 0;
    String current = this;
    while (current.contains(string)) {
      current = current.replaceFirst(string, "");
      count++;
    }
    return count;
  }

  bool get isBlank {
    return trim().equals("");
  }

  bool get isNotBlank {
    return !isBlank;
  }
}

const strList = <String>[];

bool shouldUpdateContent(
    {@required dynamic result, double timeinHoursD = 0, int timeinHours = 0}) {
  try {
    var lastUpdated = result is String
        ? DateTime.parse(result)
        : result is Map
            ? DateTime.parse(result['lastUpdated'])
            : result?.lastUpdated;
    return ((DateTime.now().difference(lastUpdated).inMinutes / 60.0) >=
        (timeinHoursD + timeinHours));
  } catch (e) {
    return false;
  }
}
