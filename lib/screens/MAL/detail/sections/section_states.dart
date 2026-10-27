import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Final state of a detail section that has nothing to show: an empty state
/// ([onRetry] null) or an error with a Retry button. Every section ends in
/// content or in one of these, never in an endless skeleton.
class SectionMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  final double height;

  const SectionMessage({
    super.key,
    required this.icon,
    required this.message,
    this.onRetry,
    this.height = 160,
  });

  /// Error with Retry. The Retry also lets Jikan be tried again at once
  /// (the client skips it for a while after a timeout).
  factory SectionMessage.error({
    Key? key,
    required String message,
    required VoidCallback onRetry,
    double height = 160,
  }) =>
      SectionMessage(
        key: key,
        icon: Icons.cloud_off_outlined,
        message: message,
        height: height,
        onRetry: () {
          JikanClient.instance.resetReachability();
          onRetry();
        },
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final retry = onRetry;
    return SizedBox(
      height: height,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: scheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (retry != null) ...[
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: retry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(S.current.Res_Retry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Round picture of a character, a person or a user: the image clipped to a
/// circle, nothing painted behind it (no shadow, no elevation, no box). A
/// missing or broken picture shows a person icon on a tinted circle.
class RoundAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const RoundAvatar({
    super.key,
    required this.url,
    this.size = 56,
    this.onTap,
    this.semanticLabel,
  });

  /// MAL serves a grey "question mark" picture for people without a photo.
  static bool isPlaceholderUrl(String? url) =>
      url == null || url.trim().isEmpty || url.contains('questionmark');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
      child: Center(
        child: Icon(Icons.person, size: size * 0.55, color: scheme.onSecondaryContainer),
      ),
    );
    final picture = isPlaceholderUrl(url)
        ? fallback
        : AppImage(
            url: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            // MAL pictures are portraits: keep the face, not the chest.
            alignment: Alignment.topCenter,
            placeholderColor: scheme.surfaceContainerHighest,
            errorWidget: (_) => fallback,
          );
    final avatar = SizedBox.square(dimension: size, child: ClipOval(child: picture));
    final tap = onTap;
    if (tap == null) return Semantics(label: semanticLabel, image: true, child: avatar);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(customBorder: const CircleBorder(), onTap: tap, child: avatar),
      ),
    );
  }
}
