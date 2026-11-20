package com.teen.mywatchlist

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.webkit.CookieManager
import java.io.File
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GALLERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name")
                val album = call.argument<String>("album") ?: "MyWatchList"
                if (bytes == null || name.isNullOrEmpty()) {
                    result.error("bad_args", "bytes and name are required", null)
                    return@setMethodCallHandler
                }
                val main = Handler(Looper.getMainLooper())
                Thread {
                    try {
                        saveImage(bytes, name, album)
                        main.post { result.success(true) }
                    } catch (e: Exception) {
                        main.post { result.error("save_failed", e.message, null) }
                    }
                }.start()
            }
    }

    /**
     * Writes a PNG to Pictures/[album] so the gallery shows it. Android 10 and later go through
     * MediaStore (no permission); older versions write the file and ask the media scanner.
     */
    private fun saveImage(bytes: ByteArray, name: String, album: String) {
        val fileName = if (name.endsWith(".png")) name else "$name.png"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/$album")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("MediaStore refused the image")
            try {
                resolver.openOutputStream(uri)?.use { it.write(bytes) }
                    ?: throw IllegalStateException("No output stream")
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
        } else {
            @Suppress("DEPRECATION")
            val dir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), album)
            if (!dir.exists() && !dir.mkdirs()) throw IllegalStateException("No folder")
            val file = File(dir, fileName)
            file.writeBytes(bytes)
            MediaScannerConnection.scanFile(this, arrayOf(file.path), arrayOf("image/png"), null)
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
        const val GALLERY_CHANNEL = "com.teen.mywatchlist/gallery"
    }
}
