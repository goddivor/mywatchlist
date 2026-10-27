import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// Placeholder page for a destination whose feature unit has not landed yet.
///
/// Every stub of the app shell (settings pages, bookmarks, calendar, profile) uses it, so
/// they look the same and are fully translated. The unit that owns the destination replaces
/// the stub's body with the real page.
class ComingSoonPage extends StatelessWidget {
  /// Title shown in the app bar (already translated).
  final String title;

  /// Icon of the destination, drawn in the empty state.
  final IconData icon;

  /// Optional line under the "coming soon" heading (e.g. the destination's description).
  final String? subtitle;

  /// Optional action below the text (e.g. a link to the current implementation).
  final Widget? action;

  const ComingSoonPage({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 24),
              Text(
                S.current.Shell_Coming_Soon,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle ?? S.current.Shell_Coming_Soon_Desc,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  S.current.Shell_Coming_Soon_Desc,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 24),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
