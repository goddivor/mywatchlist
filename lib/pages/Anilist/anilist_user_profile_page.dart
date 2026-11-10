import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_profile_view.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_sign_in_prompt.dart';

/// The "Profile" tab of the home shell for an AniList account: the signed-in user's own
/// profile, or a sign-in prompt when AniList is not connected. With [isSelf] false and a
/// [username], any public AniList profile.
class AnilistUserProfilePage extends StatelessWidget {
  final bool isSelf;
  final String? username;

  const AnilistUserProfilePage({super.key, required this.isSelf, this.username});

  @override
  Widget build(BuildContext context) {
    if (!isSelf && username != null) {
      return Scaffold(body: AnilistProfileView(username: username, showBack: true));
    }
    final user = UserAnilistV2.instance;
    return ListenableBuilder(
      listenable: user,
      builder: (context, _) {
        if (user.status != AuthStatus.AUTHENTICATED) {
          final s = S.of(context);
          final expired = user.needsReLogin;
          return SafeArea(
            child: AnilistSignInPrompt(
              icon: Icons.account_circle_outlined,
              heading: expired ? s.Al_Session_Expired : s.Prof_Sign_In_Title,
              hint: expired ? s.Al_Profile_Session_Expired_Body : s.Al_Profile_Sign_In_Body,
              expired: expired,
            ),
          );
        }
        // Rebuilt from scratch when the signed-in account changes.
        return AnilistProfileView(key: ValueKey(user.username));
      },
    );
  }
}
