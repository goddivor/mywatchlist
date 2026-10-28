import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/user/profile/profile_background.dart';

/// Formats an ISO date from the profile data as a short localized date; null when it cannot
/// be read. A day without its year ("--01-31", a birthday from MAL's page) reads "Jan 31".
String? formatProfileDate(String? iso, {bool withDay = true}) {
  final dayMonth = iso == null ? null : RegExp(r'^--(\d{2})-(\d{2})$').firstMatch(iso);
  if (dayMonth != null) {
    if (!withDay) return null;
    final month = int.parse(dayMonth.group(1)!);
    final day = int.parse(dayMonth.group(2)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateFormat.MMMd().format(DateTime(2000, month, day));
  }
  final date = iso == null ? null : DateTime.tryParse(iso);
  if (date == null) return null;
  final format = withDay ? DateFormat.yMMMd() : DateFormat.yMMM();
  return format.format(date.toLocal());
}

/// When a user was last online: an ISO time (Jikan) as a localized date and time, MAL's
/// "Now" translated, any other text of MAL's page ("5 minutes ago") as MAL gives it.
String? formatProfileLastOnline(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  if (text.toLowerCase() == 'now') return S.current.Prof_Online_Now;
  final date = DateTime.tryParse(text);
  if (date == null) return text;
  return DateFormat.yMMMd().add_jm().format(date.toLocal());
}

/// Avatar, name and key numbers of a profile.
///
/// It follows the theme: on the page surface with `onSurface` text, like the rest of the app
/// (light header in light mode, dark in dark and black). When the signed-in user picked a
/// profile background, the picture fills the header behind the image scrim token and the
/// text uses `onImageScrim`, so it reads on any picture.
///
/// Inside a `SliverAppBar.flexibleSpace` it only paints the band between the toolbar and the
/// [bottomInset] left for the tab bar: the toolbar and the tabs stay on the opaque themed app
/// bar, so the title, icons, tabs and status bar keep the theme's contrast. While the app bar
/// collapses the band slides up under the toolbar (clipped, no opacity layer). Anywhere else
/// (the quick sheet) it fills its parent.
class ProfileHeader extends StatefulWidget {
  final UserProfileData data;
  final bool isSelf;
  final double bottomInset;

  const ProfileHeader({
    super.key,
    required this.data,
    required this.isSelf,
    this.bottomInset = 0,
  });

  /// Height of the band (avatar, name, numbers) inside the profile app bar.
  static const double bandHeight = 120;

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  final _store = ProfileBackgroundStore.instance;

  @override
  void initState() {
    super.initState();
    if (widget.isSelf) {
      _store.addListener(_onBackgroundChanged);
      _store.load(widget.data.username).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    if (widget.isSelf) _store.removeListener(_onBackgroundChanged);
    super.dispose();
  }

  void _onBackgroundChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bgPath = widget.isSelf ? _store.cached(widget.data.username) : null;
    // The band is built here once per data or picture change; only [_CollapsingBand] reads
    // the app bar's scroll extent, so scrolling never rebuilds the content.
    return _CollapsingBand(
      bottomInset: widget.bottomInset,
      child: ProfileHeaderBand(data: widget.data, backgroundPath: bgPath),
    );
  }
}

/// Places [child] between the toolbar and the tab bar of a `SliverAppBar`, sliding it up
/// under the toolbar as the bar collapses. Without an app bar around, [child] fills the box.
class _CollapsingBand extends StatelessWidget {
  final double bottomInset;
  final Widget child;

  const _CollapsingBand({required this.bottomInset, required this.child});

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    if (settings == null) {
      return Padding(padding: EdgeInsets.only(bottom: bottomInset), child: child);
    }
    // minExtent = status bar + toolbar + tab bar; the band is what the bar adds above that.
    final top = settings.minExtent - bottomInset;
    final band = settings.maxExtent - settings.minExtent;
    if (band <= 0) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottomInset),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.bottomCenter,
          minHeight: band,
          maxHeight: band,
          child: child,
        ),
      ),
    );
  }
}

/// The content of the header: optional picture with its scrim, avatar, name, join date and
/// number of entries.
class ProfileHeaderBand extends StatelessWidget {
  final UserProfileData data;

  /// The local profile background, null for none (the header then sits on the surface).
  final String? backgroundPath;

  const ProfileHeaderBand({super.key, required this.data, this.backgroundPath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = AppColors.of(context);
    final s = S.of(context);
    final onPicture = backgroundPath != null;
    final nameColor = onPicture ? tokens.onImageScrim : cs.onSurface;
    final detailColor = onPicture ? tokens.onImageScrim : cs.onSurfaceVariant;
    final joined = formatProfileDate(data.joined, withDay: false);
    final entries = data.anime.totalEntries + data.manga.totalEntries;
    final details = [
      if (joined != null) s.Prof_Joined(joined),
      if (entries > 0) s.Prof_Entry_Count(entries),
    ].join(' · ');

    return Stack(
      fit: StackFit.expand,
      children: [
        if (onPicture) ...[
          _Picture(path: backgroundPath!),
          // The text sits in the lower part: full scrim there (white text ≥ 4.5:1 on a white
          // picture), fading out towards the top so the picture still shows.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.35],
                colors: [tokens.imageScrim.withValues(alpha: 0.25), tokens.imageScrim],
              ),
            ),
          ),
        ],
        Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
            child: Row(
              children: [
                _Avatar(url: data.pictureUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: nameColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          details,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(color: detailColor),
                        ),
                      ],
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
}

class _Avatar extends StatelessWidget {
  final String? url;

  static const double _size = 72;

  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = this.url;
    final placeholder = ColoredBox(
      color: cs.secondaryContainer,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Icon(Icons.person, size: 36, color: cs.onSecondaryContainer),
      ),
    );
    return GestureDetector(
      onTap: url == null ? null : () => zoomInImage(context, url),
      child: ClipOval(
        child: url == null
            ? placeholder
            : AppImage(
                url: url,
                width: _size,
                height: _size,
                placeholderColor: cs.secondaryContainer,
                errorWidget: (_) => placeholder,
              ),
      ),
    );
  }
}

class _Picture extends StatelessWidget {
  final String path;

  const _Picture({required this.path});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Image(
      image: ResizeImage(FileImage(File(path)), width: 1080),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(color: cs.surfaceContainerHighest),
    );
  }
}
