import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:mywatchlist/widgets/MAL/review/user_link.dart' show isLinkableUser;

/// MyAnimeList pages the forum and club screens link to.
abstract final class ForumUrls {
  static const _base = 'https://myanimelist.net';

  static String topic(int id) => '$_base/forum/?topicid=$id';
  static String reply(int topicId) => '$_base/forum/?action=message&topic_id=$topicId';
  static String club(int id) => '$_base/clubs.php?cid=$id';
  static String joinClub(int id) => '$_base/clubs.php?action=join&id=$id';
  static String createClub() => '$_base/clubs.php?action=create';
  static String report(String type, Map<String, String> query) =>
      '$_base/modules.php?go=report&type=$type&${query.entries.map((e) => '${e.key}=${e.value}').join('&')}';

  static String board({int? boardId, int? subBoardId, int? animeId, int? mangaId}) {
    final query = <String>[
      if (boardId != null) 'board=$boardId',
      if (subBoardId != null) 'subboard=$subBoardId',
      if (animeId != null) 'animeid=$animeId',
      if (mangaId != null) 'mangaid=$mangaId',
    ];
    return query.isEmpty ? '$_base/forum/' : '$_base/forum/?${query.join('&')}';
  }
}

/// Opens the quick profile sheet of a MyAnimeList user (forum and clubs always show MAL users,
/// whichever tracker is signed in).
void openForumUser(BuildContext context, String? username) {
  if (!isLinkableUser(username)) return;
  AppRoutes.openUserPop(context, tracker: AccountType.myanimelist, username: username);
}

/// MAL user pictures known by name, for avatars drawn without a URL (the message list, whose
/// rows have no picture in MAL's markup). The messages screens fill it from each user's
/// profile; an avatar with no URL shows the known picture as soon as it arrives.
abstract final class ForumAvatarPictures {
  static final Map<String, ValueNotifier<String?>> _byName = {};

  static String _key(String name) => name.trim().toLowerCase();

  /// The notifier of [name]'s picture (null until known).
  static ValueNotifier<String?> of(String name) => _byName.putIfAbsent(_key(name), () => ValueNotifier<String?>(null));

  /// The picture known for [name], or null.
  static String? lookup(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    return _byName[_key(name)]?.value;
  }

  /// Records [url] as [name]'s picture (an empty URL is ignored).
  static void remember(String? name, String? url) {
    if (name == null || name.trim().isEmpty || url == null || url.trim().isEmpty) return;
    of(name).value = url.trim();
  }

  @visibleForTesting
  static void clear() => _byName.clear();
}

/// A round user picture: a clean circle (clip, no shadow, no border box) with the user's
/// initials while it loads or when there is no picture. Tapping opens the quick profile sheet.
class ForumAvatar extends StatelessWidget {
  const ForumAvatar({
    super.key,
    required this.username,
    this.url,
    this.size = 40,
    this.selected = false,
    this.tappable = true,
  });

  final String? username;
  final String? url;
  final double size;

  /// Shows a check instead of the picture (a post picked for sharing).
  final bool selected;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final name = username?.trim() ?? '';
    if ((url == null || url!.isEmpty) && !selected && name.isNotEmpty) {
      return ValueListenableBuilder<String?>(
        valueListenable: ForumAvatarPictures.of(name),
        builder: (context, known, _) => _build(context, name, known),
      );
    }
    return _build(context, name, url);
  }

  Widget _build(BuildContext context, String name, String? url) {
    final scheme = Theme.of(context).colorScheme;
    final initials = Center(
      child: Text(
        name.isEmpty ? '?' : name.characters.take(2).toString().toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );

    final Widget content;
    if (selected) {
      content = ColoredBox(
        color: scheme.primary,
        child: Center(child: Icon(Icons.check, size: size * 0.55, color: scheme.onPrimary)),
      );
    } else {
      content = ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: url == null || url.isEmpty
            ? initials
            : AppImage(
                url: url,
                width: size,
                height: size,
                errorWidget: (_) => initials,
                placeholder: (_) => initials,
              ),
      );
    }

    final circle = SizedBox(width: size, height: size, child: ClipOval(child: content));
    if (!tappable || !isLinkableUser(username)) return circle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openForumUser(context, username),
      child: circle,
    );
  }
}

/// A centered message with an icon and an optional Retry button; scrollable so a pull to refresh
/// still works over it.
class ForumMessage extends StatelessWidget {
  const ForumMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.onRetry,
    this.scrollable = true,
  });

  /// "Couldn't load this page" with the usual explanation and a Retry button.
  ForumMessage.error({Key? key, required VoidCallback onRetry, bool scrollable = true})
      : this(
          key: key,
          icon: Icons.cloud_off_outlined,
          title: S.current.Fc_Error_Title,
          body: S.current.Fc_Error_Body,
          onRetry: onRetry,
          scrollable: scrollable,
        );

  final IconData icon;
  final String title;
  final String? body;
  final VoidCallback? onRetry;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface),
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(S.current.Fc_Retry),
            ),
          ],
        ],
      ),
    );
    if (!scrollable) return Center(child: content);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

/// Placeholder rows shown while a list loads (a few rows in a column, never a long list).
class ForumSkeleton extends StatelessWidget {
  const ForumSkeleton({
    super.key,
    this.count = 6,
    this.rowHeight = 64,
    this.round = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final int count;
  final double rowHeight;

  /// A round picture slot on the left (people), else a plain bar.
  final bool round;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = scheme.surfaceContainerHighest;
    Widget bar(double height, {double? width}) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(color: shape, borderRadius: BorderRadius.circular(6)),
        );
    return ShimmerColor(
      Padding(
        padding: padding,
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(
                height: rowHeight,
                child: Row(
                  children: [
                    if (round) ...[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: shape, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(14),
                          const SizedBox(height: 8),
                          bar(10, width: 140),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A staff position (President, Admin…) on a readable chip.
class StaffBadge extends StatelessWidget {
  const StaffBadge(this.position, {super.key});

  final String position;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          position,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

/// A small icon + number/text pill (replies, members…), readable on any surface.
class ForumStatChip extends StatelessWidget {
  const ForumStatChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _fontSizeRule = RegExp(r'font-size\s*:\s*[^;]+;');

/// MAL's HTML (club description, club comments) with tappable pictures and links: a link goes
/// through [openLink] (in-app screen for MAL pages, else the in-app browser).
class MalHtmlBody extends StatelessWidget {
  const MalHtmlBody(this.html, {super.key, this.style});

  final String html;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      html.replaceAll(_fontSizeRule, ''),
      textStyle: style ?? Theme.of(context).textTheme.bodyMedium,
      onTapUrl: (url) {
        openLink(context, url);
        return true;
      },
      customWidgetBuilder: (element) {
        if (element.localName != 'img') return null;
        final src = element.attributes['src'] ?? element.attributes['data-src'];
        if (src == null || src.isEmpty) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => zoomInImage(context, src),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: AppImage(
              url: src,
              fit: BoxFit.contain,
              errorWidget: (_) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
