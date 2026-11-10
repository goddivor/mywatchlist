import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mwl_commons/src/model/html/anime_detailed_html.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';

export 'package:mwl_commons/src/model/html/anime_detailed_html.dart' show LinkType;

class AnimeLink {
  final String name;
  final String url;
  final LinkType linkType;
  final String? imageUrl;

  AnimeLink({
    required this.name,
    required this.url,
    required this.linkType,
    this.imageUrl,
  });
}

class RelatedLinks {
  final String? anilist;
  final String? animePlanet;
  final String? anisearch;
  final String? kitsu;

  RelatedLinks({
    this.anilist,
    this.animePlanet,
    this.anisearch,
    this.kitsu,
  });

  bool get isEmpty =>
      anilist == null && animePlanet == null && anisearch == null && kitsu == null;

  /// Reads the link kinds LiveChart gives for an episode (`anilist`,
  /// `animeplanet`, `anisearch`, `kitsu`; other kinds are ignored). Null when
  /// none of the four is present.
  static RelatedLinks? fromLiveChart(Map<String, String> links) {
    String? pick(String kind) {
      for (final entry in links.entries) {
        final key = entry.key.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
        if (key == kind && entry.value.isNotEmpty) return entry.value;
      }
      return null;
    }

    final result = RelatedLinks(
      anilist: pick('anilist'),
      animePlanet: pick('animeplanet'),
      anisearch: pick('anisearch'),
      kitsu: pick('kitsu'),
    );
    return result.isEmpty ? null : result;
  }
}

/// Related links of the airing schedule (LiveChart, through the backend),
/// found by MyAnimeList id. The season is fetched once per session and shared
/// by every detail page.
///
/// ```dart
/// final links = await ScheduleLinks.forMalId(anime.id); // null when not airing
/// ```
abstract final class ScheduleLinks {
  static Future<Map<int, RelatedLinks>>? _season;

  /// The schedule source; tests replace it.
  @visibleForTesting
  static Future<List<LiveChartEpisode>> Function() source =
      () => MwlApi.i.getLiveChartSchedule();

  /// Links of [malId], or null when it is not on the schedule or the request
  /// failed (a failure is retried on the next call).
  static Future<RelatedLinks?> forMalId(int malId) async {
    try {
      final season = await (_season ??= _load());
      return season[malId];
    } catch (_) {
      _season = null;
      return null;
    }
  }

  static Future<Map<int, RelatedLinks>> _load() async {
    final map = <int, RelatedLinks>{};
    for (final episode in await source()) {
      final id = episode.malId;
      final links = RelatedLinks.fromLiveChart(episode.relatedLinks);
      if (id != null && links != null) map[id] = links;
    }
    return map;
  }

  @visibleForTesting
  static void reset() => _season = null;
}

class AddtionalMediaPlatforms extends StatefulWidget {
  final List<AnimeLink> links;
  final RelatedLinks? relatedLinks;

  const AddtionalMediaPlatforms(
    this.links, {
    Key? key,
    this.relatedLinks,
  }) : super(key: key);

  @override
  State<AddtionalMediaPlatforms> createState() =>
      _AddtionalMediaPlatformsState();
}

class _AddtionalMediaPlatformsState extends State<AddtionalMediaPlatforms> {
  late Map<LinkType, List<AnimeLink>> categorizedLinks;

  @override
  void initState() {
    super.initState();
    _categorize();
  }

  @override
  void didUpdateWidget(AddtionalMediaPlatforms old) {
    super.didUpdateWidget(old);
    if (old.links != widget.links || old.relatedLinks != widget.relatedLinks) {
      _categorize();
    }
  }

  void _categorize() {
    categorizedLinks = [
      ...widget.links,
      ..._adaptRelatedLinks(widget.relatedLinks),
    ].fold<Map<LinkType, List<AnimeLink>>>(
        {}, (map, e) => map..putIfAbsent(e.linkType, () => []).add(e));
  }

  List<AnimeLink> _displayed(LinkType preferred) {
    final links = categorizedLinks[preferred] ??
        categorizedLinks[LinkType.streaming] ??
        categorizedLinks[LinkType.availableAt] ??
        categorizedLinks[LinkType.resources] ??
        categorizedLinks[LinkType.otherLists] ??
        const <AnimeLink>[];
    return links.where((e) => e.url.isNotEmpty && e.name.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final preferred = context.select<PreferencesBloc?, LinkType>((bloc) =>
        (bloc?.state ?? Preferences.current).general.preferredLinkType);
    final displayed = _displayed(preferred);
    return SizedBox(
      height: 45,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 25),
              itemCount: displayed.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                child: _buildLinkImage(context: context, link: displayed[i]),
              ),
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            height: 40,
            width: 40,
            child: ShadowButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.8,
                ),
                builder: (context) => DetailedLinks(
                  categorizedLinks: categorizedLinks,
                  preferred: preferred,
                ),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              ),
              padding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              child: Tooltip(
                message: S.current.moreLinks,
                child: const Icon(Icons.more, size: 20.0),
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}

