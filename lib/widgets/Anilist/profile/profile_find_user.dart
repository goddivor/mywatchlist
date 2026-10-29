import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_follow_service.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_social.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart' show anilistErrorText;
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// "Find a user": a search field over AniList's user search; a row opens the profile.
class AnilistFindUserPage extends StatefulWidget {
  final AnilistFollowService? service;

  const AnilistFindUserPage({super.key, this.service});

  @override
  State<AnilistFindUserPage> createState() => _AnilistFindUserPageState();
}

class _AnilistFindUserPageState extends State<AnilistFindUserPage> {
  final TextEditingController _text = TextEditingController();
  Timer? _debounce;
  List<AnilistUserRow> _users = const [];
  String _query = '';
  bool _loading = false;
  Object? _error;
  int _generation = 0;

  AnilistFollowService get _service => widget.service ?? AnilistFollowService.instance;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    final generation = ++_generation;
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _users = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _query = query;
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.searchUsers(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _users = page.users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final Widget body;
    if (_loading) {
      body = ProfileLoading(label: s.Prof_Loading);
    } else if (_error != null) {
      body = ProfileMessage(
        icon: Icons.cloud_off_outlined,
        title: anilistErrorText(_error!),
        actionLabel: s.Prof_Retry,
        onAction: () => _search(_query),
      );
    } else if (_users.isEmpty) {
      body = ProfileMessage(
        icon: Icons.person_search_outlined,
        title: _query.isEmpty ? s.Alpp_Find_User : s.Alpp_No_Users,
      );
    } else {
      body = ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, i) => AnilistUserTile(
          key: ValueKey(_users[i].id),
          user: _users[i],
          showFollow: _service.signedIn,
          service: widget.service,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _text,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(border: InputBorder.none, hintText: s.Alpp_Find_User),
          onChanged: _changed,
          onSubmitted: _search,
        ),
      ),
      body: body,
    );
  }
}
