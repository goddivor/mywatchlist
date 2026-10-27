import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs_lite.dart' as tabs;
import 'package:mywatchlist/constants/constants.dart' show showToast;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// Opens web pages for the whole app (replaces the deprecated `launch()`):
///
/// - [launchWebView]: opens a URL in an in-app browser tab (Custom Tabs on
///   Android, Safari view on iOS) themed with the app colors, or the system
///   browser elsewhere.
/// - [openLink]: what a tap on a link should do. MyAnimeList links are first
///   offered to [WebLauncher.internalLinkHandler] (in-app screens); other links
///   ask for confirmation, then open with [launchWebView].
/// - [parseMalLink]: recognizes a MyAnimeList URL (or a bare MAL path).
abstract final class WebLauncher {
  /// Routes a MyAnimeList link to an in-app screen and returns true when it
  /// did. Registered once by the app shell (`lib/utils/app_routes.dart`); while
  /// null, MAL links open in the browser like any other link.
  static InternalLinkHandler? internalLinkHandler;

  /// Opens [uri] outside Flutter. Tests replace it; the default is
  /// [defaultUrlOpener].
  @visibleForTesting
  static UrlOpener opener = defaultUrlOpener;
}

/// See [WebLauncher.internalLinkHandler].
typedef InternalLinkHandler = Future<bool> Function(BuildContext context, MalLink link);

/// See [WebLauncher.opener]. [barColor] / [onBarColor] theme the browser tab.
typedef UrlOpener = Future<bool> Function(Uri uri, {Color? barColor, Color? onBarColor, bool external});

/// A MyAnimeList page, from [parseMalLink]: `https://myanimelist.net/anime/5114/Fullmetal`
/// gives `kind: 'anime', id: 5114, segments: ['anime', '5114', 'Fullmetal']`.
@immutable
class MalLink {
  /// First path segment: `anime`, `manga`, `character`, `people`, `forum`,
  /// `profile`, `search`, `news`, `featured`, `stacks`, `clubs.php`…
  final String kind;

  /// Numeric id: second path segment, or `topicid` / `cid` / `id` query value.
  final int? id;
  final List<String> segments;
  final Map<String, String> query;
  final Uri uri;

  const MalLink({required this.kind, required this.segments, required this.query, required this.uri, this.id});

  @override
  String toString() => 'MalLink($kind, $id, $uri)';
}

const _malHosts = {'myanimelist.net', 'www.myanimelist.net', 'm.myanimelist.net'};

/// Parses [uri] when it is a MyAnimeList page: a `myanimelist.net` host, or no
/// host at all (relative links found in scraped MAL HTML). Returns null for
/// other sites and for the bare home page.
MalLink? parseMalLink(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host.isNotEmpty && !_malHosts.contains(host)) return null;
  if (host.isEmpty && uri.scheme.isNotEmpty) return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  final query = uri.queryParameters;
  final id = (segments.length > 1 ? int.tryParse(segments[1]) : null) ??
      int.tryParse(query['topicid'] ?? '') ??
      int.tryParse(query['cid'] ?? '') ??
      int.tryParse(query['id'] ?? '');
  return MalLink(kind: segments.first.toLowerCase(), id: id, segments: segments, query: query, uri: uri);
}

/// Opens [uri] in a Custom Tab / Safari view on mobile (http and https only),
/// the system handler otherwise; falls back to the external browser when the
/// in-app tab is unavailable.
Future<bool> defaultUrlOpener(Uri uri, {Color? barColor, Color? onBarColor, bool external = false}) async {
  final web = uri.scheme == 'http' || uri.scheme == 'https';
  final mobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  if (web && mobile && !external) {
    try {
      await tabs.launchUrl(
        uri,
        options: tabs.LaunchOptions(barColor: barColor, onBarColor: onBarColor, barFixingEnabled: false),
      );
      return true;
    } on PlatformException catch (e) {
      debugPrint('Custom tab unavailable, falling back to the browser: $e');
    }
  }
  return launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);
}

/// Opens [url] in an in-app browser tab themed from [context] (surface
/// colors), or in the system browser when [external]. Shows "Couldn't launch"
/// and returns false on failure.
Future<bool> launchWebView(String url, {BuildContext? context, bool external = false}) async {
  final uri = Uri.tryParse(url.trim());
  ColorScheme? scheme;
  if (context != null && context.mounted) scheme = Theme.of(context).colorScheme;
  var opened = false;
  if (uri != null && uri.hasScheme) {
    try {
      opened = await WebLauncher.opener(
        uri,
        barColor: scheme?.surface,
        onBarColor: scheme?.onSurface,
        external: external,
      );
    } catch (e) {
      debugPrint('launchWebView($url) failed: $e');
    }
  }
  if (!opened) showToast('${S.current.Couldn_Launch} $url');
  return opened;
}

/// What a tap on a link does. A MyAnimeList link handled by
/// [WebLauncher.internalLinkHandler] opens its in-app screen directly; any
/// other link asks first ([showOpenLinkDialog], skipped when [confirm] is
/// false) and opens with [launchWebView]. A relative MAL path nobody handles is
/// resolved against `https://myanimelist.net`.
///
/// ```dart
/// onTap: () => openLink(context, 'https://myanimelist.net/anime/5114'),
/// ```
Future<void> openLink(BuildContext context, String url, {bool confirm = true}) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) {
    showToast('${S.current.Couldn_Launch} $url');
    return;
  }
  final malLink = parseMalLink(uri);
  final handler = WebLauncher.internalLinkHandler;
  if (malLink != null && handler != null && await handler(context, malLink)) return;
  final target = uri.hasScheme ? uri : Uri.https('myanimelist.net', uri.path, uri.hasQuery ? uri.queryParameters : null);
  if (!context.mounted) return;
  if (confirm && await showOpenLinkDialog(context, target.toString()) != true) return;
  if (!context.mounted) return;
  await launchWebView(target.toString(), context: context);
}

/// Asks before leaving the app: shows the full [url] (selectable) with Copy,
/// Cancel and Open. Completes with true when the user chose Open.
Future<bool?> showOpenLinkDialog(BuildContext context, String url) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      return AlertDialog(
        icon: const Icon(Icons.open_in_new),
        title: Text(S.current.Just_a_sec),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(S.current.Url_open_conf),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                url,
                maxLines: 4,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.of(dialogContext).pop(false);
              ScaffoldMessenger.maybeOf(context)
                  ?.showSnackBar(SnackBar(content: Text(S.current.Copied_to_Clipboard)));
            },
            child: Text(S.current.Copy),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.current.Cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.current.Kit_Open_Link),
          ),
        ],
      );
    },
  );
}