AnimeLink _adaptLink(
  String url,
  String name, [
  String? imageUrl,
  LinkType type = LinkType.otherLists,
]) {
  return AnimeLink(
    name: name,
    url: url,
    linkType: type,
    imageUrl: imageUrl,
  );
}

List<AnimeLink> _adaptRelatedLinks(RelatedLinks? links) {
  if (links == null) return [];
  return [
    if (links.anilist != null)
      _adaptLink(
        links.anilist!,
        'Anilist',
        getDomainAsset('Anilist', 'other_list'),
      ),
    if (links.animePlanet != null)
      _adaptLink(
        links.animePlanet!,
        'AnimePlanet',
        getDomainAsset('AnimePlanet', 'other_list'),
      ),
    if (links.anisearch != null)
      _adaptLink(
        links.anisearch!,
        'Anisearch',
        getDomainAsset('Anisearch', 'other_list'),
      ),
    if (links.kitsu != null)
      _adaptLink(
        links.kitsu!,
        'Kitsu',
        getDomainAsset('Kitsu', 'other_list'),
      ),
  ];
}

final _borderRadiusTypes = [
  LinkType.streaming,
  LinkType.otherLists,
];

Widget _buildLinkImage({
  required BuildContext context,
  required AnimeLink link,
  double? size,
}) {
  return SizedBox(
    height: size,
    width: size,
    child: link.imageUrl != null && link.imageUrl!.isNotEmpty
        ? ToolTipButton(
            message: link.name,
            onTap: () => _onLinkTap(context, link),
            child: AvatarAspect(
              url: link.imageUrl,
              useUserImageOnError: false,
              radius: _borderRadiusTypes.contains(link.linkType)
                  ? null
                  : BorderRadius.zero,
            ),
          )
        : ToolTipButton(
            message: link.name,
            onTap: () => _onLinkTap(context, link),
            child: const Icon(Icons.link),
          ),
  );
}

void _onLinkTap(BuildContext context, AnimeLink link) {
  return launchURLWithConfirmation(link.url, context: context);
}

/// Bottom sheet listing every link by category. The checkbox of a category
/// saves it as the `preferredLinkType` preference (the one shown on the page).
class DetailedLinks extends StatefulWidget {
  final Map<LinkType, List<AnimeLink>> categorizedLinks;
  final LinkType preferred;

  const DetailedLinks({
    super.key,
    required this.categorizedLinks,
    this.preferred = LinkType.streaming,
  });

  @override
  State<DetailedLinks> createState() => _DetailedLinksState();
}

class _DetailedLinksState extends State<DetailedLinks> {
  late LinkType _preferred = widget.preferred;

  String _titleOf(LinkType type) => switch (type) {
        LinkType.resources => S.current.Resources,
        LinkType.availableAt => S.current.Available_At,
        LinkType.streaming => S.current.Links_Streaming,
        LinkType.otherLists => S.current.Other_Lists,
      };

  void _prefer(LinkType type) {
    setState(() => _preferred = type);
    Preferences.bloc?.add(GeneralPreferencesChanged(
        (p) => p.copyWith(preferredLinkType: type)));
  }

  @override
  Widget build(BuildContext context) {
    final types = LinkType.values
        .where((t) => !nullOrEmpty(widget.categorizedLinks[t]))
        .toList()
      ..sort((a, b) => a == _preferred
          ? -1
          : b == _preferred
              ? 1
              : 0);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(S.current.moreLinks,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          for (final type in types) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_titleOf(type),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Tooltip(
                    message: S.current.Links_Set_Preferred,
                    child: Checkbox(
                      value: type == _preferred,
                      onChanged: (value) {
                        if (value == true) _prefer(type);
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 105,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: widget.categorizedLinks[type]!.length,
                itemBuilder: (context, i) =>
                    _buildCard(widget.categorizedLinks[type]![i]),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(AnimeLink link) {
    return SizedBox(
      width: 135.0,
      child: Card(
        child: InkWell(
          onTap: () => _onLinkTap(context, link),
          borderRadius: BorderRadius.circular(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 5),
              _buildLinkImage(context: context, link: link, size: 45.0),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: Text(
                  link.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
