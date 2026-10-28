import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:mwl_commons/mwl_commons.dart' show MalSearchItemHtml;
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';

/// Why a search or a directory page could not show results.
enum SearchFailureKind {
  /// The device has no network (no connection, or myanimelist.net cannot be resolved).
  offline,

  /// The network works but the sources failed (MyAnimeList down, a challenge page, Jikan
  /// unreachable and MyAnimeList's page refused…).
  source,

  /// MyAnimeList searches need three characters or more and Jikan, which takes shorter
  /// text, did not answer.
  tooShort,
}

/// A search that ended without results for a known reason.
class SearchFailure implements Exception {
  final SearchFailureKind kind;
  final Object? cause;

  const SearchFailure(this.kind, [this.cause]);

  @override
  String toString() => 'SearchFailure($kind${cause == null ? '' : ': $cause'})';
}

/// Tells "no network" from "the source failed" after an error.
abstract final class SearchFailures {
  /// Replaceable in tests (the real check looks at the connection and resolves MAL's host).
  static Future<bool> Function() isOffline = _isOffline;

  @visibleForTesting
  static void reset() => isOffline = _isOffline;

  static Future<SearchFailureKind> classify(Object error) async {
    if (error is SearchFailure && error.kind != SearchFailureKind.source) return error.kind;
    try {
      return await isOffline() ? SearchFailureKind.offline : SearchFailureKind.source;
    } catch (_) {
      return SearchFailureKind.source;
    }
  }

  static Future<bool> _isOffline() async {
    if (kIsWeb) return false;
    final links = await Connectivity().checkConnectivity().timeout(const Duration(seconds: 3));
    if (links.every((l) => l == ConnectivityResult.none)) return true;
    try {
      final found = await InternetAddress.lookup('myanimelist.net').timeout(const Duration(seconds: 4));
      return found.isEmpty;
    } on SocketException {
      return true;
    } on TimeoutException {
      return true;
    }
  }
}

/// Where the anime / manga / character / person results of a search come from. A search keeps
/// its source for every next page, so pages of two sources are never mixed.
enum MediaSource { malApi, jikan, malPage }

/// One answer of a source: the rows and whether a next page exists.
class SourceAnswer {
  final MediaSource source;
  final List<Anime> items;
  final bool hasMore;

  const SourceAnswer(this.source, this.items, {required this.hasMore});
}

/// The first source that answers with rows wins; an empty answer wins only once every source
/// has answered (an empty Jikan page never hides MyAnimeList's rows). When every source fails,
/// the error of the last one in [attempts] (the fallback) is thrown.
Future<SourceAnswer> firstUseful(List<Future<SourceAnswer>> attempts) {
  final done = Completer<SourceAnswer>();
  var pending = attempts.length;
  SourceAnswer? empty;
  Object? lastError;
  Object? fallbackError;
  StackTrace? fallbackStack;
  void settle() {
    if (--pending > 0 || done.isCompleted) return;
    if (empty != null) {
      done.complete(empty);
    } else {
      done.completeError(fallbackError ?? lastError ?? StateError('No source'), fallbackStack);
    }
  }

  for (final (index, attempt) in attempts.indexed) {
    attempt.then((answer) {
      if (done.isCompleted) return;
      if (answer.items.isNotEmpty) {
        done.complete(answer);
      } else {
        empty ??= answer;
        settle();
      }
    }, onError: (Object e, StackTrace s) {
      lastError = e;
      if (index == attempts.length - 1) {
        fallbackError = e;
        fallbackStack = s;
      }
      settle();
    });
  }
  if (attempts.isEmpty) done.completeError(StateError('No source'));
  return done.future;
}

/// A row of MyAnimeList's search page as the result tiles show it.
Anime animeFromMalPage(MalSearchItemHtml item) => Anime(
      id: item.id,
      title: item.title,
      imageUrl: item.image ?? '',
      score: item.score ?? 0,
      members: item.members ?? 0,
      synopsis: item.synopsis,
      numEpisodes: item.episodes,
      numVolumes: item.volumes,
      startDate: item.startDate,
      endDate: item.endDate,
      mediaType: item.type,
    );
