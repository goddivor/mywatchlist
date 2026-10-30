import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart' show userUpdateFromHtml;
import 'package:mywatchlist/services/api/MAL/web/friends_updates_api.dart';
import 'package:mywatchlist/widgets/MAL/content/userupdate_widget.dart';

/// Recent list updates of other users, with Friends / Top friends tabs when a MAL website
/// session is connected.
DetailSection? userUpdatesSection(DetailData data) {
  if (!data.hasContent) return null;
  return DetailSection(
    TabType.User_Updates,
    FriendsUpdatesSection(
      horizPadding: detailHorizPadding,
      category: data.category,
      id: data.id,
    ),
  );
}

enum FriendsTab { friends, top, everyone }

/// Tabs Friends / Top friends / Everyone over "Recently Updated By". Friends and Top
/// friends come from MAL's stats page with the website session; Everyone is
/// [UserUpdatesPage] as before. The tabs are hidden without a session; the default tab is
/// Friends when it has rows, else Everyone.
class FriendsUpdatesSection extends StatefulWidget {
  final int id;
  final String category;
  final double horizPadding;

  /// Friends source and Everyone view, replaceable in tests.
  final FriendsUpdatesApi? api;
  final Widget Function(BuildContext context)? everyoneBuilder;

  const FriendsUpdatesSection({
    super.key,
    required this.id,
    required this.category,
    required this.horizPadding,
    this.api,
    this.everyoneBuilder,
  });

  @override
  State<FriendsUpdatesSection> createState() => _FriendsUpdatesSectionState();
}

class _FriendsUpdatesSectionState extends State<FriendsUpdatesSection> with AutomaticKeepAliveClientMixin {
  late final FriendsUpdatesApi _api = widget.api ?? FriendsUpdatesApi();
  final Map<FriendsTab, Future<FriendsUpdates>> _loads = {};
  bool _hasSession = false;
  FriendsTab _tab = FriendsTab.everyone;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    bool session;
    try {
      session = await _api.hasSession;
    } catch (_) {
      session = false;
    }
    if (!session || !mounted) return;
    final first = _load(FriendsTab.friends);
    setState(() => _hasSession = true);
    try {
      final result = await first;
      if (!mounted) return;
      if (!result.signedIn) {
        // MAL did not treat the viewer as signed in: no friends tabs.
        setState(() => _hasSession = false);
      } else if (result.updates.isNotEmpty) {
        setState(() => _tab = FriendsTab.friends);
      }
    } catch (_) {
      if (mounted) setState(() => _hasSession = false);
    }
  }

  Future<FriendsUpdates> _load(FriendsTab tab) => _loads.putIfAbsent(
        tab,
        () => _api.fetch(
          widget.category,
          widget.id,
          tab == FriendsTab.top ? FriendsSource.top : FriendsSource.friends,
        ),
      );

  void _select(FriendsTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      if (tab != FriendsTab.everyone) _load(tab);
    });
  }

  void _retry(FriendsTab tab) {
    setState(() {
      _loads.remove(tab);
      _load(tab);
    });
  }

  Widget _everyone(BuildContext context) =>
      widget.everyoneBuilder?.call(context) ??
      UserUpdatesPage(horizPadding: widget.horizPadding, category: widget.category, id: widget.id);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_hasSession) return _everyone(context);
    final labels = {
      FriendsTab.friends: S.current.Mdf_Tab_Friends,
      FriendsTab.top: S.current.Mdf_Tab_Top_Friends,
      FriendsTab.everyone: S.current.Mdf_Tab_Everyone,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.horizPadding + 10, vertical: 4),
          child: Wrap(
            spacing: 8,
            children: [
              for (final tab in FriendsTab.values)
                ChoiceChip(
                  key: ValueKey('friends-tab-${tab.name}'),
                  label: Text(labels[tab]!),
                  selected: tab == _tab,
                  onSelected: (_) => _select(tab),
                ),
            ],
          ),
        ),
        if (_tab == FriendsTab.everyone) _everyone(context) else _friendsRows(_tab),
      ],
    );
  }

  Widget _friendsRows(FriendsTab tab) {
    return FutureBuilder<FriendsUpdates>(
      key: ValueKey('friends-rows-${tab.name}'),
      future: _load(tab),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SectionMessage.error(
            height: 200,
            message: S.current.Mdf_Friends_Failed,
            onRetry: () => _retry(tab),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }
        if (data.updates.isEmpty) {
          return SectionMessage(height: 200, icon: Icons.people_outline, message: S.current.Mdf_Friends_Empty);
        }
        // The same cards as Everyone.
        return UserUpdatesGrid(
          updates: data.updates.map(userUpdateFromHtml).toList(),
          category: widget.category,
          horizPadding: widget.horizPadding,
        );
      },
    );
  }
}
