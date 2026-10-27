import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_profile_view.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// The "Profile" tab of the home shell for a Kitsu account: the signed-in user's own profile, or
/// a sign-in prompt when Kitsu is not connected.
class KitsuUserProfilePage extends StatelessWidget {
  final bool isSelf;

  const KitsuUserProfilePage({super.key, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    final user = UserKitsuV2.instance;
    return ListenableBuilder(
      listenable: user,
      builder: (context, _) {
        if (user.status != AuthStatus.AUTHENTICATED) {
          final s = S.of(context);
          return SafeArea(
            child: ProfileMessage(
              icon: Icons.account_circle_outlined,
              title: s.Prof_Sign_In_Title,
              body: s.Kitsu_Prof_Sign_In_Body,
              actionLabel: s.Prof_Sign_In,
              onAction: () => AppRoutes.signInAgain(context, AccountType.kitsu),
            ),
          );
        }
        // Rebuilt from scratch when the signed-in account changes.
        return KitsuProfileView(key: ValueKey(user.username));
      },
    );
  }
}
