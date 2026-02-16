import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as htmlParser;
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/MAL/models/club/club_data.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/html_parsers.dart';

/// MAL Clubs API client (HTML scraping only, no official API).
class MalClubsApi {
  static const String _clubsUrl = 'https://myanimelist.net/clubs.php';

  /// Fetch clubs list from MAL HTML page.
  Future<ClubListHtml?> getClubs({int page = 1}) async {
    try {
      final url = '$_clubsUrl?p=$page';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final document = htmlParser.parse(response.body);
        final result = HtmlParsers.parseClubList(document);
        return ClubListHtml.fromJson(result);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MalClubsApi: getClubs error: $e');
    }
    return null;
  }

  /// Fetch club detail page from MAL HTML.
  Future<ClubData?> getClubData(int clubId) async {
    try {
      final url = '$_clubsUrl?cid=$clubId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final document = htmlParser.parse(response.body);
        return _parseClubPage(document);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MalClubsApi: getClubData error: $e');
    }
    return null;
  }

  /// Fetch "view all" page for club sub-sections.
  Future<List<dynamic>?> getClubViewAll(
      int clubId, String type, int offset) async {
    try {
      String url;
      if (type == 'forum') {
        url =
            'https://myanimelist.net/forum/?clubid=$clubId&show=$offset';
      } else {
        url =
            '$_clubsUrl?action=view&t=$type&id=$clubId&show=$offset';
      }
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final document = htmlParser.parse(response.body);
        return _parseClubViewAll(document, type);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MalClubsApi: getClubViewAll error: $e');
    }
    return null;
  }

  // --- HTML Parsing (matching DailyAL's parseClubPage) ---

