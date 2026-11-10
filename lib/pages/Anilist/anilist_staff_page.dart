import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_character_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_people_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Anilist/people/anilist_people_ui.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumMessage, ForumSkeleton;

/// Opens the AniList staff member [id] in the app.
Future<void> openAnilistStaff(BuildContext context, int id) =>
    AppRoutes.push<void>(context, AnilistStaffPage(staffId: id));

/// An AniList staff member (voice actor, director…): Info (picture, names, language,
/// occupations, birth and death, age, years active, hometown, favourites, description), the
/// characters they voiced and their production roles, each filterable to what is on the
/// signed-in user's list.
class AnilistStaffPage extends StatefulWidget {
  const AnilistStaffPage({super.key, required this.staffId, this.service});

  final int staffId;
  final AnilistPeopleService? service;

  @override
  State<AnilistStaffPage> createState() => _AnilistStaffPageState();
}

class _AnilistStaffPageState extends State<AnilistStaffPage> {
  AnilistStaffDetail? _staff;
  Object? _error;
  bool _toggling = false;
  bool _onList = false;
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
      final staff = await _service.staff(widget.staffId);
      if (mounted) setState(() => _staff = staff);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggleFavourite() async {
    final staff = _staff;
    if (staff == null || _toggling) return;
    setState(() => _toggling = true);
    final done =
        await toggleAnilistPersonFavourite(context, _service, AnilistFavouriteKind.staff, staff.id);
    if (!mounted) return;
    setState(() {
      _toggling = false;
      if (done) {
        _staff = staff.copyWith(
          isFavourite: !staff.isFavourite,
          favourites: staff.favourites + (staff.isFavourite ? -1 : 1),
        );
      }
    });
  }

  String? _yearsActive(List<int> years) {
    final s = S.current;
    if (years.isEmpty) return null;
    if (years.length == 1) return s.Alp_Since_Year(years.first);
    return s.Alp_Years_Range(years.first, years.last);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final staff = _staff;
    if (staff == null) {
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
          title: Text(staff.names.display, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            AnilistFavouriteAction(isFavourite: staff.isFavourite, onPressed: _toggleFavourite),
            IconButton(
              tooltip: s.Open_In_Browser,
              icon: const Icon(Icons.open_in_browser),
              onPressed: () =>
                  openLink(context, 'https://anilist.co/staff/${staff.id}', confirm: false),
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: s.Alp_Info),
            Tab(text: s.Alp_Voice_Roles),
            Tab(text: s.Alp_Staff_Roles),
          ]),
        ),
        body: TabBarView(
          children: [
            _info(context, staff),
            _voiceRoles(),
            _staffRoles(),
          ],
        ),
      ),
    );
  }

  Widget _info(BuildContext context, AnilistStaffDetail staff) {
    final s = S.of(context);
    final years = _yearsActive(staff.yearsActive);
    return ListView(
      children: [
        AnilistPersonHeader(
          imageUrl: staff.imageUrl,
          name: staff.names.display,
          native: staff.names.native,
          favourites: staff.favourites,
          subtitle: staff.language,
        ),
        AnilistAlternativeNames(names: staff.names),
        if (staff.occupations.isNotEmpty)
          AnilistInfoRow(s.Alp_Occupations, staff.occupations.join(', ')),
        if (staff.birthday != null)
          AnilistInfoRow(s.Alp_Birthday, formatAnilistFuzzyDate(staff.birthday!)),
        if (staff.death != null) AnilistInfoRow(s.Alp_Died, formatAnilistFuzzyDate(staff.death!)),
        if (staff.age != null) AnilistInfoRow(s.Alp_Age, '${staff.age}'),
        if (staff.gender != null) AnilistInfoRow(s.Gender, staff.gender!),
        if (staff.bloodType != null) AnilistInfoRow(s.Alp_Blood_Type, staff.bloodType!),
        if (years != null) AnilistInfoRow(s.Alp_Years_Active, years),
        if (staff.homeTown != null) AnilistInfoRow(s.Alp_Hometown, staff.homeTown!),
        AnilistPersonDescription(staff.descriptionHtml),
      ],
    );
  }

  Widget get _filters => AnilistFilterBar(
        onList: _service.signedIn ? _onList : null,
        onListChanged: (v) => setState(() => _onList = v),
        sort: _sort,
        onSort: (v) => setState(() => _sort = v),
      );

  Widget _voiceRoles() => AnilistPagedList<AnilistVoiceRole>(
        key: const PageStorageKey('voice'),
        reloadKey: (_onList, _sort),
        loader: (page) =>
            _service.staffVoiceRoles(widget.staffId, page: page, sort: _sort, onList: _onList),
        header: _filters,
        itemBuilder: (context, role) => AnilistMediaTile(
          media: role.media,
          detail: anilistRoleLabel(role.role),
          onTap: () =>
              openAnilistTitle(context, category: role.media.category, id: role.media.id),
          below: role.characters.isEmpty
              ? null
              : Wrap(
                  spacing: 8,
                  children: [
                    for (final character in role.characters)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 170),
                        child: AnilistPersonChip(
                          person: character,
                          onTap: () => openAnilistCharacter(context, character.id),
                        ),
                      ),
                  ],
                ),
        ),
      );

  Widget _staffRoles() => AnilistPagedList<AnilistStaffRole>(
        key: const PageStorageKey('roles'),
        reloadKey: (_onList, _sort),
        loader: (page) =>
            _service.staffRoles(widget.staffId, page: page, sort: _sort, onList: _onList),
        header: _filters,
        itemBuilder: (context, role) => AnilistMediaTile(
          media: role.media,
          detail: role.role,
          onTap: () =>
              openAnilistTitle(context, category: role.media.category, id: role.media.id),
        ),
      );
}
