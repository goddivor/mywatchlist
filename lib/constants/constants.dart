// ignore_for_file: deprecated_member_use, unnecessary_const, unnecessary_null_comparison, unnecessary_this, constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';
import 'dart:ui' as ui;

import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:mywatchlist/widgets/common/slivers.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

enum AccountType {
  none,
  myanimelist,
  anilist,
  kitsu,
  simkl,
}

enum ContentType { anime, manga, character, characters, people, news, featured }

enum DisplayType { list_vert, grid, list_horiz }

enum DisplaySubType { compact, comfortable, cover_only_grid, spacious, custom }

enum TitleLang { en, ja, ro }

class Constants {
  static const String chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890-._~';

  //myanimelist client id, secret and redirecturi
  static String malclientId = dotenv.env['MAL_CLIENT_ID'] ?? '';
  static String malClientSecret = dotenv.env['MAL_CLIENT_SECRET'] ?? '';
  static const String malredirectUri = 'com.teen.mywatchlist://myanimelist-callback';
  static const String malCallbackScheme = 'com.teen.mywatchlist';

  //anilist client id, secret and redirecturi
  static String anilistClientId = dotenv.env['ANILIST_CLIENT_ID'] ?? '';
  static String anilistClientSecret = dotenv.env['ANILIST_CLIENT_SECRET'] ?? '';
  static const String anilistRedirectUri = 'com.teen.mywatchlist://anilist-callback';
  static const String anilistCallbackScheme = 'com.teen.mywatchlist';

  //simkl client id, secret and redirecturi
  static String simklClientId = dotenv.env['SIMKL_CLIENT_ID'] ?? '';
  static String simklClientSecret = dotenv.env['SIMKL_CLIENT_SECRET'] ?? '';
  static const String simklRedirectUri = 'com.teen.mywatchlist://simkl-callback';
  static const String simklCallbackScheme = 'com.teen.mywatchlist';

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

Widget starField(
  String score, {
  double starHeight = 17.0,
  TextStyle? textStyle,
  bool useIcon = false,
}) {
  return Row(
    children: [
      if (useIcon)
        Icon(
          Icons.star,
          size: starHeight,
        )
      else
        SizedBox(
          height: starHeight,
          child: Image.asset("assets/images/star.png"),
        ),
      const SizedBox(
        width: 5,
      ),
      Text(
        score,
        style: textStyle,
      )
    ],
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
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }

  String? capitalise() {
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

Color getStatusColor(int index) {
  switch (index) {
    case 0:
      return Colors.green;
    case 1:
      return Colors.blue;
    case 2:
      return Colors.yellow;
    case 3:
      return Colors.red;
    case 4:
      return Colors.orange;
    default:
      return Colors.grey;
  }
}

Widget loadingError() {
  return Center(
    child: Stack(
      children: [
        const Center(
          child: SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              strokeWidth: .8,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation(Color(0xff757575)),
            ),
          ),
        ),
        _logoImage(),
      ],
    ),
  );
}

Center _logoImage([double? height = 50.0, double? width = 50.0]) {
  return Center(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(32.0),
      child: SizedBox(
        height: height,
        width: width,
        child: Image.asset("assets/images/mal-icon.png"),
      ),
    ),
  );
}

Widget loadingText(BuildContext context) {
  final shimmerColors = ShimmerColors.fromContext(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(15, 5, 15, 60),
    child: Shimmer.fromColors(
        baseColor: shimmerColors.baseColor,
        highlightColor: shimmerColors.highlightColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 20,
            ),
            Container(
              width: 200,
              height: 15,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: Theme.of(context).dividerColor),
            ),
            const SizedBox(
              height: 20,
            ),
            Container(
              width: 160,
              height: 15,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: Theme.of(context).dividerColor),
            ),
            const SizedBox(
              height: 20,
            ),
            Container(
              width: 300,
              height: 15,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: Theme.of(context).dividerColor),
            )
          ],
        )),
  );
}

