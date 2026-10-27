/// App bar actions of the detail page, in order: search, bookmark toggle,
/// then the overflow menu (share, open in browser, More Info, search by
/// genre, customize sections).
///
/// Each action appears only when it can work: the bookmark needs a title,
/// the menu entries need their data, and the menu itself disappears when it
/// would be empty, so no button is ever dead.
library;

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, gotoPage;
import 'package:mywatchlist/enums.dart' show Mal;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/screens/MAL/detail/actions/more_info_modal.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/tabs_customizer.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/url_formatter.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/MAL/search/filtermodal.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_button.dart';
import 'package:mywatchlist/widgets/common/app_bar_menu.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';

/// Most genres put in the "search by genre" filter (as DailyAL).
const int maxGenreFilters = 5;

List<Widget> buildDetailActions(BuildContext context, DetailData data) {
  return [
    searchAction(context, data),
    ...[
      bookmarkAction(context, data),
      overflowMenuAction(context, data),
    ].whereType<Widget>(),
  ];
}

/// Opens the general search (as DAL), through the shared routes.
Widget searchAction(BuildContext context, DetailData data) {
  return IconButton(
    tooltip: S.current.Search,
    onPressed: () => AppRoutes.openSearch(context),
    icon: const Icon(Icons.search),
  );
}

/// MyAnimeList page of the title, with its slug like the website does.
String detailPageUrl(DetailData data) {
  final slug = data.title.formatForUrl();
  return 'https://myanimelist.net/${data.category}/${data.id}${slug.isEmpty ? '' : '/$slug'}';
}

/// Bookmark toggle (bookmarks unit). The detail screen is a MyAnimeList
/// screen, so the bookmark is keyed by the MAL id whatever tracker is active.
Widget? bookmarkAction(BuildContext context, DetailData data) {
  final title = data.title;
  if (title.isEmpty) return null;
  return BookmarkButton(
    tracker: AccountType.myanimelist.name,
    kind: data.isManga ? BookmarkKind.manga : BookmarkKind.anime,
    id: data.id,
    title: title,
    imageUrl: data.coverUrl.isEmpty ? null : data.coverUrl,
    subtitle: _bookmarkSubtitle(data),
    malId: data.id,
  );
}

String? _bookmarkSubtitle(DetailData data) {
  final parts = [
    data.content?.mediaType?.toUpperCase().replaceAll('_', ' '),
    data.content?.startSeason?.year.toString(),
  ].whereType<String>().where((e) => e.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Overflow menu: share, open in browser, More Info, search by genre and
/// customize sections.
Widget? overflowMenuAction(BuildContext context, DetailData data) {
  final s = S.current;
  final canShare = data.title.isNotEmpty;
  return AppBarMenu(
    onShare: canShare ? () => shareDetail(context, data) : null,
    onOpenInBrowser: () => openLink(context, detailPageUrl(data)),
    items: [
      if (data.hasContent)
        AppBarMenuItem(
          label: s.Dh_More_Info,
          icon: Icons.info_outline,
          onTap: () => showMoreInfoModal(context, data),
        ),
      if (genreFilterNames(data).isNotEmpty)
        AppBarMenuItem(
          label: s.Dh_Search_Genre,
          icon: Icons.manage_search,
          onTap: () => searchByGenre(context, data),
        ),
      AppBarMenuItem(
        label: s.Dh_Customize,
        icon: Icons.edit_note,
        onTap: () => showTabsCustomizer(context, manga: data.isManga),
      ),
    ],
  );
}

/// Share builder with the standard fields of the title.
Future<void> shareDetail(BuildContext context, DetailData data) {
  final content = data.content;
  final synopsis = content?.synopsis;
  return showShareBuilder(
    context,
    subject: data.title,
    title: data.isManga ? S.current.Dh_Share_Manga : S.current.Dh_Share_Anime,
    fields: contentShareFields(
      url: detailPageUrl(data),
      title: data.title,
      rank: content?.rank,
      mean: content?.mean,
      members: content?.numScoringUsers,
      genres: content?.genres?.map((g) => g.name).where((n) => n.isNotEmpty).toList(),
      synopsis: synopsis,
    ),
  );
}

/// Genre names understood by the search filter (MAL genre id first, the
/// name otherwise), at most [maxGenreFilters].
List<String> genreFilterNames(DetailData data) {
  final map = data.isManga ? Mal.mangaGenresEng : Mal.animeGenresEng;
  final names = <String>[];
  for (final genre in data.content?.genres ?? const []) {
    final name = map[genre.id] ?? genre.name;
    if (name.isNotEmpty && !names.contains(name)) names.add(name);
    if (names.length == maxGenreFilters) break;
  }
  return names;
}

/// Opens the search with the title's genres already included.
void searchByGenre(BuildContext context, DetailData data) {
  final names = genreFilterNames(data);
  if (names.isEmpty) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(S.current.Dh_No_Genres)));
    return;
  }
  gotoPage<void>(
    context: context,
    newPage: GeneralSearchScreen(
      category: data.category,
      showBackButton: true,
      filterOutputs: {
        'genres': FilterOption(
          type: FilterType.multiple,
          fieldName: 'genres',
          includedOptions: names,
        ),
      },
    ),
  );
}
