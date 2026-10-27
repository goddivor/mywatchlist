import 'package:flutter/material.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Round tracker logo on a neutral disc (the logos are square pictures with their own
/// background, so they are clipped, not tinted).
class TrackerLogo extends StatelessWidget {
  final TrackerInfo info;
  final double size;

  const TrackerLogo({super.key, required this.info, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        info.logoAsset,
        width: size,
        height: size,
        cacheWidth: (size * 3).round(),
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Avatar of an account: the profile picture (decoded at its displayed size through
/// [AppImage]) with a small tracker badge, or the tracker logo when there is no picture.
class AccountAvatar extends StatelessWidget {
  final TrackerInfo info;
  final String? imageUrl;
  final double size;

  /// Draws the tracker logo in a corner of a profile picture, so two accounts of different
  /// trackers are told apart at a glance.
  final bool showBadge;

  const AccountAvatar({
    super.key,
    required this.info,
    this.imageUrl,
    this.size = 48,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return TrackerLogo(info: info, size: size);
    }
    final badge = size * 0.4;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AppImage(
            url: url,
            width: size,
            height: size,
            borderRadius: BorderRadius.circular(size),
            placeholderColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            errorWidget: (_) => TrackerLogo(info: info, size: size),
          ),
          if (showBadge)
            Positioned(
              right: -badge * 0.15,
              bottom: -badge * 0.15,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: TrackerLogo(info: info, size: badge),
              ),
            ),
        ],
      ),
    );
  }
}
