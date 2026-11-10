import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_social.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_profile_view.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_paged_tab.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Opens the profile of [user] in a page of its own.
void openKitsuUser(BuildContext context, KitsuAuthor user) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => Scaffold(body: KitsuProfileView(userId: user.id, showBack: true)),
  ));
}

/// An avatar and a name; tapping opens the profile.
class KitsuPersonTile extends StatelessWidget {
  final KitsuAuthor user;

  const KitsuPersonTile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: ClipOval(
        child: SizedBox(
          width: 44,
          height: 44,
          child: user.avatar == null
              ? ColoredBox(
                  color: scheme.secondaryContainer,
                  child: Icon(Icons.person_rounded, color: scheme.onSecondaryContainer))
              : AppImage(url: user.avatar!.url, placeholderColor: scheme.secondaryContainer),
        ),
      ),
      title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => openKitsuUser(context, user),
    );
  }
}

/// Who follows a user, or who the user follows.
class KitsuPeoplePage extends StatelessWidget {
  final String slug;
  final bool followers;
  final KitsuSocial? social;

  const KitsuPeoplePage({super.key, required this.slug, required this.followers, this.social});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final api = social ?? KitsuSocial.instance;
    return Scaffold(
      appBar: AppBar(title: Text(followers ? s.Kitsu_Followers_Title : s.Kitsu_Following_Title)),
      body: KitsuPagedList<KitsuAuthor>(
        storageKey: 'kitsu_people_${followers}_$slug',
        overlap: false,
        createPager: () => KitsuPager((page) =>
            followers ? api.followers(slug, page) : api.following(slug, page)),
        emptyText: s.Kitsu_People_Empty,
        itemBuilder: (context, user) => KitsuPersonTile(key: ValueKey(user.id), user: user),
      ),
    );
  }
}

/// Finds Kitsu users by name and opens their profile.
class KitsuUserSearchPage extends StatefulWidget {
  final KitsuSocial? social;

  const KitsuUserSearchPage({super.key, this.social});

  @override
  State<KitsuUserSearchPage> createState() => _KitsuUserSearchPageState();
}

class _KitsuUserSearchPageState extends State<KitsuUserSearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  KitsuSocial get _api => widget.social ?? KitsuSocial.instance;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final query = value.trim();
      if (mounted && query != _query) setState(() => _query = query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: s.Kitsu_User_Search_Hint, border: InputBorder.none),
          onChanged: _changed,
          onSubmitted: (value) {
            _debounce?.cancel();
            final query = value.trim();
            if (query != _query) setState(() => _query = query);
          },
        ),
      ),
      body: _query.length < 2
          ? const SizedBox.shrink()
          : KitsuPagedList<KitsuAuthor>(
              // A new query is a new list.
              key: ValueKey(_query),
              storageKey: 'kitsu_user_search',
              overlap: false,
              createPager: () => KitsuPager((page) => _api.searchUsers(_query, page)),
              emptyText: s.Kitsu_User_Search_Empty(_query),
              itemBuilder: (context, user) => KitsuPersonTile(key: ValueKey(user.id), user: user),
            ),
    );
  }
}
