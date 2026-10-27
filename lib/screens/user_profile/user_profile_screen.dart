import 'package:flutter/material.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_view.dart';

export 'package:mywatchlist/screens/user_profile/user_profile_view.dart' show UserProfileTab;

/// A pushed MyAnimeList profile page. [username] null = the signed-in user.
class UserProfileScreen extends StatelessWidget {
  final String? username;
  final UserProfileTab initialTab;

  const UserProfileScreen({
    super.key,
    this.username,
    this.initialTab = UserProfileTab.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: UserProfileView(
        username: username,
        showBack: true,
        initialTab: initialTab,
      ),
    );
  }
}
