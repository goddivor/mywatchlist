import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Reads one field of the content preferences; rebuilds when it changes and
/// falls back to [Preferences.content] without a bloc above (tests).
T contentPref<T>(BuildContext context, T Function(ContentPreferences) read) {
  try {
    return context.select((PreferencesBloc bloc) => read(bloc.state.content));
  } on ProviderNotFoundException {
    return read(Preferences.content);
  }
}

/// Cover picture behind the header, faded into the page color from 78 % to
/// 100 % (as DailyAL). With the "detail background" preference off, or no
/// picture, it is just the page color. The picture is decoded at its
/// displayed size ([AppImage]) and the fade is a plain gradient.
class DetailHeaderBackground extends StatelessWidget {
  final String? url;

  const DetailHeaderBackground({super.key, this.url});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).scaffoldBackgroundColor;
    final show = contentPref(context, (c) => c.showDetailBackground);
    final picture = url;
    return ColoredBox(
      color: color,
      child: !show || picture == null || picture.isEmpty
          ? const SizedBox.expand()
          : Stack(
              fit: StackFit.expand,
              children: [
                AppImage(url: picture, fit: BoxFit.cover, errorWidget: (_) => const SizedBox.shrink()),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [color.withValues(alpha: .78), color],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
