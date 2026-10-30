import 'package:flutter/material.dart';
import 'package:mwl_commons/mwl_commons.dart' show ContentUpdateHtml;
import 'package:mywatchlist/constants/constants.dart' show TabType, displayTimeAgo;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/MAL/web/friends_updates_api.dart';
import 'package:mywatchlist/widgets/MAL/content/userupdate_widget.dart';
import 'package:mywatchlist/widgets/MAL/home/animecardbar.dart' show StatusBadge;
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart' show NodeStatusValue;
import 'package:mywatchlist/widgets/MAL/review/review_item.dart' show ReviewScoreBadge;
import 'package:mywatchlist/widgets/MAL/review/user_link.dart';

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
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.horizPadding + 10),
          child: Column(
            children: [
              for (final update in data.updates.take(20))
                FriendUpdateRow(update: update, isManga: widget.category == 'manga'),
            ],
          ),
        );
      },
    );
  }
}

/// One member of the "Recently Updated By" table: avatar, name and activity, progress,
/// score and status. A tap opens the member's profile.
class FriendUpdateRow extends StatelessWidget {
  final ContentUpdateHtml update;
  final bool isManga;

  const FriendUpdateRow({super.key, required this.update, required this.isManga});

  String _progress() {
    String part(int? n) => n?.toString() ?? '?';
    if (isManga) {
      return '${S.current.Social_Updates_Chapters_Short} ${part(update.chaptersRead)} / ${part(update.chaptersTotal)}';
    }
    return '${part(update.episodesSeen)} / ${part(update.episodesTotal)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = update.status;
    final nsv = status == null ? null : NodeStatusValue.fromString(status.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_'));
    final date = DateTime.tryParse(update.date ?? '');
    final linkable = isLinkableUser(update.username);
    return Semantics(
      button: linkable,
      label: linkable ? S.current.Social_Open_Profile(update.username) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: linkable ? () => openMalUser(context, update.username) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              RoundAvatar(size: 40, url: update.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(update.username, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                    Text(
                      [
                        _progress(),
                        if (date != null) displayTimeAgo(date) else if (update.activity != null) update.activity!,
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              ReviewScoreBadge(score: update.score, size: 14),
              if (nsv?.status != null) ...[
                const SizedBox(width: 10),
                StatusBadge(nsv!, height: 25),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
