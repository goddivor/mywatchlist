import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// Simkl has no forum: the tab says so instead of showing an empty page.
class SimklForumPage extends StatelessWidget {
  const SimklForumPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBarHome(title: s.Sk_Forum_Title, showBookmarks: false, showCalendar: false),
      body: ProfileMessage(
        icon: Icons.forum_outlined,
        title: s.Sk_Forum_None_Title,
        body: s.Sk_Forum_None_Body,
      ),
    );
  }
}
