import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';

/// Shown instead of the sections when the MyAnimeList details could not be
/// loaded (the screen used to stay on the shimmer forever).
class DetailErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const DetailErrorView({super.key, this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final theme = Theme.of(context);
    final sessionExpired = error is MalSessionExpired;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            sessionExpired ? Icons.lock_clock_outlined : Icons.cloud_off_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            s.Detail_Load_Error,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            sessionExpired ? s.Detail_Session_Expired : s.Detail_Load_Error_Hint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(s.Detail_Retry),
          ),
        ],
      ),
    );
  }
}
