import 'package:flutter/material.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_media_page.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';

/// Opens the native Kitsu page of [media]. Every title opens, with or without a MyAnimeList
/// mapping; the page keeps "Open on MyAnimeList" in its menu when there is one.
Future<void> openKitsuMedia(BuildContext context, KitsuMedia media) => openKitsuTitle(
      context,
      kind: media.isAnime ? KitsuMediaKind.anime : KitsuMediaKind.manga,
      id: '${media.id}',
      title: media.title,
      posterUrl: media.largePosterUrl ?? media.posterUrl,
    );

/// Opens the native Kitsu page of the title with Kitsu id [id] or slug [slug]; [title] and
/// [posterUrl] show while it loads.
Future<void> openKitsuTitle(
  BuildContext context, {
  required KitsuMediaKind kind,
  String? id,
  String? slug,
  String? title,
  String? posterUrl,
}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => KitsuMediaPage(kind: kind, id: id, slug: slug, title: title, posterUrl: posterUrl),
    ));
