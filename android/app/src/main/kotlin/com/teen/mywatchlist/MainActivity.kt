package com.teen.mywatchlist

import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COOKIE_CHANNEL)
            .setMethodCallHandler { call, result ->
                val url = call.argument<String>("url")
                if (url.isNullOrEmpty()) {
                    result.error("bad_args", "url is required", null)
                    return@setMethodCallHandler
                }
                val cookies = CookieManager.getInstance()
                when (call.method) {
                    // The WebView's own jar, HttpOnly cookies included (document.cookie cannot see them).
                    "getCookies" -> result.success(cookies.getCookie(url))
                    "clearCookies" -> {
                        clearCookies(cookies, url)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Expires every cookie the jar sends to [url], for the host and its parent domain. */
    private fun clearCookies(cookies: CookieManager, url: String) {
        val host = android.net.Uri.parse(url).host ?: return
        val names = cookies.getCookie(url)
            ?.split(';')
            ?.mapNotNull { it.substringBefore('=').trim().takeIf(String::isNotEmpty) }
            ?: emptyList()
        val expired = "=; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=/"
        for (name in names) {
            cookies.setCookie(url, "$name$expired")
            cookies.setCookie(url, "$name$expired; Domain=$host")
            cookies.setCookie(url, "$name$expired; Domain=.$host")
        }
        cookies.flush()
    }

    private companion object {
        const val COOKIE_CHANNEL = "com.teen.mywatchlist/webview_cookies"
    }
}
