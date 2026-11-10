import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/widgets/accounts_panel.dart';
import 'package:mywatchlist/widgets/common/signin_widget.dart';

/// Second page of the intro (also usable on its own): connect the services you use. The
/// first tracker that connects becomes the active account by itself; more can be added
/// later in Settings > Accounts.
class OnboardingTrackers extends StatelessWidget {
  final bool fromIntro;

  const OnboardingTrackers({super.key, this.fromIntro = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: fromIntro ? null : AppBar(title: Text(S.current.Settings_Accounts)),
      body: SafeArea(
        child: AccountsPanel(
          confirmSwitch: false,
          // Room for the intro's page controls laid over the bottom of the page.
          padding: EdgeInsets.fromLTRB(16, 8, 16, fromIntro ? 120 : 24),
          header: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 12),
            child: SigninWidget(
              title: S.current.Acc_Onboarding_Title,
              subtitle: S.current.Acc_Onboarding_Subtitle,
            ),
          ),
        ),
      ),
    );
  }
}