Widget genresWidget(List<Genre> genres, String category, BuildContext context,
    {TextAlign textAlign = TextAlign.center}) {
  plainButtonBuild(Genre e, [String additional = '']) => PlainButton(
        onPressed: () => onGenrePress(e, category, context),
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 5),
        child: Text(
          convertGenre(e, category).replaceAll("_", " "),
          style: const TextStyle(fontSize: 12.0),
        ),
      );
  final length = genres.length;
  return RichText(
    textAlign: textAlign,
    text: TextSpan(
        children: genres.asMap().entries.map((e) {
      return TextSpan(
        children: [
          WidgetSpan(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: plainButtonBuild(e.value),
          )),
          if (length != (e.key + 1))
            WidgetSpan(
              child: SizedBox(
                width: 10.0,
                child: PlainButton(
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  child: const Text('·'),
                ),
              ),
            ),
        ],
      );
    }).toList()),
  );
}

String convertGenre(Genre g, [String category = "anime"]) {
  // var genres = category.equals("anime") ? Mal.animeGenres : Mal.mangaGenres;
  // var genre = genres[g.id];
  // if (genre == null) {
  // genre = g.name;
  // }
  return g.name;
}

void onGenrePress(Genre e, String category, BuildContext context) {
  // Navigate to the genre page
  // Navigator.push(
  //   context,
  //   MaterialPageRoute(
  //     builder: (context) => GenrePage(
  //       genre: e,
  //       category: category,
  //     ),
  //   ),
  // );
}

bool nullOrEmpty(dynamic list) {
  if (list == null) return true;
  if (list is! List) return true;
  if (list.isEmpty) return true;
  return false;
}

String formatText(String text) {
  // Remplace les retours à la ligne (\n) et les retours chariot (\r\n) par des espaces
  return text.replaceAll(RegExp(r'(\r\n|\n|\r)'), ' ');
}

extension ListExtension<T> on List<T> {
  T? tryAt([int index = 0]) {
    if (this == null) null;
    if (index < 0) return null;
    if (index >= length) return null;
    try {
      return elementAt(index);
    } catch (e) {
      return null;
    }
  }
}

Widget conditional({
  Key? key,
  required bool on,
  required Widget child,
  required Widget Function(Widget child) parent,
}) {
  if (on) {
    return parent(child);
  } else {
    return child;
  }
}

const invalidUserNames = ['MyAnimeList', 'removed-user'];

String displayTimeAgo(DateTime date, {bool numericDates = true}) {
  final date2 = DateTime.now();
  final difference = date2.difference(date);

  if ((difference.inDays / 365).floor() >= 2) {
    return '${(difference.inDays / 365).floor()} ${Intl.message(
      'years ago',
      name: 'years_ago',
      desc: '',
      args: [],
    )}';
  } else if ((difference.inDays / 365).floor() >= 1) {
    return (numericDates)
        ? Intl.message(
            'an year ago',
            name: 'year_ago',
            desc: '',
            args: [],
          )
        : Intl.message(
            'Last year',
            name: 'Last_year',
            desc: '',
            args: [],
          );
  } else if ((difference.inDays / 30).floor() >= 2) {
    return '${(difference.inDays / 30).floor()} ${Intl.message(
      'months ago',
      name: 'months_ago',
      desc: '',
      args: [],
    )}';
  } else if ((difference.inDays / 30).floor() >= 1) {
    return (numericDates)
        ? Intl.message(
            'a month ago',
            name: 'month_ago',
            desc: '',
            args: [],
          )
        : Intl.message(
            'Last month',
            name: 'Last_month',
            desc: '',
            args: [],
          );
  } else if ((difference.inDays / 7).floor() >= 2) {
    return '${(difference.inDays / 7).floor()}  ${Intl.message(
      'weeks ago',
      name: 'weeks_ago',
      desc: '',
      args: [],
    )}';
  } else if ((difference.inDays / 7).floor() >= 1) {
    return (numericDates)
        ? Intl.message(
            'a week ago',
            name: 'week_ago',
            desc: '',
            args: [],
          )
        : Intl.message(
            'Last week',
            name: 'Last_week',
            desc: '',
            args: [],
          );
  } else if (difference.inDays >= 2) {
    return '${difference.inDays}  ${Intl.message(
      'days ago',
      name: 'days_ago',
      desc: '',
      args: [],
    )}';
  } else if (difference.inDays >= 1) {
    return (numericDates)
        ? Intl.message(
            'a day ago',
            name: 'day_ago',
            desc: '',
            args: [],
          )
        : Intl.message(
            'Yesterday',
            name: 'Yesterday',
            desc: '',
            args: [],
          );
  } else if (difference.inHours >= 2) {
    return '${difference.inHours}  ${Intl.message(
      'hours ago',
      name: 'hours_ago',
      desc: '',
      args: [],
    )}';
  } else if (difference.inHours >= 1) {
    return Intl.message(
      'An hour ago',
      name: 'hour_ago',
      desc: '',
      args: [],
    );
  } else if (difference.inMinutes >= 2) {
    return '${difference.inMinutes}  ${Intl.message(
      'minutes ago',
      name: 'minutes_ago',
      desc: '',
      args: [],
    )}';
  } else if (difference.inMinutes >= 1) {
    return Intl.message(
      'a minute ago',
      name: 'minute_ago',
      desc: '',
      args: [],
    );
  } else if (difference.inSeconds >= 3) {
    return '${difference.inSeconds}  ${Intl.message(
      'seconds ago',
      name: 'seconds_ago',
      desc: '',
      args: [],
    )}';
  } else {
    return Intl.message(
      'Just now',
      name: 'Just_now',
      desc: '',
      args: [],
    );
  }
}

