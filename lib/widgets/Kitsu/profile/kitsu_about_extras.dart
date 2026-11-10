import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_profile.dart';
import 'package:mywatchlist/utils/web_launcher.dart';

/// What the About tab adds under the user's text: the counters of what they wrote, and their
/// social links. [summary] loads the links; when it fails or has none, only the counters show.
class KitsuAboutExtras extends StatelessWidget {
  final KitsuProfile profile;
  final Future<KitsuProfileSummary?> Function() summary;

  const KitsuAboutExtras({super.key, required this.profile, required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();
    final counters = <(String, int)>[
      (s.Kitsu_Stat_Posts, profile.postsCount),
      (s.Kitsu_Stat_Comments, profile.commentsCount),
      (s.Kitsu_Stat_Reactions, profile.reactionsCount),
      (s.Kitsu_Stat_Likes, profile.likesReceivedCount),
    ].where((c) => c.$2 > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (counters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                for (final c in counters)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(number.format(c.$2),
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      Text(c.$1,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
              ],
            ),
          ),
        _SiteLinks(load: summary),
      ],
    );
  }
}

class _SiteLinks extends StatefulWidget {
  final Future<KitsuProfileSummary?> Function() load;

  const _SiteLinks({required this.load});

  @override
  State<_SiteLinks> createState() => _SiteLinksState();
}

class _SiteLinksState extends State<_SiteLinks> {
  late final Future<KitsuProfileSummary?> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<KitsuProfileSummary?>(
      future: _future,
      builder: (context, snapshot) {
        final links = snapshot.data?.siteLinks ?? const <KitsuSiteLink>[];
        if (links.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final link in links)
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: Text(link.site.isEmpty ? link.url : link.site),
                subtitle: link.site.isEmpty
                    ? null
                    : Text(link.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: link.url.startsWith('http')
                    ? () => launchWebView(link.url, context: context)
                    : null,
              ),
          ],
        );
      },
    );
  }
}
