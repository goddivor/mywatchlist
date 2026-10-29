import 'package:flutter/material.dart';
import 'package:mywatchlist/cache/cached_user_profile.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/user/profile/profile_header.dart' show timeZoneLabel;
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';
import 'package:mwl_commons/mwl_commons.dart' show UserAboutHtml;

/// The "about me" text of a profile. MAL serves it as HTML; links open through [openLink]
/// and pictures through [AppImage]. When the profile came from MAL's page, [fromPage] holds
/// the text already read there and no request is made; otherwise the mwl-api route answers.
class AboutSection extends StatelessWidget {
  final String username;
  final bool isSelf;
  final UserAboutHtml? fromPage;

  /// The account's IANA time zone (`America/Los_Angeles`); only the official API gives it,
  /// so only for the signed-in user. When null on your own profile, the cached profile is
  /// asked.
  final String? timezone;

  const AboutSection({
    super.key,
    required this.username,
    required this.isSelf,
    this.fromPage,
    this.timezone,
  });

  static const String _editUrl = 'https://myanimelist.net/editprofile.php';
  static const String _modernEditUrl =
      'https://mxj.myanimelist.net/about-me/?utm_source=MAL&utm_medium=profile_link_about-me';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AsyncProfileTab<UserAboutHtml?>(
      storageKey: 'about_$username',
      loader: () async {
        final known = fromPage;
        if (known != null && (known.about ?? '').trim().isNotEmpty) return known;
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
        if (isSelf)
          SliverToBoxAdapter(
            child: AboutTimeZone(username: username, timezone: timezone),
          ),
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

/// The labelled "Time zone" line at the top of your About block. Hidden while unknown.
class AboutTimeZone extends StatefulWidget {
  final String username;
  final String? timezone;

  const AboutTimeZone({super.key, required this.username, this.timezone});

  @override
  State<AboutTimeZone> createState() => _AboutTimeZoneState();
}

class _AboutTimeZoneState extends State<AboutTimeZone> {
  String? _zone;

  @override
  void initState() {
    super.initState();
    _zone = widget.timezone;
    if (timeZoneLabel(_zone) == null) _fromCache();
  }

  Future<void> _fromCache() async {
    final entry = await CachedUserProfile.instance.read(widget.username);
    final zone = entry?.json['timezone'];
    if (!mounted || zone is! String) return;
    setState(() => _zone = zone);
  }

  @override
  Widget build(BuildContext context) {
    final label = timeZoneLabel(_zone);
    if (label == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            S.of(context).Mpl_Time_Zone,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Flexible(
            child: Text(label, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
