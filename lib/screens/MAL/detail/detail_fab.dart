import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show loadingCenter;
import 'package:mywatchlist/enums.dart' show combinedStatusMap;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';

/// Edit button: spinner while loading, extended "status + pencil" when the
/// edit panel is closed, compact close button when it is open. Null (no
/// button) when the details failed to load. A title in the list takes its
/// list status colours (theme tokens: DailyAL's green, blue, orange, red,
/// brown chips with their own foreground); otherwise the theme's FAB colours.
Widget? buildDetailFab({
  required DetailData data,
  required bool editOpen,
  required VoidCallback onPressed,
}) {
  final content = data.content;
  if (content == null) {
    if (data.state == DetailLoadState.failed) return null;
    return FloatingActionButton(onPressed: () {}, child: loadingCenter());
  }
  final editIcon = Icon(editOpen ? Icons.close : Icons.edit);
  if (editOpen) {
    return FloatingActionButton(
      heroTag: 'compact-floating',
      onPressed: onPressed,
      child: editIcon,
    );
  }
  final status = content.myListStatus?.status;
  final statusLabel = status == null ? null : combinedStatusMap[status];
  return Builder(builder: (context) {
    final role = AppColors.of(context).statusOf(status);
    return FloatingActionButton.extended(
      heroTag: 'extended-floating',
      onPressed: onPressed,
      isExtended: true,
      icon: statusLabel != null
          ? Text(statusLabel, style: const TextStyle(fontWeight: FontWeight.w600))
          : const SizedBox(),
      label: editIcon,
      backgroundColor: role?.container,
      foregroundColor: role?.onContainer,
    );
  });
}

/// FAB animator without the scale/rotation of the default one, so switching
/// between the extended and compact buttons only slides.
class NoScalingAnimation extends FloatingActionButtonAnimator {
  @override
  Offset getOffset(
      {required Offset begin, required Offset end, required double progress}) {
    return Offset(
      begin.dx + (end.dx - begin.dx) * progress,
      begin.dy + (end.dy - begin.dy) * progress,
    );
  }

  @override
  Animation<double> getRotationAnimation({required Animation<double> parent}) =>
      const AlwaysStoppedAnimation(1.0);

  @override
  Animation<double> getScaleAnimation({required Animation<double> parent}) =>
      const AlwaysStoppedAnimation(1.0);
}
