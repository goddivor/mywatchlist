import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_staff_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_people_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Anilist/people/anilist_people_ui.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumMessage, ForumSkeleton;

/// Opens the AniList character [id] in the app.
Future<void> openAnilistCharacter(BuildContext context, int id) =>
    AppRoutes.push<void>(context, AnilistCharacterPage(characterId: id));

/// An AniList character: Info (picture, names with the spoiler ones behind a tap, birthday,
/// age, gender, blood type, favourites, description), then the anime and the manga they
/// appear in, with their role and the voice actors of the chosen language. The heart in the
/// app bar adds them to the favourites.
class AnilistCharacterPage extends StatefulWidget {
  const AnilistCharacterPage({super.key, required this.characterId, this.service});

  final int characterId;
  final AnilistPeopleService? service;

  @override
  State<AnilistCharacterPage> createState() => _AnilistCharacterPageState();
}

class _AnilistCharacterPageState extends State<AnilistCharacterPage> {
  AnilistCharacterDetail? _character;
  Object? _error;
  bool _toggling = false;
  bool _onList = false;
  AnilistPeopleSort _sort = AnilistPeopleSort.popularity;
  String _language = 'JAPANESE';

  AnilistPeopleService get _service => widget.service ?? AnilistPeopleService.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final character = await _service.character(widget.characterId);
      if (mounted) setState(() => _character = character);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggleFavourite() async {
    final character = _character;
    if (character == null || _toggling) return;
    setState(() => _toggling = true);
    final done = await toggleAnilistPersonFavourite(
        context, _service, AnilistFavouriteKind.character, character.id);
    if (!mounted) return;
    setState(() {
      _toggling = false;
      if (done) {
        _character = character.copyWith(
          isFavourite: !character.isFavourite,
          favourites: character.favourites + (character.isFavourite ? -1 : 1),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final character = _character;
    if (character == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null
            ? ForumMessage(
                icon: Icons.cloud_off_outlined,
                title: anilistErrorText(_error!),
                onRetry: _load,
              )
            : const ForumSkeleton(count: 6, round: true),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(character.names.display, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            AnilistFavouriteAction(isFavourite: character.isFavourite, onPressed: _toggleFavourite),
            IconButton(
              tooltip: s.Open_In_Browser,
              icon: const Icon(Icons.open_in_browser),
              onPressed: () =>
                  openLink(context, 'https://anilist.co/character/${character.id}', confirm: false),
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: s.Alp_Info),
            Tab(text: s.Alp_Anime),
            Tab(text: s.Alp_Manga),
          ]),
        ),
        body: TabBarView(
          children: [
            _info(context, character),
            _mediaTab('ANIME'),
            _mediaTab('MANGA'),
          ],
        ),
      ),
    );
  }

  Widget _info(BuildContext context, AnilistCharacterDetail character) {
    final s = S.of(context);
    final names = character.names;
    return ListView(
      children: [
        AnilistPersonHeader(
          imageUrl: character.imageUrl,
          name: names.display,
          native: names.native,
          favourites: character.favourites,
        ),
        AnilistAlternativeNames(names: names),
        if (character.birthday != null)
          AnilistInfoRow(s.Alp_Birthday, formatAnilistFuzzyDate(character.birthday!)),
        if (character.age != null) AnilistInfoRow(s.Alp_Age, character.age!),
        if (character.gender != null) AnilistInfoRow(s.Gender, character.gender!),
        if (character.bloodType != null) AnilistInfoRow(s.Alp_Blood_Type, character.bloodType!),
        AnilistPersonDescription(character.descriptionHtml),
      ],
    );
  }

  Widget _mediaTab(String type) {
    final anime = type == 'ANIME';
    return AnilistPagedList<AnilistAppearance>(
      key: PageStorageKey(type),
      reloadKey: (_onList, _sort, anime ? _language : null),
      loader: (page) => _service.characterMedia(
        widget.characterId,
        type: type,
        page: page,
        sort: _sort,
        onList: _onList,
        language: _language,
      ),
      header: AnilistFilterBar(
        onList: _service.signedIn ? _onList : null,
        onListChanged: (v) => setState(() => _onList = v),
        sort: _sort,
        onSort: (v) => setState(() => _sort = v),
        extra: [
          if (anime)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: PopupMenuButton<String>(
                initialValue: _language,
                onSelected: (v) => setState(() => _language = v),
                itemBuilder: (_) => [
                  for (final language in anilistVoiceLanguages)
                    PopupMenuItem(value: language, child: Text(anilistLanguageLabel(language))),
                ],
                child: Chip(
                  avatar: const Icon(Icons.record_voice_over_outlined, size: 18),
                  label: Text(anilistLanguageLabel(_language)),
                ),
              ),
            ),
        ],
      ),
      itemBuilder: (context, appearance) => AnilistMediaTile(
        media: appearance.media,
        detail: anilistRoleLabel(appearance.role),
        onTap: () => openAnilistTitle(context,
            category: appearance.media.category, id: appearance.media.id),
        below: appearance.voiceActors.isEmpty
            ? null
            : Wrap(
                spacing: 8,
                children: [
                  for (final actor in appearance.voiceActors)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: AnilistPersonChip(
                        person: actor,
                        onTap: () => openAnilistStaff(context, actor.id),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
