import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_badges.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// The badges of a MyAnimeList profile: a card with a row of badge pictures, each opening a
/// sheet with its name, month and link. Nothing at all is drawn while they load, when the
/// page fails or when the user has no badge.
class ProfileBadgesCard extends StatefulWidget {
  final String username;

  /// Replaced in tests.
  final Future<List<MalBadge>> Function(String username)? load;

  const ProfileBadgesCard({super.key, required this.username, this.load});

  @override
  State<ProfileBadgesCard> createState() => _ProfileBadgesCardState();
}

class _ProfileBadgesCardState extends State<ProfileBadgesCard> {
  late Future<List<MalBadge>> _badges = _start();

  Future<List<MalBadge>> _start() => (widget.load ?? MalBadges.of)(widget.username);

  @override
  void didUpdateWidget(ProfileBadgesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username) _badges = _start();
  }

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MalBadge>>(
      future: _badges,
      builder: (context, snapshot) {
        final badges = snapshot.data;
        if (badges == null || badges.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${S.of(context).Mb_Badges} · ${badges.length}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: _size + 40,
                  child: ListView.separated(
                    key: const ValueKey('profile-badges'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: badges.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => _BadgeTile(badge: badges[i], size: _size),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final MalBadge badge;
  final double size;

  const _BadgeTile({required this.badge, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: badge.name,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showBadge(context, badge),
        child: SizedBox(
          width: size + 8,
          child: Column(
            children: [
              AppImage(
                url: badge.imageUrl,
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorWidget: (_) => Icon(Icons.military_tech_outlined, size: size * 0.6),
              ),
              const SizedBox(height: 6),
              Text(
                badge.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showBadge(BuildContext context, MalBadge badge) {
  final s = S.of(context);
  final theme = Theme.of(context);
  final locale = Localizations.localeOf(context).toString();
  final earned = badge.earnedAt;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppImage(url: badge.imageUrl, width: 128, height: 128, fit: BoxFit.contain),
            const SizedBox(height: 16),
            Text(badge.name, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            if (earned != null) ...[
              const SizedBox(height: 6),
              Text(
                s.Mb_Badge_Earned(DateFormat.yMMMM(locale).format(earned)),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (badge.url != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  openLink(context, badge.url!);
                },
                icon: const Icon(Icons.open_in_new),
                label: Text(s.Open),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
