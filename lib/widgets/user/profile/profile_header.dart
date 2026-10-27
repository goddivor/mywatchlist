import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/user/profile/profile_background.dart';

/// Formats an ISO date from the profile data as a short localized date; null when it cannot
/// be read.
String? formatProfileDate(String? iso, {bool withDay = true}) {
  final date = iso == null ? null : DateTime.tryParse(iso);
  if (date == null) return null;
  final format = withDay ? DateFormat.yMMMd() : DateFormat.yMMM();
  return format.format(date.toLocal());
}

/// Avatar, name and key numbers over the profile background (the user's own picture on their
/// own profile, a theme gradient otherwise). Fills its parent: the parent leaves
/// [bottomInset] free for a tab bar.
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
    final data = widget.data;
    final theme = Theme.of(context);
    final s = S.of(context);
    final bgPath = widget.isSelf ? _store.cached(data.username) : null;
    final joined = formatProfileDate(data.joined, withDay: false);
    final entries = data.anime.totalEntries + data.manga.totalEntries;
    const onImage = Colors.white;

    return Stack(
      fit: StackFit.expand,
      children: [
        _Backdrop(path: bgPath, color: theme.colorScheme.primary),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0xB3000000)],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: widget.bottomInset + 12,
          child: Row(
            children: [
              GestureDetector(
                onTap: data.pictureUrl == null
                    ? null
                    : () => zoomInImage(context, data.pictureUrl!),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: onImage.withValues(alpha: 0.9), width: 2.5),
                  ),
                  child: ClipOval(
                    child: AppImage(
                      url: data.pictureUrl,
                      width: 72,
                      height: 72,
                      errorWidget: (_) => const SizedBox(
                        width: 72,
                        height: 72,
                        child: Icon(Icons.person, size: 36, color: onImage),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
                        color: onImage,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (joined != null) s.Prof_Joined(joined),
                        if (entries > 0) s.Prof_Entry_Count(entries),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onImage.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Backdrop extends StatelessWidget {
  final String? path;
  final Color color;

  const _Backdrop({required this.path, required this.color});

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    if (path != null) {
      return Image(
        image: ResizeImage(FileImage(File(path)), width: 1080),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _gradient(),
      );
    }
    return _gradient();
  }

  Widget _gradient() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.5)!],
          ),
        ),
      );
}
