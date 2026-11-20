import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Saves images where the phone's gallery shows them: Pictures/[album] on Android (through
/// MediaStore, see MainActivity), the documents folder elsewhere.
class GallerySaver {
  GallerySaver._();

  static const MethodChannel _channel =
      MethodChannel('com.teen.mywatchlist/gallery');

  /// Saves the PNG [bytes] as [name] (without extension) and returns true when it was written.
  static Future<bool> savePng(Uint8List bytes, String name,
      {String album = 'MyWatchList'}) async {
    try {
      if (Platform.isAndroid) {
        // Android 9 and older write to shared storage and need the storage permission; later
        // versions ignore the request (the permission is capped at API 28 in the manifest).
        final status = await Permission.storage.status;
        if (!status.isGranted) await Permission.storage.request();
        final ok = await _channel.invokeMethod<bool>(
            'saveImage', {'bytes': bytes, 'name': name, 'album': album});
        return ok ?? false;
      }
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/$album');
      await folder.create(recursive: true);
      await File('${folder.path}/$name.png').writeAsBytes(bytes, flush: true);
      return true;
    } catch (e) {
      debugPrint('Gallery save failed: $e');
      return false;
    }
  }
}
