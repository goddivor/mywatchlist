import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AuthWebView extends StatefulWidget {
  final String initialUrl;
  final Function(String) onAuthCodeReceived;

  const AuthWebView({super.key, required this.initialUrl, required this.onAuthCodeReceived});

  @override
  // ignore: library_private_types_in_public_api
  _AuthWebViewState createState() => _AuthWebViewState();
}

class _AuthWebViewState extends State<AuthWebView> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (url.startsWith('mywatchlist://callback')) {
              final uri = Uri.parse(url);
              final code = uri.queryParameters['code'];
              if (code != null) {
                widget.onAuthCodeReceived(code);
                Navigator.of(context).pop();
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ignore: prefer_const_constructors
        title: Text('Authenticatioin...'),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
