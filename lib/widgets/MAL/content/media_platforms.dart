import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
// import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';
// import 'package:mywatchlist/utilities/url_launcher.dart';

enum LinkType {
  resources,
  availableAt,
  streaming,
  otherLists,
}

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
  late List<AnimeLink> displayedLinks;
  LinkType preferredLinkType =
      LinkType.streaming; // You can make this configurable

  @override
  void initState() {
    super.initState();

    categorizedLinks = [
      ...widget.links,
      ..._adaptRelatedLinks(widget.relatedLinks),
    ].fold<Map<LinkType, List<AnimeLink>>>(
        {}, (map, e) => map..putIfAbsent(e.linkType, () => []).add(e));
    _setDisplayedLinks();
  }

  void _setDisplayedLinks() {
    displayedLinks = categorizedLinks[preferredLinkType] ??
        categorizedLinks[LinkType.streaming] ??
        categorizedLinks[LinkType.availableAt] ??
        categorizedLinks[LinkType.resources] ??
        categorizedLinks[LinkType.otherLists] ??
        [];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: Row(
          children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 25),
                children: displayedLinks
                    .where((e) => e.url.isNotEmpty && e.name.isNotEmpty)
                    .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 7),
                          child: _buildLinkImage(context: context, link: e),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              height: 40,
              width: 40,
              child: ShadowButton(
                onPressed: () async {
                  await showModalBottomSheet(
                      context: context,
                      builder: (context) => DetailedLinks(
                            categorizedLinks: categorizedLinks,
                          ),
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20))));
                  _setDisplayedLinks();
                  if (mounted) setState(() {});
                },
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                child: const Icon(Icons.more, size: 20.0),
              ),
            ),
            const SizedBox(width: 20),
          ],
        ),
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

class DetailedLinks extends StatefulWidget {
  final Map<LinkType, List<AnimeLink>> categorizedLinks;

  const DetailedLinks({
    super.key,
    required this.categorizedLinks,
  });

  @override
  State<DetailedLinks> createState() => _DetailedLinksState();
}

class _DetailedLinksState extends State<DetailedLinks> {
  final _linkTitleMap = {
    LinkType.resources: 'Resources',
    LinkType.availableAt: 'Available At',
    LinkType.streaming: 'Streaming Platforms',
    LinkType.otherLists: 'Other Lists',
  };
  late List<MapEntry<LinkType, String>> _sortedEntries;
  LinkType preferredLinkType =
      LinkType.streaming; // You can make this configurable

  @override
  void initState() {
    super.initState();
    _sortedEntries = _linkTitleMap.entries.toList()
      ..sort((a, b) => a.key == preferredLinkType
          ? -1
          : b.key == preferredLinkType
              ? 1
              : 0);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 700.0,
      child: Material(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Text('More Links',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              for (int i = 0; i < _sortedEntries.length; i++)
                if (!nullOrEmpty(
                    widget.categorizedLinks[_sortedEntries[i].key]))
                  ..._linkContent(_sortedEntries[i].key),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _linkContent(LinkType type) {
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          Text(_linkTitleMap[type] ?? 'UNKNOWN',
              style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Checkbox(
            value: type == preferredLinkType,
            onChanged: (value) {
              if (value == true) {
                preferredLinkType = type;
                setState(() {});
              }
            },
          ),
        ],
      ),
    );

    return [
      header,
      const SizedBox(height: 10),
      _buildLinkCards(widget.categorizedLinks[type] ?? []),
    ];
  }

  Widget _buildLinkCards(List<AnimeLink> streaming) {
    return SizedBox(
      height: 105.0,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        scrollDirection: Axis.horizontal,
        itemCount: streaming.length,
        itemBuilder: (context, index) => _buildCard(streaming[index]),
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
              _buildLinkImage(
                context: context,
                link: link,
                size: 45.0,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: Text(
                  link.name,
                  textAlign: TextAlign.center,
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
