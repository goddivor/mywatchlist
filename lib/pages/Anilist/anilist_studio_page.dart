import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_people_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Anilist/people/anilist_people_ui.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumMessage, ForumSkeleton;

/// Opens the AniList studio [id] in the app.
Future<void> openAnilistStudio(BuildContext context, int id) =>
    AppRoutes.push<void>(context, AnilistStudioPage(studioId: id));

/// An AniList studio: its name and favourites in the header, then every production grouped by
/// year (undated ones last), sortable, with the "main studio" and "on my list" filters. The
/// heart in the app bar adds the studio to the favourites.
class AnilistStudioPage extends StatefulWidget {
  const AnilistStudioPage({super.key, required this.studioId, this.service});

  final int studioId;
  final AnilistPeopleService? service;

  @override
  State<AnilistStudioPage> createState() => _AnilistStudioPageState();
}

class _AnilistStudioPageState extends State<AnilistStudioPage> {
  AnilistStudioDetail? _studio;
  Object? _error;
  bool _toggling = false;
  bool _onList = false;
  bool _mainOnly = false;
  AnilistPeopleSort _sort = AnilistPeopleSort.startDate;

  AnilistPeopleService get _service => widget.service ?? AnilistPeopleService.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final studio = await _service.studio(widget.studioId);
      if (mounted) setState(() => _studio = studio);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggleFavourite() async {
    final studio = _studio;
    if (studio == null || _toggling) return;
    setState(() => _toggling = true);
    final done = await toggleAnilistPersonFavourite(
        context, _service, AnilistFavouriteKind.studio, studio.id);
    if (!mounted) return;
    setState(() {
      _toggling = false;
      if (done) {
        _studio = studio.copyWith(
          isFavourite: !studio.isFavourite,
          favourites: studio.favourites + (studio.isFavourite ? -1 : 1),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final studio = _studio;
    if (studio == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null
            ? ForumMessage(
                icon: Icons.cloud_off_outlined,
                title: anilistErrorText(_error!),
                onRetry: _load,
              )
            : const ForumSkeleton(count: 6),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(studio.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          AnilistFavouriteAction(isFavourite: studio.isFavourite, onPressed: _toggleFavourite),
          IconButton(
            tooltip: s.Open_In_Browser,
            icon: const Icon(Icons.open_in_browser),
            onPressed: () =>
                openLink(context, 'https://anilist.co/studio/${studio.id}', confirm: false),
          ),
        ],
      ),
      body: AnilistPagedList<AnilistStudioWork>(
        reloadKey: (_onList, _mainOnly, _sort),
        loader: (page) => _service.studioMedia(
          widget.studioId,
          page: page,
          sort: _sort,
          mainOnly: _mainOnly,
          onList: _onList,
        ),
        groupLabel: _sort == AnilistPeopleSort.startDate
            ? (work) => work.media.year?.toString() ?? s.Alp_Tba
            : null,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.favorite, size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 6),
                  Text(s.Alp_Favourites_Count(NumberFormat.decimalPattern().format(studio.favourites))),
                ],
              ),
            ),
            AnilistFilterBar(
              onList: _service.signedIn ? _onList : null,
              onListChanged: (v) => setState(() => _onList = v),
              sort: _sort,
              onSort: (v) => setState(() => _sort = v),
              extra: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(s.Alp_Main_Studio_Only),
                    selected: _mainOnly,
                    onSelected: (v) => setState(() => _mainOnly = v),
                  ),
                ),
              ],
            ),
          ],
        ),
        itemBuilder: (context, work) => AnilistMediaTile(
          media: work.media,
          onTap: () =>
              openAnilistTitle(context, category: work.media.category, id: work.media.id),
        ),
      ),
    );
  }
}
