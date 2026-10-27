import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_view.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// The "Profile" tab of the home shell for a MyAnimeList account: the signed-in user's own
/// profile, or a sign-in prompt when MAL is not connected.
///
/// [isSelf] false is not used by the shell; other users open through
/// `AppRoutes.openUserProfile`.
class MalUserProfilePage extends StatelessWidget {
  final bool isSelf;

  const MalUserProfilePage({super.key, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    final user = UserMalV2.instance;
    return ListenableBuilder(
      listenable: user,
      builder: (context, _) {
        final signedIn = user.status == AuthStatus.AUTHENTICATED;
        if (!signedIn) {
          final s = S.of(context);
          return SafeArea(
            child: ProfileMessage(
              icon: Icons.account_circle_outlined,
              title: s.Prof_Sign_In_Title,
              body: s.Prof_Sign_In_Body,
              actionLabel: s.Prof_Sign_In,
              onAction: () => AppRoutes.signInAgain(context, AccountType.myanimelist),
            ),
          );
        }
        // Rebuilt from scratch when the signed-in account changes.
        return UserProfileView(key: ValueKey(user.username));
      },
    );
  }
}
