import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_profile_rows.dart' show kitsuTimeAgo;
import 'package:mywatchlist/widgets/common/app_image.dart';

/// A round avatar with the author's initial when there is no picture.
class KitsuAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  const KitsuAvatar({super.key, required this.url, required this.name, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return AppImage(
      url: url,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
      placeholderColor: scheme.surfaceContainerHighest,
      errorWidget: (_) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
        child: Text(initial,
            style: TextStyle(
                color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600, fontSize: size * 0.4)),
      ),
    );
  }
}

/// Hides [child] behind a tap while [hidden] (a spoiler or a sensitive post).
class KitsuReveal extends StatefulWidget {
  final bool hidden;
  final String label;
  final Widget child;
  const KitsuReveal({super.key, required this.hidden, required this.label, required this.child});

  @override
  State<KitsuReveal> createState() => _KitsuRevealState();
}

class _KitsuRevealState extends State<KitsuReveal> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.hidden || _shown) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _shown = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.visibility_off_outlined, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kitsu's formatted body (HTML) when there is one, else the plain text.
class KitsuBody extends StatelessWidget {
  final String text;
  final String? html;
  final int? maxLines;
  const KitsuBody({super.key, required this.text, this.html, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final html = this.html;
    if (maxLines != null || html == null || html.trim().isEmpty) {
      return Text(text.trim(),
          style: style, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis);
    }
    return HtmlWidget(
      html,
      textStyle: style,
      onTapUrl: (url) {
        openLink(context, url);
        return true;
      },
    );
  }
}

/// Spoiler and sensitive-content guard around a post body.
class KitsuGuardedBody extends StatelessWidget {
  final String text;
  final String? html;
  final bool isSpoiler;
  final bool isNsfw;
  final int? maxLines;
  const KitsuGuardedBody({
    super.key,
    required this.text,
    this.html,
    this.isSpoiler = false,
    this.isNsfw = false,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return KitsuReveal(
      hidden: isSpoiler || isNsfw,
      label: isNsfw ? s.Kc_Nsfw_Hidden : s.Kc_Spoiler_Hidden,
      child: KitsuBody(text: text, html: html, maxLines: maxLines),
    );
  }
}

/// "Alice · 3 hours ago".
class KitsuByline extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final DateTime? at;
  final bool nsfw;
  final double avatarSize;
  const KitsuByline({
    super.key,
    required this.name,
    this.avatarUrl,
    this.at,
    this.nsfw = false,
    this.avatarSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Row(
      children: [
        KitsuAvatar(url: avatarUrl, name: name, size: avatarSize),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall),
              if (at != null) Text(kitsuTimeAgo(at), style: muted),
            ],
          ),
        ),
        if (nsfw)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(S.of(context).Kc_Nsfw_Badge,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onErrorContainer)),
          ),
      ],
    );
  }
}

/// Counts under a post: likes and comments.
class KitsuCounts extends StatelessWidget {
  final int likes;
  final int comments;
  const KitsuCounts({super.key, required this.likes, required this.comments});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Row(
      children: [
        Icon(Icons.favorite_border, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(s.Kc_Like_Count(likes), style: style),
        const SizedBox(width: 16),
        Icon(Icons.chat_bubble_outline, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(s.Kc_Comment_Count(comments), style: style),
      ],
    );
  }
}

/// Centered error with a retry, or a plain empty message.
class KitsuStateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Sits right under what is above (a search field) instead of floating in the middle of the
  /// space left, which read as a large empty band.
  final bool top;
  const KitsuStateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.top = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: top ? Alignment.topCenter : Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The spinner or retry row at the end of a paged list.
class KitsuListFooter extends StatelessWidget {
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;
  const KitsuListFooter({super.key, required this.loading, required this.failed, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: failed
            ? TextButton(onPressed: onRetry, child: Text(S.of(context).Kc_Retry))
            : loading
                ? const SizedBox(
                    width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const SizedBox.shrink(),
      ),
    );
  }
}
