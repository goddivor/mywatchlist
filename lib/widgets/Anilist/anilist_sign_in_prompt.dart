import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/app_routes.dart';

/// "Sign in with AniList" (or "session expired") state of the AniList tabs, under [title].
class AnilistSignInPrompt extends StatelessWidget {
  final Widget? title;
  final IconData icon;
  final String heading;
  final String hint;
  final bool expired;

  const AnilistSignInPrompt({
    super.key,
    this.title,
    required this.icon,
    required this.heading,
    required this.hint,
    required this.expired,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        if (title != null) title!,
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 64, color: cs.primary),
                  const SizedBox(height: 16),
                  Text(heading, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => expired
                        ? AppRoutes.signInAgain(context, AccountType.anilist)
                        : AppRoutes.openLogin(context),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(expired ? S.current.Al_Sign_In_Again : S.current.Al_Sign_In),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
