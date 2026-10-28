import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tabs_source.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_friends.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// The friends of a MyAnimeList user, a page at a time with a "load more" button.
class FriendsSection extends StatefulWidget {
  final String username;

  const FriendsSection({super.key, required this.username});

  @override
  State<FriendsSection> createState() => _FriendsSectionState();
}

class _FriendsSectionState extends State<FriendsSection> with AutomaticKeepAliveClientMixin {
  final List<ProfileFriend> _friends = [];
  int _page = 0;
  FriendsCursor? _cursor;
  bool _hasNext = false;
  bool _loading = true;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  Future<void> _loadNext() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ProfileTabsSource.friends(widget.username, page: _page + 1, after: _cursor);
      if (!mounted) return;
      final known = {for (final f in _friends) f.username};
      setState(() {
        _page++;
        _friends.addAll(page.friends.where((f) => known.add(f.username)));
        _hasNext = page.hasNextPage;
        _cursor = page.cursor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final key = 'friends_${widget.username}';

    if (_friends.isEmpty) {
      final Widget child;
      if (_loading) {
        child = ProfileLoading(label: s.Pt_Friends_Loading);
      } else if (_error != null) {
        child = ProfileErrorView(error: _error!, onRetry: _loadNext);
      } else {
        child = ProfileMessage(icon: Icons.people_outline, title: s.Prof_Friends_Empty);
      }
      return ProfileTabScroll(
        storageKey: key,
        slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
      );
    }

    return ProfileTabScroll(
      storageKey: key,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              s.Prof_Friends_Count(_friends.length),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        SliverList.builder(
          itemCount: _friends.length,
          itemBuilder: (context, i) => _FriendTile(friend: _friends[i]),
        ),
        if (_hasNext || _error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : OutlinedButton(
                        onPressed: _loadNext,
                        child: Text(_error != null ? s.Prof_Retry : s.Prof_Load_More),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  final ProfileFriend friend;

  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final lastSeen = friend.lastSeenAt != null ? _ago(s, friend.lastSeenAt!) : friend.lastOnline;
    // Two-line row like DailyAL's (name, then one meta line): the friendship date is a
    // date only and shares the last-seen line instead of adding a third one.
    final since = friend.friendsSinceAt != null
        ? DateFormat.yMMMd(Localizations.localeOf(context).toString())
            .format(friend.friendsSinceAt!)
        : friend.friendsSince;
    final lines = [
      if (lastSeen != null) s.Prof_Last_Seen(lastSeen),
      if (since != null) s.Prof_Friends_Since(since),
    ];
    return ListTile(
      leading: ClipOval(
        child: AppImage(
          url: friend.imageUrl,
          width: 44,
          height: 44,
          errorWidget: (_) => SizedBox(
            width: 44,
            height: 44,
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.person),
            ),
          ),
        ),
      ),
      title: Text(friend.username, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: lines.isEmpty
          ? null
          : Text(lines.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => AppRoutes.openUserProfile(
        context,
        tracker: AccountType.myanimelist,
        username: friend.username,
      ),
    );
  }
}

/// "3 hours ago" in the app's language.
String _ago(S s, DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return s.Prof_Seen_Just_Now;
  if (d.inHours < 1) return s.Prof_Seen_Minutes(d.inMinutes);
  if (d.inDays < 1) return s.Prof_Seen_Hours(d.inHours);
  if (d.inDays < 30) return s.Prof_Seen_Days(d.inDays);
  if (d.inDays < 365) return s.Prof_Seen_Months(d.inDays ~/ 30);
  return s.Prof_Seen_Years(d.inDays ~/ 365);
}
