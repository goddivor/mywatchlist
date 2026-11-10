import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';

/// Centered icon, title, text and an optional button: the empty, error and sign-in states of
/// the profile screens share it.
class ProfileMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ProfileMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A spinner with an optional caption.
class ProfileLoading extends StatelessWidget {
  final String? label;

  const ProfileLoading({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(label!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// The message that fits [error]: a dead MAL session offers to sign in again, a missing
/// profile says so, anything else offers a retry.
class ProfileErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final VoidCallback? onSignIn;

  const ProfileErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (error is MalSessionExpired) {
      return ProfileMessage(
        icon: Icons.lock_outline,
        title: s.Prof_Error_Title,
        body: s.Prof_Session_Expired_Body,
        actionLabel: onSignIn == null ? s.Prof_Retry : s.Prof_Sign_In,
        onAction: onSignIn ?? onRetry,
      );
    }
    if (error is UserProfileUnavailable) {
      return ProfileMessage(
        icon: Icons.person_off_outlined,
        title: s.Prof_Error_Title,
        body: s.Prof_Not_Found_Body,
        actionLabel: s.Prof_Retry,
        onAction: onRetry,
      );
    }
    return ProfileMessage(
      icon: Icons.cloud_off_outlined,
      title: s.Prof_Error_Title,
      body: s.Prof_Error_Body,
      actionLabel: s.Prof_Retry,
      onAction: onRetry,
    );
  }
}
