import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/utils/app_routes.dart';

/// Opens the detail screen of [media]. The detail screens are MyAnimeList screens, so a title
/// Kitsu maps to no MyAnimeList page says so instead of doing nothing.
void openKitsuMedia(BuildContext context, KitsuMedia media) {
  final mal = media.malId;
  if (mal == null) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(S.current.Kitsu_No_Mal_Match)));
    return;
  }
  AppRoutes.openContent(context, id: mal, category: media.category);
}
