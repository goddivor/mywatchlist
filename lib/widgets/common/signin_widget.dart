import 'package:flutter/material.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/widgets/common/acc_widget.dart';

/// Header of the sign-in screens: the app logo over the four tracker logos, a title and a
/// sentence. Static (no animation, no shadow), so it costs nothing while the list scrolls.
class SigninWidget extends StatelessWidget {
  final String title;
  final String subtitle;

  const SigninWidget({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/mwl-black-bg.png',
            width: 72,
            height: 72,
            cacheWidth: 216,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 16),
        ExcludeSemantics(
          child: Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final info in TrackerInfo.all)
                TrackerLogo(info: info, size: 28),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: colors.onSurface),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
