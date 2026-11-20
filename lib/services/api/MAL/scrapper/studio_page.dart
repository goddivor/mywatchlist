import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

/// The kinds of anime the studio page groups, as MAL's tabs do.
enum StudioAnimeType { tv, ona, ova, movie, other }

/// One anime of a studio page.
@immutable
class StudioAnime {
  final int id;
  final String title;
  final String? imageUrl;
  final double? score;
  final int members;

  /// MAL's start date as a sortable number (`20030826`), 0 when unknown.
  final int startDate;
  final StudioAnimeType type;

  const StudioAnime({
    required this.id,
    required this.title,
    this.imageUrl,
    this.score,
    this.members = 0,
    this.startDate = 0,
    this.type = StudioAnimeType.other,
  });
}

/// A line of the studio's information block ("Established: Jul 12, 1985"). [label] is MAL's
/// English label.
@immutable
class StudioFact {
  final String label;
  final String value;
  const StudioFact(this.label, this.value);
}

/// A link of the "Available At" block (website, X, YouTube…).
@immutable
class StudioLink {
  final String label;
  final String url;
  const StudioLink(this.label, this.url);
}

/// Everything the studio page shows (`myanimelist.net/anime/producer/<id>`).
@immutable
class StudioPage {
  final int id;
  final String name;

  /// The big logo (600×600), null when MAL has none.
  final String? logo;
  final List<StudioFact> facts;
  final String? about;
  final List<StudioLink> links;
  final List<StudioAnime> anime;

  const StudioPage({
    required this.id,
    required this.name,
    this.logo,
    this.facts = const [],
    this.about,
    this.links = const [],
    this.anime = const [],
  });
}

String _clean(String? text) => (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// MAL's `js-anime-type-<n>` classes: 1 TV, 2 OVA, 3 movie, 5 ONA; the rest (specials,
/// music, CM, TV specials…) is MAL's "Other" tab.
StudioAnimeType _typeOf(Element item) {
  final classes = item.classes;
  if (classes.contains('js-anime-type-1')) return StudioAnimeType.tv;
  if (classes.contains('js-anime-type-2')) return StudioAnimeType.ova;
  if (classes.contains('js-anime-type-3')) return StudioAnimeType.movie;
  if (classes.contains('js-anime-type-5')) return StudioAnimeType.ona;
  return StudioAnimeType.other;
}

int? _idOf(String? href) {
  final match = RegExp(r'/anime/(\d+)').firstMatch(href ?? '');
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// The text of a node with `<br>` as line breaks (MAL's about text).
String _textWithBreaks(Element element) {
  final buffer = StringBuffer();
  void walk(Node node) {
    if (node is Text) {
      buffer.write(node.text);
    } else if (node is Element) {
      if (node.localName == 'br') {
        buffer.write('\n');
      } else {
        node.nodes.forEach(walk);
      }
    }
  }

  element.nodes.forEach(walk);
  return buffer
      .toString()
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// Reads a studio page. [args] = (page body, studio id). Null when the body is not a studio
/// page (a challenge or maintenance page).
StudioPage? parseStudioPage((String, int) args) {
  final doc = html.parse(args.$1);
  final name = _clean(doc.querySelector('h1.title-name')?.text);
  final left = doc.querySelector('.content-left');
  if (name.isEmpty || left == null) return null;

  final img = left.querySelector('.logo img');
  final logo = img?.attributes['data-src'] ?? img?.attributes['src'];

  final facts = <StudioFact>[];
  String? about;
  for (final row in left.querySelectorAll('.spaceit_pad')) {
    final label = row.querySelector('.dark_text');
    if (label == null) {
      final span = row.querySelector('span') ?? row;
      final text = _textWithBreaks(span);
      if (text.isNotEmpty) about = text;
      continue;
    }
    final key = _clean(label.text).replaceAll(RegExp(r':$'), '');
    label.remove();
    final value = _clean(row.text);
    if (key.isNotEmpty && value.isNotEmpty) facts.add(StudioFact(key, value));
  }

  final links = <StudioLink>[];
  final sns = left.querySelector('.user-profile-sns');
  for (final a in sns?.querySelectorAll('a[href]') ?? const <Element>[]) {
    final url = a.attributes['href']!.trim();
    final label = _clean(a.text);
    if (url.startsWith('http') && label.isNotEmpty) links.add(StudioLink(label, url));
  }

  final anime = <StudioAnime>[];
  final seen = <int>{};
  for (final item in doc.querySelectorAll('.seasonal-anime.js-seasonal-anime')) {
    final link = item.querySelector('.title a');
    final id = _idOf(link?.attributes['href']);
    if (id == null || !seen.add(id)) continue;
    final picture = item.querySelector('.image img');
    final score = double.tryParse(_clean(item.querySelector('.js-score')?.text));
    anime.add(StudioAnime(
      id: id,
      title: _clean(item.querySelector('.js-title')?.text).isNotEmpty
          ? _clean(item.querySelector('.js-title')?.text)
          : _clean(link?.text),
      imageUrl: picture?.attributes['data-src'] ?? picture?.attributes['src'],
      score: score == null || score <= 0 ? null : score,
      members: int.tryParse(_clean(item.querySelector('.js-members')?.text)) ?? 0,
      startDate: int.tryParse(_clean(item.querySelector('.js-start_date')?.text)) ?? 0,
      type: _typeOf(item),
    ));
  }

  return StudioPage(
    id: args.$2,
    name: name,
    logo: logo == null || logo.isEmpty || logo.contains('no_picture') ? null : logo,
    facts: facts,
    about: about,
    links: links,
    anime: anime,
  );
}

/// Reads a studio page on the device (desktop layout), parsed off the UI isolate; each studio
/// once per session (a failure is asked again next time).
class StudioPages {
  StudioPages._();

  static const String _userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

  /// The page source; tests replace it.
  @visibleForTesting
  static Future<StudioPage> Function(int id) source = _fetch;

  static final Map<int, Future<StudioPage>> _session = {};

  static Future<StudioPage> of(int id) {
    final known = _session[id];
    if (known != null) return known;
    final future = source(id);
    _session[id] = future;
    future.then<void>((_) {}, onError: (_) {
      _session.remove(id);
    });
    return future;
  }

  @visibleForTesting
  static void reset() {
    _session.clear();
    source = _fetch;
  }

  static Future<StudioPage> _fetch(int id) async {
    final url = Uri.https('myanimelist.net', '/anime/producer/$id');
    final response = await http.get(url, headers: const {
      'User-Agent': _userAgent,
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw http.ClientException('MAL answered ${response.statusCode}', url);
    }
    final page = await compute(parseStudioPage, (response.body, id));
    if (page == null) throw FormatException('Not a MAL studio page: $id');
    return page;
  }
}
