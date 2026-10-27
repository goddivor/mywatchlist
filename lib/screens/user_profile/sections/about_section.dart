import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';
import 'package:mwl_commons/mwl_commons.dart' show UserAboutHtml;

/// The "about me" text of a profile. MAL serves it as HTML; links open through [openLink]
/// and pictures through [AppImage].
class AboutSection extends StatelessWidget {
  final String username;
  final bool isSelf;

  const AboutSection({super.key, required this.username, required this.isSelf});

  static const String _editUrl = 'https://myanimelist.net/editprofile.php';
  static const String _modernEditUrl =
      'https://mxj.myanimelist.net/about-me/?utm_source=MAL&utm_medium=profile_link_about-me';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AsyncProfileTab<UserAboutHtml?>(
      storageKey: 'about_$username',
      loader: () async {
        final about = await MwlApi.i.getUserAboutHtml(username);
        if (about == null) throw StateError('No about for $username');
        return about;
      },
      isEmpty: (about) => (about?.about ?? '').trim().isEmpty,
      emptyBuilder: (context) => ProfileMessage(
        icon: Icons.notes_outlined,
        title: isSelf ? s.Prof_About_Empty_Self : s.Prof_About_Empty,
        actionLabel: isSelf ? s.Prof_About_Edit : null,
        onAction: isSelf ? () => openLink(context, _editUrl) : null,
      ),
      slivers: (context, about) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: HtmlWidget(
              about!.about!,
              textStyle: Theme.of(context).textTheme.bodyMedium,
              onTapUrl: (url) {
                openLink(context, url);
                return true;
              },
              customWidgetBuilder: (element) {
                if (element.localName != 'img') return null;
                final src = element.attributes['src'] ?? element.attributes['data-src'];
                if (src == null || src.isEmpty) return const SizedBox.shrink();
                final width = MediaQuery.sizeOf(context).width - 32;
                return GestureDetector(
                  onTap: () => zoomInImage(context, src),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: AppImage(
                      url: src,
                      width: width,
                      fit: BoxFit.contain,
                      errorWidget: (_) => const SizedBox.shrink(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (isSelf)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => openLink(context, about.modern ? _modernEditUrl : _editUrl),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(s.Prof_About_Edit),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.Prof_About_Edit_Hint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
