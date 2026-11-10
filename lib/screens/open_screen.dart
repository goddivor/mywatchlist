import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/screens/intro_screen.dart';
import 'package:mywatchlist/user/user_preference.dart';

/// Entry point: shows the intro on the first launch, the home shell otherwise.
class OpenScreen extends StatefulWidget {
  /// Payload of the notification that launched the app (see `NotificationRoute`), routed
  /// by the home shell after its first frame.
  final String? notificationPayload;

  const OpenScreen({super.key, this.notificationPayload});

  @override
  State<OpenScreen> createState() => _OpenScreenState();
}

class _OpenScreenState extends State<OpenScreen> {
  late final Future<bool> _firstTime = UserPreference().isFirstTime();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _firstTime,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppStartupLoader();
        }
        // A storage failure must not lock the user out: treat it as "not first time".
        final firstTime = snapshot.data ?? false;
        return firstTime
            ? IntroScreen()
            : HomeScreen(notificationPayload: widget.notificationPayload);
      },
    );
  }
}

/// Full-screen loader of the startup (logo + progress), shared by the open screen and the
/// home shell while the account is loading.
class AppStartupLoader extends StatelessWidget {
  const AppStartupLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Semantics(
          label: S.current.Shell_Loading,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/mwl-black-bg.png',
                  width: 88,
                  height: 88,
                  cacheWidth: 264,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                  color: colors.primary,
                  backgroundColor: colors.primary.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
