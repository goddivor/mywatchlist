import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_profile_service.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_actions.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_colors.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// The AniList profile header: the user's banner (or their profile colour) with the avatar,
/// the name, the supporter badge and the joined date over it. It fills the band a pinned
/// `SliverAppBar` leaves between the toolbar and the tab bar.
class AnilistProfileBanner extends StatelessWidget {
  final AnilistProfile profile;
  final double bottomInset;

  const AnilistProfileBanner({super.key, required this.profile, this.bottomInset = 0});

  /// Height of the band under the toolbar.
  static const double bandHeight = 140;

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final band = _Band(profile: profile);
    if (settings == null) return Padding(padding: EdgeInsets.only(bottom: bottomInset), child: band);
    final top = settings.minExtent - bottomInset;
    final height = settings.maxExtent - settings.minExtent;
    if (height <= 0) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottomInset),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.bottomCenter,
          minHeight: height,
          maxHeight: height,
          child: band,
        ),
      ),
    );
  }
}

class _Band extends StatelessWidget {
  final AnilistProfile profile;
  const _Band({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = AppColors.of(context);
    final s = S.of(context);
    final banner = profile.bannerUrl;
    final accent = anilistProfileColor(profile.profileColor);
    final onBanner = banner != null;
    final nameColor = onBanner ? tokens.onImageScrim : cs.onSurface;
    final detailColor = onBanner ? tokens.onImageScrim : cs.onSurfaceVariant;
    final joined = profile.data.joined == null ? null : DateTime.tryParse(profile.data.joined!);
    final details = [
      if (joined != null) s.Prof_Joined(DateFormat.yMMM().format(joined.toLocal())),
      if (profile.isFollower && !profile.isFollowing) s.Alpp_Follows_You,
      if (profile.isFollower && profile.isFollowing) s.Alpp_Follow_Each_Other,
    ].join(' · ');
    return Stack(
      fit: StackFit.expand,
      children: [
        if (onBanner) ...[
          AppImage(url: banner, fit: BoxFit.cover, placeholderColor: cs.surfaceContainerHighest),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.3],
                colors: [tokens.imageScrim.withValues(alpha: 0.25), tokens.imageScrim],
              ),
            ),
          ),
        ] else if (accent != null)
          ColoredBox(color: accent.withValues(alpha: 0.14)),
        Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 14),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: accent == null ? cs.surface : anilistReadableAccent(accent, cs),
                        width: 3),
                  ),
                  child: AnilistAvatar(
                      name: profile.data.username, url: profile.data.pictureUrl, size: 76),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.data.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700, color: nameColor),
                      ),
                      if (details.isNotEmpty)
                        Text(details,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: detailColor)),
                      if (profile.donatorBadge != null || profile.moderatorRoles.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (profile.donatorBadge != null)
                                _Badge(
                                    icon: Icons.favorite,
                                    label: profile.donatorBadge!,
                                    color: accent ?? cs.primary),
                              for (final role in profile.moderatorRoles)
                                _Badge(
                                    icon: Icons.shield_outlined,
                                    label: _role(s, role),
                                    color: cs.tertiary),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// AniList's moderator role as a readable label (`ADMIN` → "Admin", `FORUM_MOD` → "Forum
  /// mod"); the translated ones for the common roles.
  static String _role(S s, String role) => switch (role) {
        'ADMIN' => s.Alpp_Role_Admin,
        'MODERATOR' || 'FORUM_MOD' || 'COMMUNITY_MOD' => s.Alpp_Role_Moderator,
        _ => role.split('_').map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase()).join(' '),
      };
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = color;
    final fg = anilistOn(bg, cs);
    return DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