  ClubData? _parseClubPage(Document document) {
    try {
      final body = document.body;
      if (body == null) return null;

      final wrapper = body.querySelector('#contentWrapper');
      if (wrapper == null) return null;

      String? title = wrapper.querySelector('h1.h1')?.text.trim();
      final content = wrapper.querySelector('#content');
      if (content == null) return null;

      final tds = content.querySelector('table tbody tr')?.children.toList();
      if (tds == null || tds.length < 2) return null;

      final left = tds[0];
      final right = tds[1];

      // Information
      String? clubInfo = left.querySelector('.clearfix')?.innerHtml.trim();

      // Headers for different sections
      final headers = left.querySelectorAll('.normal_header');

      // Members
      final membersSection = headers.length > 1
          ? headers[1].nextElementSibling
          : null;
      final members = membersSection
              ?.querySelectorAll('.borderClass')
              .map((e) => _getUserFromElement(e))
              .toList() ??
          [];

      // Forum topics
      final forumTopics = _parseForumTopics(left);

      // Comments
      final commentsHeader = _getElementByContent(headers, 'Club Comments');
      final commentsSection = commentsHeader?.nextElementSibling;
      final comments = _parseComments(commentsSection);

      // Details (right column)
      final details = _parseClubDetails(right);

      return ClubData(
        title: title,
        information: clubInfo,
        members: members,
        forumTopics: forumTopics,
        comments: comments,
        details: details,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('MalClubsApi: _parseClubPage error: $e');
      return null;
    }
  }

  List<ClubForumTopic> _parseForumTopics(Element ele) {
    try {
      return ele
              .querySelector('#forumTopics')
              ?.querySelectorAll('tr')
              .map((e) => _forumTopicFromRow(e))
              .where((e) => e.id != null)
              .toList() ??
          [];
    } catch (e) {
      return [];
    }
  }

  ClubForumTopic _forumTopicFromRow(Element row) {
    try {
      final cells = row.querySelectorAll('td');
      if (cells.length < 2) return ClubForumTopic();

      // cells[0] is the watch/notification icon column.
      // cells[1] contains the topic title link, created-by username, and date.
      final topicCell = cells[1];
      final topicLink = topicCell.querySelector('a');
      final href = topicLink?.attributes['href'] ?? '';
      final topicIdMatch = RegExp(r'topicid=(\d+)').firstMatch(href);
      final id = topicIdMatch != null
          ? int.tryParse(topicIdMatch.group(1)!)
          : null;
      final title = topicLink?.text.trim();

      String? createdBy;
      final createdByEl =
          topicCell.querySelector('.forum_postusername');
      createdBy = createdByEl?.text.trim();

      String? replies;
      if (cells.length > 2) {
        replies = cells[2].text.trim();
      }

      String? lastPostBy;
      String? lastPostTime;
      if (cells.length > 3) {
        lastPostBy = cells[3].querySelector('a')?.text.trim();
        final innerHtml = cells[3].innerHtml;
        final brIndex = innerHtml.lastIndexOf('<br');
        if (brIndex != -1) {
          // Extract text after the last <br> tag
          final afterBr = innerHtml.substring(brIndex);
          final closingIndex = afterBr.indexOf('>');
          if (closingIndex != -1) {
            lastPostTime = afterBr
                .substring(closingIndex + 1)
                .replaceAll(RegExp(r'<[^>]*>'), '')
                .trim();
          }
        }
      }

      return ClubForumTopic(
        id: id,
        title: title,
        createdBy: createdBy,
        replies: replies,
        lastPostBy: lastPostBy,
        lastPostTime: lastPostTime,
      );
    } catch (e) {
      return ClubForumTopic();
    }
  }

  ClubExtra _parseClubDetails(Element element) {
    final headers = element.querySelectorAll('.normal_header');

    // Stats
    final stats = _getElementByContent(headers, 'Club Stats');
    int? memberCount;
    int? pictureCount;
    String? category;
    String? created;

    if (stats != null) {
      var current = stats.nextElementSibling;
      if (current != null) {
        memberCount = int.tryParse(
            current.text.replaceAll('Members:', '').trim());
        current = current.nextElementSibling;
      }
      if (current != null) {
        pictureCount = int.tryParse(
            current.text.replaceAll('Pictures:', '').trim());
        current = current.nextElementSibling;
      }
      if (current != null) {
        category = current.text.replaceAll('Category:', '').trim();
        current = current.nextElementSibling;
      }
      if (current != null) {
        created = current.text.trim();
      }
    }

    // Staff
    final staffHeader = _getElementByContent(headers, 'Club Staff');
    final typeHeader = _getElementByContent(headers, 'Club Type');
    final staffList = <ClubStaff>[];
    _populateStaffList(staffHeader, typeHeader, staffList);

    // Relations
    final animeList = <ClubRelation>[];
    final mangaList = <ClubRelation>[];
    final characterList = <ClubRelation>[];
    _populateRelationsList(
        _getElementByContent(headers, 'Anime Relations'), animeList, 'anime');
    _populateRelationsList(
        _getElementByContent(headers, 'Manga Relations'), mangaList, 'manga');
    _populateRelationsList(
        _getElementByContent(headers, 'Character Relations'),
        characterList,
        'character');

    // Picture
    String? pictureUrl;
    final imgEl = element.querySelector('img');
    if (imgEl != null) {
      pictureUrl = imgEl.attributes['data-src'] ?? imgEl.attributes['src'];
    }

    return ClubExtra(
      pictureUrl: pictureUrl,
      members: memberCount,
      category: category,
      pictures: pictureCount,
      created: created,
      staffs: staffList,
      clubRelations: ClubRelations(
        anime: animeList,
        manga: mangaList,
        character: characterList,
      ),
    );
  }

  void _populateStaffList(
      Element? staff, Element? type, List<ClubStaff> staffList) {
    var currentStaff = staff?.nextElementSibling;
    int count = 0;
    while (type != null &&
        currentStaff != null &&
        currentStaff != type &&
        count < 20) {
      final staffA = currentStaff.querySelector('a');
      final username = staffA?.text.trim();
      staffA?.remove();
      final position = currentStaff.text.trim();
      if (username != null && username.isNotEmpty) {
        final imageUrl =
            staffA?.querySelector('img')?.attributes['data-src'] ??
                staffA?.querySelector('img')?.attributes['src'];
        staffList.add(ClubStaff(
          user: ClubMember(username: username, imageUrl: imageUrl),
          position: position,
        ));
      }
      currentStaff = currentStaff.nextElementSibling;
      count++;
    }
  }

  void _populateRelationsList(
      Element? startElement, List<ClubRelation> list, String category) {
    var currentElement = startElement?.nextElementSibling;
    int count = 0;
    while (currentElement != null &&
        currentElement.localName?.toUpperCase() != 'BR' &&
        !currentElement.classes.contains('normal_header') &&
        count < 101) {
      final anchor = currentElement.querySelector('a');
      if (anchor != null) {
        final href = anchor.attributes['href'];
        if (href != null) {
          final uri = Uri.tryParse(href);
          if (uri != null && uri.pathSegments.isNotEmpty) {
            if (uri.pathSegments[0] == category) {
              final id = uri.pathSegments.length > 1
                  ? int.tryParse(uri.pathSegments[1])
                  : null;
              if (id != null) {
                list.add(ClubRelation(id: id, title: anchor.text.trim()));
              }
            }
          }
        }
      }
      currentElement = currentElement.nextElementSibling;
      count++;
    }
  }

  List<ClubComment> _parseComments(Element? element) {
    if (element == null) return [];
    try {
      final comments = <Element>[];
      comments.addAll(element.querySelectorAll('.bgColor1'));
      comments.addAll(element.querySelectorAll('.bgNone'));

      final formatted = comments.map((e) {
        String idStr = e.id.replaceAll('comment', '');
        final picLeading = e.querySelector('.picSurround');
        final user = _getUserFromElement(picLeading);
        final parentTD = picLeading?.parent?.nextElementSibling;
        final small = parentTD?.children.isNotEmpty == true
            ? parentTD!.children.first.querySelector('small')
            : null;
        final longAgo = small?.text.replaceAll('|', '').trim();
        small?.parent?.remove();
        final comment = parentTD?.innerHtml.trim();

        return ClubComment(
          id: int.tryParse(idStr),
          by: user,
          longAgo: longAgo,
          content: comment,
        );
      }).where((e) => e.id != null).toList();

      formatted.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
      return formatted;
    } catch (e) {
      return [];
    }
  }

  ClubMember _getUserFromElement(Element? element) {
    if (element == null) return ClubMember();

    String? username;
    String? imageUrl;

    final anchor = element.querySelector('a');
    if (anchor != null) {
      final href = anchor.attributes['href'] ?? '';
      if (href.contains('/profile/')) {
        username = href.split('/profile/').last.replaceAll('/', '');
      } else {
        username = anchor.text.trim();
      }
    }

    final img = element.querySelector('img');
    if (img != null) {
      imageUrl = img.attributes['data-src'] ?? img.attributes['src'];
    }

    if (username == null || username.isEmpty) {
      username = element.text.trim();
    }

    return ClubMember(username: username, imageUrl: imageUrl);
  }

  Element? _getElementByContent(
      List<Element> elements, String searchText) {
    for (final e in elements) {
      if (e.text.toLowerCase().contains(searchText.toLowerCase())) {
        return e;
      }
    }
    return null;
  }

  List<dynamic>? _parseClubViewAll(Document document, String type) {
    try {
      final body = document.body;
      if (body == null) return [];

      switch (type) {
        case 'members':
          return body
                  .querySelector('#content')
                  ?.querySelectorAll('.borderClass')
                  .map((e) => _getUserFromElement(e))
                  .where((e) => e.username != null && e.username!.isNotEmpty)
                  .toList() ??
              [];
        case 'forum':
          return _parseForumTopics(body);
        case 'comments':
          return _parseComments(body.querySelector('#content'));
        default:
          return [];
      }
    } catch (e) {
      return [];
    }
  }
}
