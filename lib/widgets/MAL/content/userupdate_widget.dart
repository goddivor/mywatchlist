import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show displayTimeAgo;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_animeuserupdate.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/widgets/MAL/home/animecardbar.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';
import 'package:mywatchlist/widgets/MAL/review/review_item.dart';
import 'package:mywatchlist/widgets/MAL/review/user_link.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

/// Latest list updates of other users for one title: a two-row horizontal grid of cards
/// (avatar, name, progress ring, score, age, status). A tap on a card opens the quick user
/// sheet of that user.
///
/// Sources ([JikanFallbacks.race]): Jikan `userupdates` while Jikan is the data source,
/// against the "Recently Updated By" table of MAL's stats page (`?m=all`, all members) read
/// on the phone without a session. Tenrai has no `userupdates`: while Jikan is muted the
/// Jikan leg fails at once and MAL's page is the only source. The skeleton always ends in
/// cards, an empty state or an error with Retry within about 12 s.
class UserUpdatesPage extends StatefulWidget {
  final int id;
  final VoidCallback? onPageChange;
  final String category;
  final double horizPadding;

  const UserUpdatesPage({
    super.key,
    required this.id,
    required this.category,
    this.onPageChange,
    required this.horizPadding,
  });

  @override
  State<UserUpdatesPage> createState() => _UserUpdatesPageState();
}

class _UserUpdatesPageState extends State<UserUpdatesPage> with AutomaticKeepAliveClientMixin {
  late Future<AnimeUserUpdatesResponse> _updates = _fetch();

  Future<AnimeUserUpdatesResponse> _fetch() async {
    final result = await JikanFallbacks.race<AnimeUserUpdatesResponse>(
      jikan: () => JikanApi.getAnimeUserUpdates(widget.id, category: widget.category),
      fallback: () => JikanFallbacks.userUpdates(widget.id, widget.category, 1),
    );
    return result.value;
  }

  void _retry() {
    setState(() {
      _updates = _fetch();
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<AnimeUserUpdatesResponse>(
      future: _updates,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SectionMessage.error(height: 200, message: S.current.Social_Updates_Failed, onRetry: _retry);
        }
        final data = snapshot.data;
        if (data == null) {
          return _grid(List<AnimeUserUpdate?>.generate(12, (_) => null));
        }
        if (data.data.isEmpty) {
          return SectionMessage(height: 200, icon: Icons.people_outline, message: S.current.Social_Updates_Empty);
        }
        return _grid(data.data);
      },
    );
  }

  Widget _grid(List<AnimeUserUpdate?> users) =>
      UserUpdatesGrid(updates: users, category: widget.category, horizPadding: widget.horizPadding);
}

/// The two-row horizontal grid of update cards; `null` entries show a skeleton card.
/// Also used by the Friends tabs of the title page.
class UserUpdatesGrid extends StatelessWidget {
  final List<AnimeUserUpdate?> updates;
  final String category;
  final double horizPadding;

  const UserUpdatesGrid({super.key, required this.updates, required this.category, required this.horizPadding});

  @override
  Widget build(BuildContext context) {
    final users = updates;

    return SizedBox(
      height: 280,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: .5,
        ),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizPadding + 10, vertical: 7),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final update = users[index];
          return ShimmerConditionally(
            showShimmer: update == null,
            child: SizedBox(
              width: 120,
              child: Card(
                child: update == null ? const SizedBox() : _UpdateCard(update: update, category: category),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  final AnimeUserUpdate update;
  final String category;

  const _UpdateCard({required this.update, required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = update.status;
    final nsv = status == null ? null : NodeStatusValue.fromString(statusKey(status));
    final date = DateTime.tryParse(update.date ?? '');
    final username = update.user?.username;
    final linkable = isLinkableUser(username);

    return Semantics(
      button: linkable,
      label: linkable ? S.current.Social_Open_Profile(username!) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: linkable ? () => openMalUser(context, username) : null,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      RoundAvatar(size: 45, url: update.user?.images?.jpg?.imageUrl),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 80,
                        child: Text(
                          username ?? S.current.Social_Review_Anonymous,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  category == 'manga' ? _mangaProgress(context) : _episodeProgress(context),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: ReviewScoreBadge(score: update.score, size: 14),
                  ),
                  if (date != null)
                    Text(
                      displayTimeAgo(date),
                      style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, fontSize: 12),
                    ),
                  if (nsv?.status != null) StatusBadge(nsv!, height: 25),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ring(BuildContext context, {required double size, required String label, required double value, double fontSize = 9}) {
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: 1.5, value: value),
          Text(label, style: TextStyle(fontSize: fontSize)),
        ],
      ),
    );
  }

  static double _ratio(int? done, int? total) =>
      (done == null || total == null || total == 0) ? 0.0 : (done / total).clamp(0.0, 1.0);

  Widget _episodeProgress(BuildContext context) {
    final seen = update.episodesSeen;
    final total = update.episodesTotal;
    return Column(
      children: [
        _ring(context, size: 45, label: '${seen ?? "-"}/${total ?? "-"}', value: _ratio(seen, total)),
        const SizedBox(height: 5),
        Text(S.current.Social_Updates_Episodes, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _mangaProgress(BuildContext context) {
    final read = update.chaptersRead;
    final total = update.chaptersTotal;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ring(context, size: 40, label: '${read ?? "-"}/${total ?? "-"}', value: _ratio(read, total), fontSize: 8),
        const SizedBox(height: 2),
        Text(S.current.Social_Updates_Chapters_Short, style: const TextStyle(fontSize: 10)),
        const SizedBox(height: 1),
        Text(
          S.current.Social_Updates_Volumes('${update.volumesRead ?? "-"}', '${update.volumesTotal ?? "-"}'),
          style: const TextStyle(fontSize: 9),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The list status key (`on_hold`, `plan_to_watch`…) of a status as Jikan or MAL's page
/// print it (`On-Hold`, `Plan to Watch`).
@visibleForTesting
String statusKey(String status) =>
    status.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
