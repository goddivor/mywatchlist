import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// How an [AuthWebView] ended.
@immutable
class AuthWebViewResult {
  /// The OAuth redirect (with `code`), or null when the user closed the page.
  final Uri? callback;

  /// The user asked to continue in the system browser instead.
  final bool useBrowser;

  const AuthWebViewResult._({this.callback, this.useBrowser = false});

  const AuthWebViewResult.closed() : this._();
}

/// The in-app sign-in page of an OAuth tracker. It loads [initialUrl] and stops at the first
/// navigation to [redirectPrefix] (the app's callback scheme, which a WebView cannot open),
/// so the WebView that the user signed in with is still alive when the code arrives: the MAL
/// sign in reads the website cookies from it at that moment.
class AuthWebView extends StatefulWidget {
  final String initialUrl;

  /// The redirect URI prefix that ends the flow.
  final String redirectPrefix;

  /// Title of the app bar (the tracker name).
  final String? title;

  /// Legacy callback: called with the `code` (the page then closes itself).
  final void Function(String code)? onAuthCodeReceived;

  /// Shows "Open in browser" in the menu (the caller then uses its browser flow).
  final bool allowBrowser;

  const AuthWebView({
    super.key,
    required this.initialUrl,
    this.redirectPrefix = 'mywatchlist://callback',
    this.title,
    this.onAuthCodeReceived,
    this.allowBrowser = false,
  });

  /// Opens the page and returns how it ended.
  static Future<AuthWebViewResult> open(
    BuildContext context, {
    required String url,
    required String redirectPrefix,
    String? title,
    bool allowBrowser = false,
  }) async {
    final result = await Navigator.of(context).push<AuthWebViewResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AuthWebView(
          initialUrl: url,
          redirectPrefix: redirectPrefix,
          title: title,
          allowBrowser: allowBrowser,
        ),
      ),
    );
    return result ?? const AuthWebViewResult.closed();
  }

  @override
  State<AuthWebView> createState() => _AuthWebViewState();
}

class _AuthWebViewState extends State<AuthWebView> {
  late final WebViewController _controller;
  final ValueNotifier<int> _progress = ValueNotifier(0);
  bool _failed = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              _maybeFinish(request.url) ? NavigationDecision.prevent : NavigationDecision.navigate,
          onUrlChange: (change) => _maybeFinish(change.url),
          onPageStarted: (url) {
            if (_maybeFinish(url)) return;
            if (_failed && mounted) setState(() => _failed = false);
          },
          onPageFinished: _maybeFinish,
          onProgress: (p) => _progress.value = p,
          onWebResourceError: (error) {
            if (_maybeFinish(error.url)) return;
            final mainFrame = error.isForMainFrame ?? true;
            if (mainFrame && mounted && !_done) setState(() => _failed = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  /// Ends the flow on the redirect; true when [url] was the redirect.
  bool _maybeFinish(String? url) {
    if (url == null || !url.startsWith(widget.redirectPrefix)) return false;
    if (_done) return true;
    _done = true;
    final uri = Uri.parse(url);
    final legacy = widget.onAuthCodeReceived;
    final code = uri.queryParameters['code'];
    if (legacy != null && code != null) legacy(code);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(AuthWebViewResult._(callback: uri));
    });
    return true;
  }

  void _reload() {
    setState(() => _failed = false);
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).pop(const AuthWebViewResult.closed()),
        ),
        title: Text(widget.title ?? s.Ms_Sign_In_Title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: s.Ms_Reload,
            onPressed: _reload,
          ),
          if (widget.allowBrowser)
            PopupMenuButton<int>(
              onSelected: (_) =>
                  Navigator.of(context).pop(const AuthWebViewResult._(useBrowser: true)),
              itemBuilder: (context) => [
                PopupMenuItem(value: 0, child: Text(s.Ms_Open_In_Browser)),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: ValueListenableBuilder<int>(
            valueListenable: _progress,
            builder: (context, p, _) => p >= 100
                ? const SizedBox(height: 2)
                : LinearProgressIndicator(
                    minHeight: 2,
                    value: p <= 0 ? null : p / 100,
                    color: scheme.primary,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
          ),
        ),
      ),
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 48, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      s.Ms_Page_Failed,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonal(onPressed: _reload, child: Text(s.Ms_Retry)),
                  ],
                ),
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}
