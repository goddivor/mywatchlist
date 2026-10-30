import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Why a picture could not be uploaded.
enum ImageUploadError {
  /// No connection, DNS failure, timeout.
  offline,

  /// Bigger than the host accepts.
  tooLarge,

  /// The host answered, but not with a picture URL (refused, down, rate limited).
  refused,

  /// The file could not be read from the phone.
  unreadable,
}

class ImageUploadFailed implements Exception {
  const ImageUploadFailed(this.reason, [this.detail]);

  final ImageUploadError reason;
  final String? detail;

  @override
  String toString() => 'ImageUploadFailed($reason${detail == null ? '' : ': $detail'})';
}

/// The upload was cancelled by the user.
class ImageUploadCancelled implements Exception {
  const ImageUploadCancelled();
}

/// A picture to upload: its bytes come from [read] so a fake needs no file.
class UploadImage {
  const UploadImage({required this.name, required this.read, this.length});

  /// A picture on disk (what image_picker returns).
  factory UploadImage.file(String path, {String? name}) {
    final file = File(path);
    return UploadImage(
      name: name ?? path.split(Platform.pathSeparator).last,
      read: file.readAsBytes,
      length: file.lengthSync,
    );
  }

  final String name;
  final Future<Uint8List> Function() read;
  final int Function()? length;
}

/// Cancels an upload in progress.
class UploadCancel {
  final CancelToken _token = CancelToken();
  bool get isCancelled => _token.isCancelled;
  void cancel() => _token.cancel();
}

/// Uploads a picture somewhere public and answers its URL.
abstract class ImageUploader {
  /// [onProgress] gets 0..1 while the bytes are sent.
  Future<Uri> upload(UploadImage image, {void Function(double progress)? onProgress, UploadCancel? cancel});
}

/// catbox.moe anonymous uploads (owner's decision, see docs/DECISIONS.md): no account,
/// `POST https://catbox.moe/user/api.php` multipart `reqtype=fileupload` + `fileToUpload`, the
/// answer body is the file's URL (`https://files.catbox.moe/<id>.<ext>`), anything else is a
/// refusal. Files are kept by catbox without expiry; 200 MB at most.
class CatboxUploader implements ImageUploader {
  CatboxUploader({Dio? dio}) : _dio = dio ?? Dio();

  static ImageUploader instance = CatboxUploader();

  static final Uri endpoint = Uri.parse('https://catbox.moe/user/api.php');
  static const int maxBytes = 200 * 1024 * 1024;
  static final RegExp _fileUrl = RegExp(r'^https://files\.catbox\.moe/[A-Za-z0-9._-]+$');

  final Dio _dio;

  @override
  Future<Uri> upload(UploadImage image, {void Function(double progress)? onProgress, UploadCancel? cancel}) async {
    final int? size;
    final Uint8List bytes;
    try {
      size = image.length?.call();
      if (size != null && size > maxBytes) throw const ImageUploadFailed(ImageUploadError.tooLarge);
      bytes = await image.read();
    } on ImageUploadFailed {
      rethrow;
    } catch (e) {
      throw ImageUploadFailed(ImageUploadError.unreadable, '$e');
    }
    if (bytes.length > maxBytes) throw const ImageUploadFailed(ImageUploadError.tooLarge);
    if (bytes.isEmpty) throw const ImageUploadFailed(ImageUploadError.unreadable, 'empty file');

    final form = FormData.fromMap({
      'reqtype': 'fileupload',
      'fileToUpload': MultipartFile.fromBytes(bytes, filename: _safeName(image.name)),
    });
    try {
      final response = await _dio.postUri<String>(
        endpoint,
        data: form,
        cancelToken: cancel?._token,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'User-Agent': 'MyWatchList'},
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
          validateStatus: (_) => true,
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) onProgress((sent / total).clamp(0.0, 1.0));
        },
      );
      final body = (response.data ?? '').trim();
      if (response.statusCode == 413) throw const ImageUploadFailed(ImageUploadError.tooLarge);
      if ((response.statusCode ?? 0) ~/ 100 != 2 || !_fileUrl.hasMatch(body)) {
        throw ImageUploadFailed(ImageUploadError.refused, '${response.statusCode} ${_short(body)}');
      }
      return Uri.parse(body);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) throw const ImageUploadCancelled();
      throw ImageUploadFailed(ImageUploadError.offline, e.type.name);
    }
  }

  static String _safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'image.jpg' : cleaned;
  }

  static String _short(String s) => s.length <= 120 ? s : '${s.substring(0, 120)}…';
}

/// freeimage.host anonymous uploads, the default since catbox.moe started storing empty files
/// (checked 2026-10-30: every new catbox file answered 200 with 0 bytes). No account: the key
/// below is the public one freeimage.host publishes for its API. `POST /api/1/upload`
/// multipart `key`, `action=upload`, `format=json`, `source`; the answer's `image.url` is the
/// direct link (`https://iili.io/<id>.<ext>`). 64 MB at most.
class FreeimageUploader implements ImageUploader {
  FreeimageUploader({Dio? dio}) : _dio = dio ?? Dio();

  static ImageUploader instance = FreeimageUploader();

  static final Uri endpoint = Uri.parse('https://freeimage.host/api/1/upload');
  static const String publicKey = '6d207e02198a847aa98d0a2a901485a5';
  static const int maxBytes = 64 * 1024 * 1024;

  final Dio _dio;

  @override
  Future<Uri> upload(UploadImage image, {void Function(double progress)? onProgress, UploadCancel? cancel}) async {
    final Uint8List bytes;
    try {
      final size = image.length?.call();
      if (size != null && size > maxBytes) throw const ImageUploadFailed(ImageUploadError.tooLarge);
      bytes = await image.read();
    } on ImageUploadFailed {
      rethrow;
    } catch (e) {
      throw ImageUploadFailed(ImageUploadError.unreadable, '$e');
    }
    if (bytes.length > maxBytes) throw const ImageUploadFailed(ImageUploadError.tooLarge);
    if (bytes.isEmpty) throw const ImageUploadFailed(ImageUploadError.unreadable, 'empty file');

    final form = FormData.fromMap({
      'key': publicKey,
      'action': 'upload',
      'format': 'json',
      'source': MultipartFile.fromBytes(bytes, filename: CatboxUploader._safeName(image.name)),
    });
    try {
      final response = await _dio.postUri<String>(
        endpoint,
        data: form,
        cancelToken: cancel?._token,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'User-Agent': 'MyWatchList'},
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
          validateStatus: (_) => true,
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) onProgress((sent / total).clamp(0.0, 1.0));
        },
      );
      if (response.statusCode == 413) throw const ImageUploadFailed(ImageUploadError.tooLarge);
      dynamic data;
      try {
        data = jsonDecode(response.data ?? '');
      } catch (_) {
        data = null;
      }
      final url = data is Map ? (data['image'] is Map ? data['image']['url'] : null) : null;
      final uri = url is String ? Uri.tryParse(url) : null;
      if ((response.statusCode ?? 0) ~/ 100 != 2 || uri == null || uri.scheme != 'https') {
        throw ImageUploadFailed(ImageUploadError.refused, '${response.statusCode}');
      }
      return uri;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) throw const ImageUploadCancelled();
      throw ImageUploadFailed(ImageUploadError.offline, e.type.name);
    }
  }
}
