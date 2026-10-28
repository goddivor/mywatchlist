import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';

/// Parsers of simkl.com's server-rendered pages (read 2026-10-28 on Frieren 1990194 and Mashle
/// 2475640, desktop markup). Pure functions of the HTML text, run off the UI isolate by
/// `SimklDetailService`. Every block is parsed on its own: a block whose selector no longer
/// matches gives null (the page hides that section), never an exception.

const String simklSite = 'https://simkl.com';

/// Title page `https://simkl.com/anime/{id}/{slug}`: watcher distribution (C1), counters (C7),
/// the first reviews (C3), tags, links, studios, producers and licensors (C9).
SimklTitlePage parseSimklTitlePage(String html) {
  final doc = html_parser.parse(html);
  final about = _guard(() => _aboutRows(doc)) ?? const <String, Element>{};
  return SimklTitlePage(
    watchers: _guard(() => _watchers(doc)),
    counters: _guard(() => _counters(doc)),
    reviews: _guard(() => _reviews(doc)),
    tags: _guard(() => _tags(doc)),
    links: _guard(() => _links(about['links'])),
    studios: _guard(() => _names(about['studios'])),
    producers: _guard(() => _names(about['producers'])),
    licensors: _guard(() => _names(about['licensors'])),
  );
}

/// Reviews page `…/reviews/` (C3): summary and every review card.
SimklReviews? parseSimklReviews(String html) => _guard(() => _reviews(html_parser.parse(html)));

/// Comments page `…/comments/` (C4), in page order (replies follow their comment).
List<SimklComment>? parseSimklComments(String html) => _guard(() => _comments(html_parser.parse(html)));

/// Memos page `…/memos/` (C5): every memo with the rating bucket of its column.
List<SimklMemo>? parseSimklMemos(String html) => _guard(() => _memos(html_parser.parse(html)));

T? _guard<T>(T? Function() read) {
  try {
    return read();
  } catch (_) {
    return null;
  }
}