int getStatusColorInt(int i) {
  switch (i) {
    case 0:
      return Colors.green.value;
    case 1:
      return Colors.blue.value;
    case 2:
      return Colors.orange.value;
    case 3:
      return Colors.red.value;
    case 4:
      return Colors.brown.value;
    default:
      return Colors.grey.value;
  }
}

enum TabType {
  Synopsis,
  Media,
  Related,
  Adaptations,
  Reviews,
  Recommendations,
  Interest_Stacks,
  Characters,
  Forums,
  Pictures,
  Related_Anime,
  News,
  Featured_Articles,
  User_Updates,
  Stats,
  ScoreStats,
  More_Info,
}

Widget loadingGraph(BuildContext context) {
  final shimmerColors = ShimmerColors.fromContext(context);
  return Padding(
    padding: const EdgeInsets.all(15),
    child: Shimmer.fromColors(
      baseColor: shimmerColors.baseColor,
      highlightColor: shimmerColors.highlightColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(5, (index) {
          // Créer des barres de hauteurs variables pour simuler un graphique
          double height =
              (index + 1) * 40.0; // Chaque barre a une hauteur différente
          return Container(
            width: 20, // Largeur fixe des barres
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).dividerColor,
            ),
          );
        }),
      ),
    ),
  );
}

Widget wrapScrollTag({
  required int index,
  required Widget child,
  required AutoScrollController controller,
  Color? highlightColor,
}) {
  return AutoScrollTag(
      key: ValueKey(index),
      controller: controller,
      index: index,
      highlightColor: highlightColor,
      child: child);
}

Widget loadingInner() {
  return Center(
    child: Stack(
      children: [
        const Center(
          child: SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              strokeWidth: .8,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation(Color(0xff757575)),
            ),
          ),
        ),
        _logoImage()
      ],
    ),
  );
}

Color getAnimeStatusColor(String? status) {
  // Vérifie si le status existe dans la map
  if (myAnimeStatusIntMap.containsKey(status) && status != null) {
    // Récupère l'index correspondant au status
    int index = myAnimeStatusIntMap[status]!;
    // Utilise cet index pour obtenir la couleur correspondante
    return getStatusColor(index);
  } else {
    // Si le status n'existe pas, retourne une couleur par défaut (gris)
    return Colors.grey;
  }
}

Map<String, String> myAnimeStatusMap = {
  "watching": "Watching",
  "completed": "Completed",
  "on_hold": "On Hold",
  "dropped": "Dropped",
  "plan_to_watch": "Plan to Watch"
};

Map<String, int> myAnimeStatusIntMap = {
  "watching": 0,
  "completed": 1,
  "on_hold": 2,
  "dropped": 3,
  "plan_to_watch": 4
};

Widget loadingCenter({
  double? width,
  double containerSide = 20,
}) {
  return Center(
    child: SizedBox(
      width: containerSide,
      height: containerSide,
      child: CircularProgressIndicator(
        strokeWidth: width ?? 2,
      ),
    ),
  );
}

