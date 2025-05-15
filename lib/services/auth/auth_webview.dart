import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A StatefulWidget that displays a WebView for authentication purposes.
/// It takes an initial URL to load and a callback function to handle the
/// authentication code received from the redirect URL.
class AuthWebView extends StatefulWidget {
  final String initialUrl; // The initial URL to load in the WebView.
  final Function(String) onAuthCodeReceived; // Callback for handling the auth code.

  const AuthWebView({
    super.key,
    required this.initialUrl,
    required this.onAuthCodeReceived,
  });

  @override
  _AuthWebViewState createState() => _AuthWebViewState();
}

class _AuthWebViewState extends State<AuthWebView> {
  late WebViewController _controller; // Controller for managing the WebView.

  @override
  void initState() {
    super.initState();
    // Initialize the WebViewController with JavaScript enabled and set up navigation handling.
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // Enable JavaScript.
      ..setNavigationDelegate(
        NavigationDelegate(
          // Handle page navigation events.
          onPageFinished: (String url) {
            // Check if the URL starts with the custom callback scheme.
            if (url.startsWith('mywatchlist://callback')) {
              final uri = Uri.parse(url); // Parse the URL.
              final code = uri.queryParameters['code']; // Extract the 'code' query parameter.
              if (code != null) {
                widget.onAuthCodeReceived(code); // Pass the code to the callback.
                Navigator.of(context).pop(); // Close the WebView.
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl)); // Load the initial URL.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Authentication...'), // Title for the AppBar.
      ),
      // Display the WebView using the initialized controller.
      body: WebViewWidget(controller: _controller),
    );
  }
}