String _clean(String? s) => (s ?? '').replaceAll(' ', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// First whole number of [s] ("5,727 (16.6%)" → 5727, "245 Reactions" → 245).
int? _firstInt(String? s) {
  final m = RegExp(r'\d[\d,\.\s]*').firstMatch(_clean(s));
  if (m == null) return null;
  final digits = m.group(0)!.split(RegExp(r'[^\d,\.\s]')).first;
  return int.tryParse(digits.replaceAll(RegExp(r'[,\.\s]'), ''));
}

double? _percentIn(String? s) {
  final m = RegExp(r'(\d+(?:[\.,]\d+)?)\s*%').firstMatch(_clean(s));
  return m == null ? null : double.tryParse(m.group(1)!.replaceAll(',', '.'));
}

String? _abs(String? href) {
  final h = href?.trim();
  if (h == null || h.isEmpty || h == '#' || h == '/#') return null;
  if (h.startsWith('http')) return h;
  if (h.startsWith('//')) return 'https:$h';
  if (h.startsWith('/')) return '$simklSite$h';
  return null;
}

String? _avatar(Element? img) {
  final src = _abs(img?.attributes['src']);
  if (src == null || src.contains('ico_profile_guest')) return null;
  return src;
}

// --- C1 watcher distribution ------------------------------------------------------------------

const _bucketByClass = {
  'bg5': SimklWatcherStatus.watching,
  'bg4': SimklWatcherStatus.planToWatch,
  'bg3': SimklWatcherStatus.completed,
  'bg2': SimklWatcherStatus.onHold,
  'bg1': SimklWatcherStatus.dropped,
};

const _bucketByTitle = {
  'watching': SimklWatcherStatus.watching,
  'plan to watch': SimklWatcherStatus.planToWatch,
  'completed': SimklWatcherStatus.completed,
  'on hold': SimklWatcherStatus.onHold,
  'dropped': SimklWatcherStatus.dropped,
};

SimklWatchers? _watchers(Document doc) {
  final items = doc.querySelectorAll('.simkltvdetailssummarystatsitem');
  if (items.isEmpty) return null;
  final buckets = <SimklWatcherBucket>[];
  int? total;
  for (final item in items) {
    final title = _clean(item.querySelector('.simkltvdetailssummarystatsitemtitle')?.text).toLowerCase();
    final usersEl = item.querySelector('.simkltvdetailssummarystatsitemusers');
    if (usersEl == null) continue;
    final percentEl = usersEl.querySelector('.simkltvdetailssummarystatsitemuserstext');
    final own = usersEl.nodes.whereType<Text>().map((t) => t.text).join(' ');
    final users = _firstInt(own) ?? _firstInt(usersEl.text);
    if (users == null) continue;
    final bg = item.classes
        .map((c) => RegExp(r'simkltvdetailssummarystatsitem(bg\d)$').firstMatch(c)?.group(1))
        .whereType<String>()
        .firstOrNull;
    if (bg == 'bg6' || title == 'total') {
      total = users;
      continue;
    }
    final status = _bucketByClass[bg] ?? _bucketByTitle[title];
    if (status == null) continue;
    buckets.add(SimklWatcherBucket(status, users, _percentIn(percentEl?.text)));
  }
  if (buckets.isEmpty) return null;
  buckets.sort((a, b) => a.status.index.compareTo(b.status.index));
  return SimklWatchers(buckets, total);
}

// --- C7 counters ------------------------------------------------------------------------------

SimklCounters? _counters(Document doc) {
  int? read(String id) {
    final tab = doc.getElementById(id);
    if (tab == null) return null;
    // "Add Review" / "Add Comments": the tab is there, nothing posted yet.
    return _firstInt(tab.text) ?? 0;
  }

  final c = SimklCounters(
    reactions: read('CommentTabReactions'),
    reviews: read('CommentTabReviews'),
    comments: read('CommentTabComments'),
    memos: read('CommentTabMemos'),
  );
  return c.isEmpty ? null : c;
}

// --- C3 reviews -------------------------------------------------------------------------------

const _aspectByLabel = {
  'story': SimklReviewAspect.story,
  'animation': SimklReviewAspect.animation,
  'sound': SimklReviewAspect.sound,
  'character': SimklReviewAspect.character,
  'enjoyment': SimklReviewAspect.enjoyment,
};

SimklReviews? _reviews(Document doc) {
  final block = doc.querySelector('.SimklTVDetailReviewsCount');
  final cards = doc.querySelectorAll('.SimklTVDetailReviewItem');
  if (block == null && cards.isEmpty) return null;
  SimklReviewSummary? summary;
  if (block != null && block.querySelector('.SimklTVDetailReviewsCountTotal') != null) {
    int count(String cls) => _firstInt(block.querySelector('.$cls .SimklTVDetailReviewsCountNumber')?.text) ?? 0;
    summary = SimklReviewSummary(
      positivePercent: _percentIn(block.querySelector('.SimklTVDetailReviewsCountTotal')?.text),
      positive: count('SimklTVDetailReviewsCountPositive'),
      neutral: count('SimklTVDetailReviewsCountNeutral'),
      negative: count('SimklTVDetailReviewsCountNegative'),
    );
  }
  final items = <SimklReview>[];
  for (final card in cards) {
    final review = _guard(() => _review(card));
    if (review != null) items.add(review);
  }
  return SimklReviews(summary, items);
}

SimklReview? _review(Element card) {
  final aboutDate = card.querySelector('.SimklTVDetailReviewItemAboutDate');
  final authorLink = aboutDate?.querySelector('a');
  final author = _clean(authorLink?.text);
  final dateText = aboutDate?.nodes.whereType<Text>().map((t) => t.text).join(' ');
  final date = _clean(dateText).replaceAll(RegExp(r'\s*-\s*$'), '');
  final titleLink = card.querySelector('.SimklTVDetailReviewItemTitle a');
  final scores = <SimklReviewAspect, int>{};
  final story = card.querySelector('.SimklTVDetailReviewItemStoryRating');
  if (story != null) {
    String? label;
    for (final node in story.nodes) {
      if (node is Text) {
        final t = _clean(node.text).replaceAll(':', '').toLowerCase();
        if (t.isNotEmpty) label = t;
      } else if (node is Element && label != null) {
        final aspect = _aspectByLabel[label];
        final value = _firstInt(node.text);
        if (aspect != null && value != null) scores[aspect] = value;
        label = null;
      }
    }
  }
  final body = card.querySelector('.SimklTVDetailReviewItemText');
  var truncated = false;
  final paragraphs = <String>[];
  if (body != null) {
    for (final a in body.querySelectorAll('a').toList()) {
      if (_clean(a.text).toLowerCase() == 'read more') {
        truncated = true;
        a.remove();
      }
    }
    final ps = body.querySelectorAll('p');
    for (final p in ps.isEmpty ? [body] : ps) {
      final t = _clean(p.text);
      if (t.isNotEmpty) paragraphs.add(t);
    }
  }
  final text = paragraphs.join('\n\n');
  if (author.isEmpty && text.isEmpty) return null;
  final helpful = card.querySelectorAll('.SimklTVDetailReviewItemHelpfulStats strong');
  final tone = card.classes.contains('Positive')
      ? SimklReviewTone.positive
      : card.classes.contains('Negative')
          ? SimklReviewTone.negative
          : card.classes.contains('Neutral')
              ? SimklReviewTone.neutral
              : null;
  return SimklReview(
    author: author,
    authorUrl: _abs(authorLink?.attributes['href']),
    avatarUrl: _avatar(card.querySelector('.SimklTVDetailReviewItemWhoAvatar img')),
    date: date.isEmpty ? null : date,
    title: titleLink == null ? null : _clean(titleLink.text),
    url: _abs(titleLink?.attributes['href']),
    overall: _firstInt(card.querySelector('.SimklTVDetailReviewItemRatingNumber')?.text),
    scores: scores,
    tone: tone,
    text: text,
    truncated: truncated,
    helpful: helpful.isNotEmpty ? _firstInt(helpful[0].text) : null,
    helpfulTotal: helpful.length > 1 ? _firstInt(helpful[1].text) : null,
  );
}

// --- C9 tags, links, studios, producers, licensors --------------------------------------------

/// The About table: `<td><strong>Label:</strong></td><td>value</td>`, keyed by the lower-case
/// label without its colon ("studios", "links"…).
Map<String, Element> _aboutRows(Document doc) {
  final rows = <String, Element>{};
  for (final strong in doc.querySelectorAll('td > strong')) {
    final label = _clean(strong.text);
    if (!label.endsWith(':')) continue;
    final cell = strong.parent;
    final value = cell?.nextElementSibling;
    if (value == null || value.localName != 'td') continue;
    rows.putIfAbsent(label.substring(0, label.length - 1).trim().toLowerCase(), () => value);
  }
  return rows;
}

List<String>? _tags(Document doc) {
  final box = doc.querySelector('.simkltvdiscoverlistleftfiltersitemoptionstags');
  if (box == null) return null;
  final seen = <String>{};
  return [
    for (final a in box.querySelectorAll('a.tag'))
      if (_clean(a.text).isNotEmpty && seen.add(_clean(a.text))) _clean(a.text),
  ];
}

List<SimklLink>? _links(Element? cell) {
  if (cell == null) return null;
  final seen = <String>{};
  final out = <SimklLink>[];
  for (final a in cell.querySelectorAll('a')) {
    final href = a.attributes['href']?.trim() ?? '';
    final name = _clean(a.text);
    if (!href.startsWith('http') || name.isEmpty || !seen.add(href)) continue;
    out.add(SimklLink(name, href));
  }
  return out;
}

List<String>? _names(Element? cell) {
  if (cell == null) return null;
  final links = cell.querySelectorAll('a').map((a) => _clean(a.text)).where((t) => t.isNotEmpty).toList();
  final names = links.isNotEmpty ? links : _clean(cell.text).split(',').map((s) => s.trim()).toList();
  return names.where((n) => n.isNotEmpty).toSet().toList();
}

// --- C4 comments ------------------------------------------------------------------------------

List<SimklComment>? _comments(Document doc) {
  final list = doc.querySelectorAll('.SimklTVCommentsItem');
  final out = <SimklComment>[];
  for (final item in list) {
    final c = _guard(() => _comment(item));
    if (c != null) out.add(c);
  }
  if (out.isEmpty && list.isNotEmpty) return null; // markup changed: hide rather than say "none"
  return out;
}

SimklComment? _comment(Element item) {
  final cell = item.querySelector('td.SimklTVCommentsItemTd');
  final textEl = item.querySelector('.SimklTVCommentsItemText');
  final nameEl = item.querySelector('.SimklTVCommentsItemName');
  if (textEl == null || nameEl == null) return null;
  final depth = item.classes
          .map((c) => RegExp(r'^SimklTVCommentsItem(\d+)$').firstMatch(c)?.group(1))
          .whereType<String>()
          .map(int.parse)
          .firstOrNull ??
      0;
  final date = item.querySelector('.SimklTVCommentsItemDate');
  final body = item.querySelector('.SimklTVCommentsItemCommentTXT');
  final classes = <String>{...?body?.classes, ...textEl.classes};
  final spoiler = classes.any((c) => c != 'spoilerMark' && c.toLowerCase().contains('spoiler')) ||
      textEl.querySelector('[class*=Spoiler], .spoiler') != null;
  return SimklComment(
    id: (cell?.id ?? '').replaceFirst('comment', ''),
    author: _clean(nameEl.text),
    authorUrl: _abs(nameEl.attributes['href']),
    avatarUrl: _avatar(item.querySelector('img.SimklImageCircle')),
    text: textEl.text.replaceAll(' ', ' ').trim(),
    ago: date == null ? null : _clean(date.text),
    exactTime: date?.attributes['title']?.trim(),
    likes: _firstInt(item.querySelector('.SimklTVCommentsItemHeart')?.text) ?? 0,
    spoiler: spoiler,
    vip: item.querySelector('.SimklTVCommentsItemVIP') != null,
    depth: depth,
  );
}

// --- C5 memos ---------------------------------------------------------------------------------

List<SimklMemo>? _memos(Document doc) {
  final columns = doc.querySelectorAll('.detailmemostabcontentcolumn');
  if (columns.isEmpty) return null;
  final out = <SimklMemo>[];
  for (final column in columns) {
    final header = _clean(column.querySelector('.detailmemostabcontentcolumnheaderleft')?.text);
    final range = RegExp(r'(\d+)\s*-\s*(\d+)').firstMatch(header);
    for (final item in column.querySelectorAll('.detailmemostabcontentcolumnitem')) {
      final name = _clean(item.querySelector('.detailmemostabcontentcolumnitemrightnametext')?.text);
      final text = _clean(item.querySelector('.dmemoetailmemostabcontentcolumnitemright')?.text);
      if (name.isEmpty || text.isEmpty) continue;
      out.add(SimklMemo(
        author: name,
        authorUrl: _abs(item.querySelector('a.detailmemostabcontentcolumnitemrightname')?.attributes['href']),
        text: text,
        likes: _firstInt(item.querySelector('.detailmemostabcontentcolumnitemleftnumber')?.text) ?? 0,
        minStars: range == null ? null : int.parse(range.group(1)!),
        maxStars: range == null ? null : int.parse(range.group(2)!),
      ));
    }
  }
  return out;
}
