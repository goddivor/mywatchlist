import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html_unescape/html_unescape.dart';

import '../model/html/pages/characters.dart';
import '../model/html/pages/common.dart';
import '../model/html/pages/community.dart';
import '../model/html/pages/content_stats.dart';
import '../model/html/pages/recommendations.dart';
import '../model/html/pages/search_schedule.dart';
import '../util/mal_path.dart';

/// Parsers for the MAL (and LiveChart) pages ported from DailyAL's
/// `dal_commons` HtmlParsers: characters, people, pictures, producers,
/// clubs, reviews, forum rows, user "about", "all" search and schedules.
///
/// Every parser is pure (Document in, model out), never throws on a page
/// whose layout changed (it returns an empty result instead) and can run on
/// a background isolate.
class PageParsers {
  PageParsers._();

  static final _unescape = HtmlUnescape();
  static final _spaces = RegExp(r'\s+');
  static final _digits = RegExp(r'\D');

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  static String _clean(String? text) =>
      _unescape.convert((text ?? '').replaceAll(_spaces, ' ').trim());

  static String? _cleanOrNull(String? text) {
    final cleaned = _clean(text);
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Text of [element] where `<br>` becomes a line break and every other
  /// whitespace run a single space.
  static String _textWithBreaks(Element element) {
    const marker = '\u0000';
    final copy = element.clone(true);
    for (final br in copy.querySelectorAll('br')) {
      br.replaceWith(Text(marker));
    }
    return _unescape
        .convert(copy.text.replaceAll(_spaces, ' '))
        .split(marker)
        .map((l) => l.trim())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static int? _intOf(String? text) {
    final digits = (text ?? '').replaceAll(_digits, '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  /// Image of the first `img` in [element], in both sizes.
  ///
  /// Reads `data-srcset` (1x, 2x), then `data-src`, then `srcset`/`src`.
  static ImageSet imageOf(Element? element) {
    final img =
        element?.localName == 'img' ? element : element?.querySelector('img');
    if (img == null) return const ImageSet();
    final srcSet = img.attributes['data-srcset'] ?? img.attributes['srcset'];
    if (srcSet != null && srcSet.trim().isNotEmpty) {
      final parts = srcSet
          .split(',')
          .map((e) => e.trim().split(' ').first.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        return ImageSet(
          medium: parts.first,
          large: parts.length > 1 ? parts[1] : parts.first,
        );
      }
    }
    final src = img.attributes['data-src'] ?? img.attributes['src'];
    if (src == null || src.trim().isEmpty) return const ImageSet();
    return ImageSet(medium: src.trim(), large: src.trim());
  }

  static MalNodeRef _nodeOfAnchor(Element a) {
    final href = a.attributes['href'];
    return MalNodeRef(
      id: MalPath.idFromUrl(href),
      title: _cleanOrNull(a.text),
      category: MalPath.categoryFromUrl(href),
    );
  }

  static MalUserRef? _userOf(Element? element) {
    final username = MalPath.usernameOf(element);
    if (username == null || username.isEmpty) return null;
    final image = imageOf(element);
    return MalUserRef(username: username, image: image.isEmpty ? null : image);
  }

  static Element? _headerContaining(List<Element> headers, String text) {
    final needle = text.toLowerCase();
    for (final header in headers) {
      if (header.text.toLowerCase().contains(needle)) return header;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Characters and people
  // ---------------------------------------------------------------------------

  /// `/{anime|manga}/{id}/_/characters`: every character with its voice
  /// actors, plus the staff list (anime only).
  ///
  /// Ported from DailyAL `parseCharacterAllPage`.
  static ContentCharactersHtml parseCharacterAllPage(
    Document doc,
    String category,
  ) {
    final body = doc.body;
    if (body == null) return const ContentCharactersHtml();

    final characters = <ContentCharacterHtml>[];
    final seen = <int>{};
    for (final table in body.querySelectorAll('.js-$category-character-table')) {
      final row = table.querySelector('tr');
      if (row == null) continue;
      final cells = row.children.where((e) => e.localName == 'td').toList();
      if (cells.length < 2) continue;
      final info = cells[1];
      final id = MalPath.idOf(info.querySelector('.spaceit_pad a') ??
          info.querySelector('a'));
      final roleAndName =
          _clean(info.querySelector('.js-chara-roll-and-name')?.text);
      String? role;
      String name = _clean(info.querySelector('h3')?.text);
      final underscore = roleAndName.indexOf('_');
      if (underscore > 0) {
        role = roleAndName.substring(0, underscore) == 'm'
            ? 'Main'
            : 'Supporting';
        if (name.isEmpty) name = roleAndName.substring(underscore + 1);
      }
      final shownRole = info
          .querySelectorAll('.spaceit_pad')
          .map((e) => _clean(e.text))
          .firstWhere((t) => t == 'Main' || t == 'Supporting',
              orElse: () => '');
      if (shownRole.isNotEmpty) role = shownRole;
      if (id == null || name.isEmpty || !seen.add(id)) continue;

      final favorites = _intOf(
              info.querySelector('.js-$category-character-favorites')?.text) ??
          0;
      final voiceActors = <VoiceActorHtml>[];
      if (cells.length > 2) {
        for (final va
            in cells[2].querySelectorAll('.js-anime-character-va-lang')) {
          final anchor = va.querySelector('.spaceit_pad a') ??
              va.querySelector('a');
          final vaId = MalPath.idOf(anchor);
          final vaName = _clean(anchor?.text);
          if (vaId == null || vaName.isEmpty) continue;
          final image = imageOf(va);
          voiceActors.add(VoiceActorHtml(
            id: vaId,
            name: vaName,
            language: _cleanOrNull(
                va.querySelector('.js-anime-character-language')?.text),
            image: image.isEmpty ? null : image,
          ));
        }
      }
      final image = imageOf(cells[0]);
      characters.add(ContentCharacterHtml(
        id: id,
        name: name,
        role: role,
        favorites: favorites,
        image: image.isEmpty ? null : image,
        voiceActors: voiceActors,
      ));
    }

    return ContentCharactersHtml(
      characters: characters,
      staff: _parseStaff(body),
    );
  }

  static List<StaffMemberHtml> _parseStaff(Element body) {
    Element? header;
    for (final border in body.querySelectorAll('.border_solid')) {
      if (_clean(border.querySelector('h2')?.text).toLowerCase() == 'staff') {
        header = border;
        break;
      }
    }
    final staff = <StaffMemberHtml>[];
    var next = header?.nextElementSibling;
    while (next != null && next.localName == 'table') {
      final cells = next.querySelectorAll('td');
      if (cells.length >= 2) {
        final anchor = cells[1].querySelector('a');
        final id = MalPath.idOf(anchor);
        final name = _clean(anchor?.text);
        if (id != null && name.isNotEmpty) {
          final image = imageOf(cells[0]);
          staff.add(StaffMemberHtml(
            id: id,
            name: name,
            role: _cleanOrNull(cells[1].querySelector('small')?.text),
            image: image.isEmpty ? null : image,
          ));
        }
      }
      next = next.nextElementSibling;
    }
    return staff;
  }

  /// Top characters (`character.php`) or top people (`people.php`).
  ///
  /// [category] is `character` or `people`. Ported from DailyAL
  /// `parseCharacterPeopleHome`.
  static List<RankedPersonHtml> parseCharacterPeopleHome(
    Document doc,
    String category,
  ) {
    final table = category == 'people'
        ? '.people-favorites-ranking-table'
        : '.characters-favorites-ranking-table';
    final rows = doc.querySelectorAll('$table .ranking-list');
    final result = <RankedPersonHtml>[];
    for (final row in rows) {
      final people = row.querySelector('.people');
      final info = people?.querySelector('.information');
      final anchor = info?.querySelector('a');
      final id = MalPath.idOf(anchor);
      final name = _clean(anchor?.text);
      if (id == null || name.isEmpty) continue;
      var otherName = _clean(
          (info?.querySelector('div') ?? info?.querySelector('span'))?.text);
      if (otherName.startsWith('(') && otherName.endsWith(')')) {
        otherName = otherName.substring(1, otherName.length - 1).trim();
      }
      final image = imageOf(people);
      result.add(RankedPersonHtml(
        id: id,
        rank: _intOf(row.querySelector('.rank')?.text),
        name: name,
        otherName: otherName.isEmpty ? null : otherName,
        image: image.isEmpty ? null : image,
        favorites: _intOf(row.querySelector('.favorites')?.text),
        birthday: category == 'people'
            ? _cleanOrNull(row.querySelector('.birthday')?.text)
            : null,
        animeography: category == 'people'
            ? const []
            : row
                .querySelectorAll('.animeography a')
                .map(_nodeOfAnchor)
                .where((e) => e.id != null)
                .toList(),
        mangaography: category == 'people'
            ? const []
            : row
                .querySelectorAll('.mangaography a')
                .map(_nodeOfAnchor)
                .where((e) => e.id != null)
                .toList(),
      ));
    }
    return result;
  }

  /// Picture URL of one cell of a `/character|people/{id}/_/pics` page.
  ///
  /// Ported from DailyAL `parseCharacterPage`.
  static String? parseCharacterPage(Element cell) {
    final href = cell.querySelector('a')?.attributes['href'];
    if (href == null || !href.startsWith('http')) return null;
    return href;
  }

  /// Every full-size picture of a character or person pictures page.
  static List<String> parsePicturesPage(Document doc) {
    final table = doc.querySelector('.mb8')?.nextElementSibling;
    if (table == null) return const [];
    return table
        .querySelectorAll('td')
        .map(parseCharacterPage)
        .whereType<String>()
        .toSet()
        .toList();
  }

  /// Producers (from `anime.php`) or magazines (from `manga.php`):
  /// id to name, in MAL's order (most entries first).
  ///
  /// Ported from DailyAL `parseMagazines`, which picked the fifth
  /// `.genre-link` block; MAL added a block since, so the block is now found
  /// by its links.
  static Map<int, String> parseMagazines(Document doc, String category) {
    final prefix =
        category == 'anime' ? '/anime/producer/' : '/manga/magazine/';
    final result = <int, String>{};
    for (final a in doc.querySelectorAll('.genre-link .genre-list a')) {
      final href = a.attributes['href'] ?? '';
      final at = href.indexOf(prefix);
      if (at < 0) continue;
      final parts = href.substring(at + prefix.length).split('/');
      final id = int.tryParse(parts.first);
      if (id == null) continue;
      var name = _clean(a.text).replaceFirst(RegExp(r'\s*\([\d,]+\)$'), '');
      if (name.isEmpty && parts.length > 1) {
        name = parts[1].replaceAll('_', ' ').trim();
      }
      if (name.isNotEmpty) result.putIfAbsent(id, () => name);
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Reviews and forum rows
  // ---------------------------------------------------------------------------

  /// One `.review-element`. Ported from DailyAL `animeReviewHtmlfromHtml`.
  static ReviewHtml? animeReviewHtmlfromHtml(Element? review) {
    if (review == null) return null;
    final body = review.querySelector('.body');
    if (body == null) return null;

    final username = _cleanOrNull(body.querySelector('.username a')?.text);
    if (username == null) return null;

    MalNodeRef? related;
    final thumbRight = review.querySelector('.thumb-right');
    final relatedAnchor = thumbRight?.querySelector('a') ??
        review.querySelector('.titleblock a.title');
    if (relatedAnchor != null) {
      final href = relatedAnchor.attributes['href'];
      final image = imageOf(thumbRight);
      related = MalNodeRef(
        id: MalPath.idFromUrl(href),
        category: MalPath.categoryFromUrl(href),
        title: _cleanOrNull(
                review.querySelector('.titleblock a.title')?.text) ??
            _titleFromUrl(href),
        image: image.isEmpty ? null : image,
      );
    }

    String? text;
    final textEl = body.querySelector('.text')?.clone(true);
    if (textEl != null) {
      textEl.querySelectorAll('.thumb-right, .js-visible').forEach((e) {
        e.remove();
      });
      text = _textWithBreaks(textEl);
    }

    final reactions = <String, int>{};
    for (final button in review.querySelectorAll('.btn-reaction')) {
      final count = _intOf(button.querySelector('.num')?.text);
      final name = _clean(button.nodes
          .where((n) => n.nodeType == Node.TEXT_NODE)
          .map((n) => n.text)
          .join(' '));
      if (name.isNotEmpty) reactions[name] = count ?? 0;
    }
    if (reactions.isEmpty) {
      final raw = review.attributes['data-reactions'] ?? '';
      if (raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          final counts = decoded is Map ? decoded['count'] : null;
          if (counts is List) {
            const names = [
              'Nice',
              'Love it',
              'Funny',
              'Confusing',
              'Informative',
              'Well-written',
              'Creative',
            ];
            for (var i = 0; i < counts.length && i < names.length; i++) {
              reactions[names[i]] = int.tryParse('${counts[i]}') ?? 0;
            }
          }
        } catch (_) {}
      }
    }

    final image = imageOf(review.querySelector('.thumb'));
    return ReviewHtml(
      id: int.tryParse(
          review.querySelector('.btn-reaction')?.attributes['data-id'] ?? ''),
      username: username,
      userPicture: image.isEmpty ? null : image,
      timeAdded: _cleanOrNull(body.querySelector('.update_at')?.text),
      overallRating: _cleanOrNull(body.querySelector('.rating .num')?.text),
      reviewText: text,
      tags: body
          .querySelectorAll('.tags .tag')
          .map((e) => _clean(e.text))
          .where((e) => e.isNotEmpty)
          .toList(),
      reactions: reactions,
      relatedNode: related,
    );
  }

  /// Every review of a review list page (`reviews.php` or
  /// `/{category}/{id}/_/reviews`).
  static List<ReviewHtml> getReviews(Document doc) => doc
      .querySelectorAll('.review-element')
      .map(animeReviewHtmlfromHtml)
      .whereType<ReviewHtml>()
      .toList();

  static String? _titleFromUrl(String? url) {
    final uri = Uri.tryParse(url ?? '');
    final segments = uri?.pathSegments ?? const [];
    if (segments.length < 3) return null;
    return segments[2].replaceAll('_', ' ').trim();
  }

  /// One row of a `#forumTopics` table. Ported from DailyAL
  /// `forumHtmlFromHtml`.
  static ForumTopicHtml? forumHtmlFromHtml(Element row) {
    final cells = row.children.where((e) => e.localName == 'td').toList();
    if (cells.length < 4) return null;
    final topic = cells[1];
    final titleAnchor = topic
        .querySelectorAll('a')
        .firstWhere((a) => (a.attributes['href'] ?? '').contains('topicid='),
            orElse: () => Element.tag('a'));
    final id = int.tryParse(row.attributes['data-topic-id'] ?? '') ??
        MalPath.idFromUrl(titleAnchor.attributes['href']);
    if (id == null) return null;

    final last = cells[3];
    final lastHtml = last.innerHtml;
    final br = lastHtml.lastIndexOf('<br');
    String? lastTime;
    if (br >= 0) {
      final after = lastHtml.substring(br);
      lastTime = _cleanOrNull(after.substring(after.indexOf('>') + 1));
    }

    return ForumTopicHtml(
      id: id,
      title: _cleanOrNull(titleAnchor.text),
      createdBy: _cleanOrNull(topic.querySelector('.forum_postusername')?.text),
      createdTime: _cleanOrNull(topic.querySelector('.lightLink')?.text),
      replies: _intOf(cells[2].text),
      lastPostBy: _cleanOrNull(last.querySelector('a')?.text),
      lastPostTime: lastTime,
    );
  }

  static List<ForumTopicHtml> _forumTopics(Element? element) =>
      element
          ?.querySelector('#forumTopics')
          ?.querySelectorAll('tr')
          .map(forumHtmlFromHtml)
          .whereType<ForumTopicHtml>()
          .toList() ??
      const [];

  // ---------------------------------------------------------------------------
  // Clubs
  // ---------------------------------------------------------------------------

  /// A club page (`clubs.php?cid=<id>`). Ported from DailyAL
  /// `parseClubPage` and `_getClubDetails`.
  static ClubPageHtml? parseClubPage(Document doc) {
    final wrapper = doc.body?.querySelector('#contentWrapper');
    final content = wrapper?.querySelector('#content');
    if (wrapper == null || content == null) return null;
    final columns = content
        .querySelector('table tr')
        ?.children
        .where((e) => e.localName == 'td')
        .toList();
    if (columns == null || columns.length < 2) return null;
    final left = columns[0];
    final right = columns[1];
    final headers = left.querySelectorAll('.normal_header');

    final membersHeader = _headerContaining(headers, 'Club Members');
    final picturesHeader = _headerContaining(headers, 'Club Pictures');
    final commentsHeader = _headerContaining(headers, 'Club Comments');

    return ClubPageHtml(
      title: _cleanOrNull(wrapper.querySelector('h1.h1')?.text),
      information: left.querySelector('.clearfix')?.innerHtml.trim(),
      members: membersHeader?.nextElementSibling
              ?.querySelectorAll('.borderClass')
              .map(_userOf)
              .whereType<MalUserRef>()
              .toList() ??
          const [],
      pictures: picturesHeader?.nextElementSibling
              ?.querySelectorAll('.picSurround')
              .map(imageOf)
              .where((e) => !e.isEmpty)
              .toList() ??
          const [],
      forumTopics: _forumTopics(left),
      comments: _comments(commentsHeader?.nextElementSibling),
      details: _clubDetails(right),
    );
  }

  static ClubDetailsHtml _clubDetails(Element right) {
    final headers = right.querySelectorAll('.normal_header');
    final stats = <String, String>{};
    for (final row in right.querySelectorAll('.spaceit_pad')) {
      final label = row.querySelector('.dark_text');
      if (label == null) continue;
      final key = _clean(label.text).replaceAll(':', '').toLowerCase();
      stats[key] = _clean(row.text.replaceFirst(label.text, ''));
    }

    final staff = <ClubStaffHtml>[];
    var current = _headerContaining(headers, 'Club Staff')?.nextElementSibling;
    var guard = 0;
    while (current != null &&
        !current.classes.contains('normal_header') &&
        guard++ < 50) {
      final user = _userOf(current.querySelector('a'));
      if (user != null) {
        final position = _clean(current.text)
            .replaceFirst(user.username, '')
            .trim()
            .replaceAll(RegExp(r'^\(|\)$'), '')
            .trim();
        staff.add(ClubStaffHtml(
          user: user,
          position: position.isEmpty ? null : position,
        ));
      }
      current = current.nextElementSibling;
    }

    final picture = imageOf(right);
    return ClubDetailsHtml(
      picture: picture.isEmpty ? null : picture,
      members: _intOf(stats['members']),
      pictures: _intOf(stats['pictures']),
      category: stats['category'],
      created: stats['created'],
      staff: staff,
      animeRelations:
          _relations(_headerContaining(headers, 'Anime Relations'), 'anime'),
      mangaRelations:
          _relations(_headerContaining(headers, 'Manga Relations'), 'manga'),
      characterRelations: _relations(
          _headerContaining(headers, 'Character Relations'), 'character'),
    );
  }

  static List<MalNodeRef> _relations(Element? header, String category) {
    final list = <MalNodeRef>[];
    var current = header?.nextElementSibling;
    var guard = 0;
    while (current != null &&
        current.localName != 'br' &&
        !current.classes.contains('normal_header') &&
        guard++ < 200) {
      final anchor = current.querySelector('a');
      final segments = Uri.tryParse(anchor?.attributes['href'] ?? '')
              ?.pathSegments
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [];
      if (anchor != null &&
          segments.length >= 2 &&
          segments[0] == category) {
        final id = int.tryParse(segments[1]);
        if (id != null) {
          list.add(MalNodeRef(
            id: id,
            title: _cleanOrNull(anchor.text),
            category: category,
          ));
        }
      }
      current = current.nextElementSibling;
    }
    return list;
  }

  static List<ClubCommentHtml> _comments(Element? element) {
    if (element == null) return const [];
    final comments = <ClubCommentHtml>[];
    for (final e in element.querySelectorAll('div[id^="comment"]')) {
      final id = int.tryParse(e.id.replaceAll('comment', ''));
      if (id == null) continue;
      final pic = e.querySelector('.picSurround');
      final cell = pic?.parent?.nextElementSibling?.clone(true);
      final small = cell?.querySelector('small');
      final longAgo = _cleanOrNull(small?.text.replaceAll('|', ''));
      cell?.children.firstOrNull?.remove();
      comments.add(ClubCommentHtml(
        id: id,
        by: _userOf(pic),
        longAgo: longAgo,
        content: cell?.innerHtml.trim(),
      ));
    }
    comments.sort((a, b) => b.id.compareTo(a.id));
    return comments;
  }

  /// "See all" pages of a club: [type] is `members`, `forum` or `comments`.
  ///
  /// Ported from DailyAL `parseClubPageViewAll`. Returns
  /// [MalUserRef], [ForumTopicHtml] or [ClubCommentHtml] items.
  static List<Object> parseClubPageViewAll(Document doc, String type) {
    final body = doc.body;
    if (body == null) return const [];
    switch (type) {
      case 'members':
        return body
                .querySelector('#content')
                ?.querySelectorAll('td.borderClass')
                .map(_userOf)
                .whereType<MalUserRef>()
                .toList() ??
            const [];
      case 'forum':
        return _forumTopics(body);
      case 'comments':
        return _comments(body.querySelector('#content'));
    }
    return const [];
  }

  // ---------------------------------------------------------------------------
  // Users, search and schedules
  // ---------------------------------------------------------------------------

  /// "About me" of `/profile/<username>`. Ported from DailyAL
  /// `parseUserAboutPage`.
  static UserAboutHtml parseUserAboutPage(Document doc) {
    final classic =
        doc.querySelector('.user-profile-about .word-break')?.innerHtml.trim();
    if (classic != null && classic.isNotEmpty) {
      return UserAboutHtml(about: classic);
    }
    final modern = doc.querySelector('#modern-about-me')?.innerHtml.trim();
    if (modern != null && modern.isNotEmpty) {
      return UserAboutHtml(about: modern, modern: true);
    }
    return const UserAboutHtml();
  }

  /// MAL "all" search (`/search/all?q=`). Ported from DailyAL
  /// `allSearchResultFromHtml`; the category and id now come from the
  /// `data-l-content-type` / `data-l-content-id` attributes MAL added.
  static SearchAllResult allSearchResultFromHtml(Document doc) {
    final results = {
      for (final c in SearchAllResult.categories) c: <SearchAllItem>[],
    };
    for (final item in doc.querySelectorAll('article .list')) {
      final link = item.querySelector('.information a[data-l-content-type]') ??
          item.querySelector('a[data-l-content-type]');
      if (link == null) continue;
      final category = link.attributes['data-l-content-type'];
      final id = int.tryParse(link.attributes['data-l-content-id'] ?? '') ??
          MalPath.idFromUrl(link.attributes['href']);
      final list = results[category];
      if (list == null || id == null) continue;

      final title = _clean(link.text);
      final image = imageOf(item.querySelector('.picSurround'));
      final cleanedImage = image.isEmpty
          ? null
          : ImageSet(
              medium: _stripResize(image.medium),
              large: _stripResize(image.large),
            );

      if (category == 'anime' || category == 'manga') {
        final infoEl = item.querySelector('.information .fn-grey4');
        final typeAnchor = infoEl?.querySelector('a');
        final text = _clean(infoEl?.text);
        list.add(SearchAllItem(
          id: id,
          title: title,
          image: cleanedImage,
          mediaType: _cleanOrNull(typeAnchor?.text),
          numEpisodes: int.tryParse(
              RegExp(r'\((\d+)\s*(eps|vols|chs)').firstMatch(text)?.group(1) ??
                  ''),
          mean: double.tryParse(
              RegExp(r'Scored\s+([\d.]+)').firstMatch(text)?.group(1) ?? ''),
          numListUsers: _intOf(
              RegExp(r'([\d,]+)\s+members').firstMatch(text)?.group(1)),
        ));
      } else {
        final info = item.querySelector('.information');
        final extras = info?.children
                .where((e) => e.localName == 'div' && e != link)
                .map((e) => _textWithBreaks(e)
                    .replaceAll('»', '')
                    .split('\n')
                    .map((l) => l.trim())
                    .where((l) => l.isNotEmpty)
                    .join(' · '))
                .where((e) => e.isNotEmpty)
                .join(' · ') ??
            '';
        list.add(SearchAllItem(
          id: id,
          title: title,
          image: cleanedImage,
          additional: extras.isEmpty ? null : extras,
        ));
      }
    }
    return SearchAllResult(results);
  }

  static String? _stripResize(String? url) =>
      url?.replaceFirst(RegExp(r'/r/\d+x\d+'), '').split('?').first;

  /// Upcoming episodes of a LiveChart.me season page
  /// (`https://www.livechart.me/<season>-<year>/<type>`).
  ///
  /// Ported from DailyAL `parseLiveChartSchedule`; cards without a countdown
  /// or without any related link are skipped, as in DailyAL.
  static List<LiveChartEpisode> parseLiveChartSchedule(Document doc) {
    final result = <LiveChartEpisode>[];
    for (final card in doc.querySelectorAll('.anime-card')) {
      final time = card.querySelector('.episode-countdown time');
      final timestamp = int.tryParse(time?.attributes['data-timestamp'] ?? '');
      final info = _clean(card.querySelector('.release-schedule-info')?.text);
      final episode = int.tryParse(
          RegExp(r'EP\s*(\d+)').firstMatch(info)?.group(1) ?? '');
      if (timestamp == null || episode == null) continue;

      final links = <String, String>{};
      for (final a in card.querySelectorAll('.related-links a')) {
        final href = a.attributes['href'];
        final kind = a.className.replaceAll('-icon', '').trim();
        if (href != null && kind.isNotEmpty) links[kind] = href;
      }
      if (links.isEmpty) continue;

      result.add(LiveChartEpisode(
        timestamp: timestamp,
        episode: episode,
        title: _cleanOrNull(card.querySelector('.main-title')?.text),
        malId: MalPath.idFromUrl(links['mal']),
        relatedLinks: links,
      ));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Stats page (`/anime/<id>/x/stats`, `/manga/<id>/x/stats`)
  // ---------------------------------------------------------------------------

  /// Status labels of the "Summary Stats" block, anime and manga wording,
  /// to the JSON key they fill.
  static const _statusLabels = {
    'watching': 'watching',
    'reading': 'watching',
    'completed': 'completed',
    'on-hold': 'on_hold',
    'dropped': 'dropped',
    'plan to watch': 'plan_to_watch',
    'plan to read': 'plan_to_watch',
    'total': 'total',
  };

  static final _percent = RegExp(r'(\d+(?:\.\d+)?)\s*%');
  static final _votes = RegExp(r'\(\s*([\d,]+)\s*votes?\s*\)');

  /// Score distribution (votes per score, highest first) and status counts
  /// of MAL's stats page. Null when the page has neither block (not a stats
  /// page, or a layout MAL changed); a title nobody scored yet gives an
  /// empty score list.
  static ContentStatsHtml? parseContentStats(Document doc) {
    final counts = <String, int>{};
    for (final pad in _summaryStatsRows(doc)) {
      final label = _clean(pad.querySelector('span.dark_text')?.text)
          .replaceAll(':', '')
          .trim()
          .toLowerCase();
      final key = _statusLabels[label];
      if (key == null || counts.containsKey(key)) continue;
      final value = _intOf(pad.nodes
          .where((n) => n is! Element || !n.classes.contains('dark_text'))
          .map((n) => n.text)
          .join());
      if (value != null) counts[key] = value;
    }

    final scores = <ScoreVotesHtml>[];
    final table = doc.querySelector('table.score-stats');
    for (final row in table?.querySelectorAll('tr') ?? const <Element>[]) {
      final score = int.tryParse(
          _clean(row.querySelector('td.score-label')?.text));
      final text = _clean(row.text);
      final votes = _votes.firstMatch(text)?.group(1)?.replaceAll(',', '');
      if (score == null || score < 1 || score > 10 || votes == null) continue;
      scores.add(ScoreVotesHtml(
        score: score,
        votes: int.parse(votes),
        percentage: double.tryParse(_percent.firstMatch(text)?.group(1) ?? '') ?? 0,
      ));
    }
    scores.sort((a, b) => b.score.compareTo(a.score));

    if (counts.isEmpty && table == null) return null;
    final statuses = StatusCountsHtml(
      watching: counts['watching'] ?? 0,
      completed: counts['completed'] ?? 0,
      onHold: counts['on_hold'] ?? 0,
      dropped: counts['dropped'] ?? 0,
      planToWatch: counts['plan_to_watch'] ?? 0,
      total: counts['total'] ??
          counts.values.fold<int>(0, (sum, value) => sum + value),
    );
    return ContentStatsHtml(scores: scores, statuses: statuses);
  }

  /// The `.spaceit_pad` rows between the "Summary Stats" heading and the
  /// next heading (so the sidebar's own rows are never read).
  static List<Element> _summaryStatsRows(Document doc) {
    final heading = doc.getElementById('summary_stats') ??
        doc
            .querySelectorAll('h2')
            .where((h) => _clean(h.text) == 'Summary Stats')
            .firstOrNull;
    final rows = <Element>[];
    var next = heading?.nextElementSibling;
    while (next != null && next.localName != 'h2') {
      if (next.classes.contains('spaceit_pad')) rows.add(next);
      next = next.nextElementSibling;
    }
    return rows;
  }

  // ---------------------------------------------------------------------------
  // Global recommendations
  // ---------------------------------------------------------------------------

  /// The feed of `recommendations.php?s=recentrecs&t=<category>`: one `.borderClass` block
  /// per recommendation, a two-cell table (liked title, recommended title), the user's text
  /// and a "rec by <user> - <time>" line. Blocks that do not read as a pair are skipped.
  static List<GlobalRecommendationHtml> parseRecentRecommendations(
    Document doc,
    String category,
  ) {
    final out = <GlobalRecommendationHtml>[];
    for (final block in doc.querySelectorAll('div.borderClass')) {
      try {
        final cells = block.querySelectorAll('table td');
        if (cells.length < 2) continue;
        final source = _recommendationNode(cells[0], category);
        final recommended = _recommendationNode(cells[1], category);
        if (source == null || recommended == null) continue;

        final textElement = block.querySelector('.recommendations-user-recs-text');
        final footer = block.querySelector('.lightLink.spaceit');
        final userLink = footer?.querySelector('a[href*="/profile/"]');
        final reportHref =
            footer?.querySelector('a[href*="id="]')?.attributes['href'] ?? '';
        final footerText = _clean(footer?.text);
        final dash = footerText.lastIndexOf(' - ');

        out.add(GlobalRecommendationHtml(
          id: int.tryParse(RegExp(r'[?&]id=(\d+)').firstMatch(reportHref)?.group(1) ?? ''),
          category: category,
          source: source,
          recommended: recommended,
          text: textElement == null ? null : _textWithBreaks(textElement),
          username: _cleanOrNull(userLink?.text),
          timeAdded: dash < 0 ? null : _cleanOrNull(footerText.substring(dash + 3)),
        ));
      } catch (_) {
        // A block that changed layout is skipped, the rest of the feed stays.
      }
    }
    return out;
  }

  static MalNodeRef? _recommendationNode(Element cell, String category) {
    final link = cell.querySelector('a[href*="/$category/"]');
    final id = MalPath.idFromUrl(link?.attributes['href']);
    if (link == null || id == null) return null;
    final title = _cleanOrNull(cell.querySelector('strong')?.text) ??
        _cleanOrNull(link.attributes['title']);
    final img = cell.querySelector('img');
    final src = img?.attributes['data-src'] ?? img?.attributes['src'];
    // `...t.jpg` is the 50 px thumbnail; the 2x source of the srcset is sharper.
    final large = (img?.attributes['data-srcset'] ?? '')
        .split(',')
        .map((e) => e.trim().split(' ').first)
        .where((e) => e.startsWith('http'))
        .fold<String?>(null, (_, e) => e);
    return MalNodeRef(
      id: id,
      title: title,
      category: category,
      image: src == null || src.contains('spacer.gif')
          ? null
          : ImageSet(medium: src, large: large),
    );
  }
}