enum HomePageTileSize { xs, s, m, l, xl }

class TileSize {
  final double contentHeight;
  final double contentWidth;
  final double containerHeight;
  final double loadingContainerHeight;

  const TileSize({
    required this.contentHeight,
    required this.contentWidth,
    required this.containerHeight,
    required this.loadingContainerHeight,
  });
}

TileSize getTileSizeValues(HomePageTileSize size) {
  switch (size) {
    case HomePageTileSize.xs:
      return const TileSize(
        contentHeight: 104,
        contentWidth: 80,
        containerHeight: 187.6,
        loadingContainerHeight: 130,
      );
    case HomePageTileSize.s:
      return const TileSize(
        contentHeight: 130,
        contentWidth: 100,
        containerHeight: 215,
        loadingContainerHeight: 162.5,
      );
    case HomePageTileSize.m:
      return const TileSize(
        contentHeight: 160,
        contentWidth: 120,
        containerHeight: 237,
        loadingContainerHeight: 200,
      );
    case HomePageTileSize.l:
      return const TileSize(
        contentHeight: 200,
        contentWidth: 150,
        containerHeight: 280,
        loadingContainerHeight: 250,
      );
    case HomePageTileSize.xl:
      return const TileSize(
        contentHeight: 230,
        contentWidth: 172.93,
        containerHeight: 322,
        loadingContainerHeight: 287.5,
      );
  }
}

String getDomainAsset(String e, [String domain = 'streaming']) =>
    'https://dailyanimelist.web.app/assets/$domain/${e.trim()}.png';

void launchURLWithConfirmation(
  String url, {
  required BuildContext context,
}) async {
  var result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        S.current.Just_a_sec,
      ),
      content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.current.Url_open_conf),
            Text("$url"),
            Text(S.current.Continue),
          ]),
      actions: [
        PlainButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            Navigator.of(context, rootNavigator: true).pop(false);
          },
          child: Text(S.current.Copy),
        ),
        ..._yesOrNoButtons(context)
      ],
    ),
  );
  if (result ?? false) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotBlank) {
      launchURL(url);
    } else {
      // final widget = await DalPathUtils.handleUri(uri, context);
      // if (widget != null) {
      //   gotoPage(context: context, newPage: widget);
      // }
    }
  }
}

void launchURL(String url) async {
  try {
    await launch(url);
  } catch (e) {
    showToast("${S.current.Couldn_Launch} $url!");
  }
}

Future<void> showToast(String message, {Toast? toast}) async {
  await Fluttertoast.showToast(
      gravity: ToastGravity.CENTER,
      msg: message,
      toastLength: toast,
      backgroundColor: Colors.black,
      textColor: Colors.white);
}

List<Widget> _yesOrNoButtons(BuildContext context) {
  return [
    PlainButton(
      onPressed: () {
        Navigator.of(context, rootNavigator: true)
            .pop(false); // dismisses only the dialog and returns false
      },
      child: Text(S.current.No),
    ),
    ShadowButton(
      onPressed: () {
        Navigator.of(context, rootNavigator: true)
            .pop(true); // dismisses only the dialog and returns true
      },
      child: Text(S.current.Yes),
    ),
  ];
}

Future<bool> showConfirmationDialog({
  String alertTitle = "",
  String desc = "",
  required BuildContext context,
  List<Widget>? addtionalActions,
}) async {
  return await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: title(alertTitle, opacity: 1, fontSize: 14),
      content: title(desc, opacity: 1, fontSize: 14),
      actions: addtionalActions == null
          ? _yesOrNoButtons(context)
          : [
              ...addtionalActions,
              ..._yesOrNoButtons(context),
            ],
    ),
  );
}

// Dans constants.dart, ajouter cette extension
extension DateTimeExtension on DateTime {
  DateTime nextDateTime(int day) {
    return add(
      Duration(
        days: (day - weekday) % DateTime.daysPerWeek,
      ),
    );
  }

  DateTime nextDate(int day) {
    return DateFormat("yyyy-MM-dd")
        .parse(DateFormat("yyyy-MM-dd").format(nextDateTime(day)));
  }
}
