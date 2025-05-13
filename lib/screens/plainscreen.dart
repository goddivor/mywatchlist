// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';

void _gotoSearch(BuildContext context) {
  // gotoPage(context: context, newPage: GeneralSearchScreen(autoFocus: false));
  gotoPage(context: context, newPage: SizedBox());
}

class PlainScreen extends StatelessWidget {
  final Widget child;
  final String title;
  const PlainScreen({super.key, required this.child, required this.title});

  @override
  Widget build(BuildContext context) {
    return TitlebarScreen(child, appbarTitle: title);
  }
}

AppBar simpleAppBar(String title, BuildContext context) {
  return AppBar(title: Text(title), actions: [searchIconButton(context)]);
}

IconButton searchIconButton(BuildContext context) =>
    IconButton(onPressed: () => _gotoSearch(context), icon: Icon(Icons.search));

IconButton bookmarkAction(BuildContext context) => IconButton(
    // onPressed: () => gotoPage(context: context, newPage: BookMarksWidget()),
    onPressed: () => gotoPage(context: context, newPage: SizedBox()),
    icon: Icon(Icons.bookmark_outline));

class TitlebarScreen extends StatelessWidget {
  final Widget child;
  final String? appbarTitle;
  final bool useAppbar;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool autoIncludeSearch;
  const TitlebarScreen(
    this.child, {
    super.key,
    this.appbarTitle,
    this.useAppbar = true,
    this.autoIncludeSearch = true,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> _actions = [
      if (autoIncludeSearch) searchIcon(context),
      ...(actions ?? []),
    ];
    return Scaffold(
      floatingActionButton: floatingActionButton,
      appBar: useAppbar
          ? AppBar(
              actions: _actions,
              title: Text(appbarTitle ?? 'DailyAL', style: TextStyle()),
            )
          : null,
      body: child,
    );
  }
}

ToolTipButton searchIcon(BuildContext context) {
  return ToolTipButton(
    usePadding: true,
    message: S.current.Search_Bar_Text,
    onTap: () => _gotoSearch(context),
    child: Icon(Icons.search),
  );
}
