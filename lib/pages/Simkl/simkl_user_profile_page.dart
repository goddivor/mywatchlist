import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_profile_view.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_states.dart';

/// The "Profile" tab of the home shell for a Simkl account: the signed-in user's own profile
/// (account, list numbers, charts), or a sign-in prompt.
///
/// Simkl shows no other user's profile, so [isSelf] false is not used by the shell.
class SimklUserProfilePage extends StatelessWidget {
  final bool isSelf;

  const SimklUserProfilePage({super.key, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    final user = UserSimklV2.instance;
    return ListenableBuilder(
      listenable: user,
      builder: (context, _) {
        if (!simklSignedIn) {
          return SafeArea(
            child: SimklSignInPrompt(
              icon: Icons.account_circle_outlined,
              what: S.of(context).Sk_Profile_Sign_In_Hint,
            ),
          );
        }
        // Rebuilt from scratch when another Simkl account signs in.
        return SimklProfileView(key: ValueKey(user.username));
      },
    );
  }
}
