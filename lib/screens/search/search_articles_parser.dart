import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:mwl_commons/mwl_commons.dart' show Paging;
import 'package:mywatchlist/services/api/MAL/scrapper/anime_news_featured.dart';

/// Reads the latest articles from MyAnimeList's own `/news` and `/featured` pages.
///
/// Those two pages use the `box-unit3` markup; the tag and search pages still use `news-unit`,
/// which the shared parser reads. Only the first `.news-list` is read: on `/news` the following
/// lists repeat the same articles grouped by tag.
AnimeNewsOrFeaturedResult parseLatestArticles(String body) {
  final document = html_parser.parse(body);
  final list = document.querySelector('.news-list');
  final items = <AnimeNewsOrFeaturedItem>[];
  final seen = <int>{};
  for (final unit in list?.querySelectorAll('.box-unit3') ?? const <Element>[]) {
    final url = unit.querySelector('a.box-unit3-btn')?.attributes['href']?.trim() ?? '';
    final id = int.tryParse(RegExp(r'/(?:news|featured)/(\d+)').firstMatch(url)?.group(1) ?? '');
    final title = unit.querySelector('.title')?.text.trim() ?? '';
    if (id == null || title.isEmpty || !seen.add(id)) continue;
    final image = unit.querySelector('img');
    items.add(AnimeNewsOrFeaturedItem(
      id: id,
      title: title,
      text: _squash(unit.querySelector('.update')?.text ?? ''),
      tags: unit.querySelectorAll('.tags .tag').map((e) => e.text.trim()).join(', '),
      imageUrl: image?.attributes['data-src'] ?? image?.attributes['src'] ?? '',
      url: url,
    ));
  }
  final next = document.querySelector('a.btn-next')?.attributes['href']?.trim();
  return AnimeNewsOrFeaturedResult(
    newsorfeatured: items,
    paging: Paging(previous: '', next: next),
  );
}

String _squash(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();
