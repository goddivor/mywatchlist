/// App bar actions of the detail page.
///
/// [buildDetailActions] returns, in order: search, then the extension points
/// below. Each extension point returns null today (nothing shown); the
/// `detail-header` unit fills them (share builder, open in browser, bookmark
/// toggle, overflow menu with search by genre / customize tabs) without
/// touching the screen.
library;

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';

List<Widget> buildDetailActions(BuildContext context, DetailData data) {
  return [
    searchAction(context, data),
    ...[
      shareAction(context, data),
      openInBrowserAction(context, data),
      bookmarkAction(context, data),
      overflowMenuAction(context, data),
    ].whereType<Widget>(),
  ];
}

/// Opens the search screen on this category (DAL opens the general search).
Widget searchAction(BuildContext context, DetailData data) {
  return IconButton(
    tooltip: S.current.Search,
    onPressed: () => gotoPage(
      context: context,
      newPage: GeneralSearchScreen(
        category: data.category,
        showBackButton: true,
      ),
    ),
    icon: const Icon(Icons.search),
  );
}

/// EXTENSION POINT (detail-header): share the title (DAL share builder).
Widget? shareAction(BuildContext context, DetailData data) => null;

/// EXTENSION POINT (detail-header): open the MAL page in the browser.
Widget? openInBrowserAction(BuildContext context, DetailData data) => null;

/// EXTENSION POINT (detail-header): bookmark toggle (bookmarks unit API).
Widget? bookmarkAction(BuildContext context, DetailData data) => null;

/// EXTENSION POINT (detail-header): overflow menu (More Info, search by
/// genre, customize tabs).
Widget? overflowMenuAction(BuildContext context, DetailData data) => null;
