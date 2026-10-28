import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// Whether the Simkl account is signed in right now.
bool get simklSignedIn => UserSimklV2.instance.status == AuthStatus.AUTHENTICATED;

/// "Sign in with Simkl" (or "Sign in again" after a dead session) for the tabs that need the
/// account. [what] is the sentence saying what the sign-in unlocks.
class SimklSignInPrompt extends StatelessWidget {
  final IconData icon;
  final String what;

  const SimklSignInPrompt({super.key, required this.icon, required this.what});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final expired = UserSimklV2.instance.needsReLogin;
    return ProfileMessage(
      icon: expired ? Icons.lock_outline_rounded : icon,
      title: expired ? s.Sk_Session_Expired : s.Sk_Sign_In_Title,
      body: expired ? s.Sk_Session_Expired_Hint : what,
      actionLabel: expired ? s.Sk_Sign_In_Again : s.Sk_Sign_In,
      onAction: () => AppRoutes.signInAgain(context, AccountType.simkl),
    );
  }
}
