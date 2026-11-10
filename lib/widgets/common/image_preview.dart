import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/user_preference.dart';
import 'package:mywatchlist/utils/file_service.dart';
import 'package:mywatchlist/utils/streamutils.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Static scrim behind the image viewer. A BackdropFilter blur here re-blurred the whole screen
/// on every frame of a pinch or a swipe; a flat dark layer costs nothing (docs/PERFORMANCE.md).
Color _viewerScrim(BuildContext context) =>
    Theme.of(context).colorScheme.scrim.withValues(alpha: 0.7);

/// Provider for the viewer: cached on disk, decoded no larger than twice the screen (enough
/// detail to zoom, never a 4000 px banner decoded at full size).
ImageProvider _viewerImage(BuildContext context, String url) {
  // Avatars with a bundled picture open the viewer too.
  if (!url.startsWith('http')) return AssetImage(url);
  final media = MediaQuery.of(context);
  return AppImage.provider(
    url,
    logicalWidth: media.size.width * 2,
    logicalHeight: media.size.height * 2,
    devicePixelRatio: media.devicePixelRatio,
    fit: BoxFit.contain,
  );
}

void zoomInImage(BuildContext context, String url, [bool showButtons = true]) {
  showDialog(
      context: context,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: ColoredBox(
            color: _viewerScrim(context),
            child: Stack(
              children: [
                PhotoView(
                  imageProvider: _viewerImage(context, url),
                  backgroundDecoration: const BoxDecoration(),
                  loadingBuilder: (context, event) => _imageLoader(event),
                ),
                Positioned(
                  bottom: 30.0,
                  left: 0.0,
                  right: 0.0,
                  child: imageButtons(url, context, showButtons),
                ),
              ],
            ),
          ),
        );
      });
}

Widget imageButtons(String url, BuildContext context,
    [bool showButtons = true]) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Card(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 10),
            IconButton(
              tooltip: S.current.Close,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
            if (showButtons) ...[
              IconButton(
                tooltip: S.current.Share,
                icon: const Icon(Icons.share),
                onPressed: () => shareImage(url),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: S.current.Save,
                icon: const Icon(Icons.save_alt),
                onPressed: () => saveImage(url),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: S.current.Open_In_Browser,
                icon: const Icon(Icons.open_in_new),
                onPressed: () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    ],
  );
}

/// Returns the user's chosen save path, or falls back to the default.
Future<String> _getSavePath() async {
  final customPath = await UserPreference().getDownloadPath();
  if (customPath != null) {
    final dir = Directory(customPath);
    if (await dir.exists()) return customPath;
  }
  return FileStorage.getExternalDocumentPath();
}

Future<void> saveImageBytes(Uint8List bytes) async {
  try {
    var path = await _getSavePath();
    var fileName = '${Random().nextInt(10000000)}.jpg';
    var newPath = '$path/$fileName';
    File file = File(newPath);
    await file.writeAsBytes(bytes);
    showToast(S.current.Image_Saved);
  } catch (e) {
    showToast(S.current.Image_Save_Failed);
  }
}

void saveImage(String url) async {
  try {
    var path = await downloadImage(url);
    File file = File(path);
    var fileName = _getFileName(url);
    var destPath = '${await _getSavePath()}/$fileName';
    await file.copy(destPath);
    showToast(S.current.Image_Saved);
  } catch (e) {
    showToast(S.current.Image_Save_Failed);
  }
}

/// download image from url and share it
void shareImage(String url) async {
  try {
    var path = await downloadImage(url);
    XFile file = XFile(path);
    Share.shareXFiles([file], text: S.current.Image_Share_Text);
  } catch (e) {
    showToast(S.current.Image_Share_Failed);
  }
}

Future<String> downloadImage(String url) async {
  var savePath = await getLocalImagePath(url);
  // Ensure directory exists
  final dir = Directory(p.dirname(savePath));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  var response = await Dio().download(url, savePath);
  if (response.statusCode != 200) {
    throw Exception('Error downloading file');
  }
  return savePath;
}

Future<String> getLocalImagePath(String url) async {
  var path = await _getPathToDownload();
  return '$path/${_getFileName(url)}';
}

String _getFileName(String url) {
  // Remove query params
  var cleanUrl = url.split('?').first;
  var fileName = cleanUrl.split('/').last;
  String? extension;
  if (fileName.contains('.')) {
    extension = fileName.split('.').last;
  }
  if (extension == null || extension.length > 5) {
    return '${Random().nextInt(10000000)}.jpg';
  } else {
    return fileName;
  }
}

/// Returns the default download path (for display in settings).
Future<String> getDefaultDownloadPath() async {
  if (Platform.isAndroid) {
    final dir = await getExternalStorageDirectory();
    if (dir != null) {
      return p.join(dir.path, "Downloads");
    }
  } else {
    final dir = await getDownloadsDirectory();
    if (dir != null) return dir.path;
  }
  final tempDir = await getTemporaryDirectory();
  return tempDir.path;
}

Future<String> _getPathToDownload() async {
  Directory? dir;
  if (Platform.isAndroid) {
    dir = await getExternalStorageDirectory();
    if (dir != null) {
      final downloadDir = Directory(p.join(dir.path, "Downloads"));
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir.path;
    }
  } else {
    dir = await getDownloadsDirectory();
    if (dir != null) {
      return dir.path;
    }
  }
  // Fallback to temp directory
  final tempDir = await getTemporaryDirectory();
  return tempDir.path;
}

void zoomInImageList(BuildContext context, List<String> urlList,
    [int index = 0]) {
  PageController pageController = PageController(initialPage: index);
  final listener = StreamListener(index);
  pageController.addListener(() {
    listener.update(pageController.page?.toInt() ?? 0);
  });
  showDialog(
      context: context,
      builder: (context) {
        return SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: ColoredBox(
              color: _viewerScrim(context),
              child: Stack(
                children: [
                  PhotoViewGallery.builder(
                    pageController: pageController,
                    scrollPhysics: const BouncingScrollPhysics(),
                    builder: (BuildContext context, int i) {
                      var url = urlList[i];
                      return PhotoViewGalleryPageOptions(
                        imageProvider: _viewerImage(context, url),
                        initialScale: PhotoViewComputedScale.contained * 0.8,
                      );
                    },
                    backgroundDecoration: const BoxDecoration(),
                    itemCount: urlList.length,
                    loadingBuilder: (context, event) => _imageLoader(event),
                  ),
                  StreamBuilder<int>(
                      stream: listener.stream,
                      builder: (context, snapshot) {
                        var imageIndex = snapshot.data ?? 0;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _pageIndicator(imageIndex, urlList),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 40.0),
                              child: imageButtons(urlList[imageIndex], context),
                            ),
                          ],
                        );
                      }),
                ],
              ),
            ));
      });
}

Widget _pageIndicator(int imageIndex, List<String> urlList) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 25.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ShadowButton(
          onPressed: () {},
          child: Text('${imageIndex + 1} / ${urlList.length}'),
        ),
      ],
    ),
  );
}

Center _imageLoader(ImageChunkEvent? event) {
  return Center(
    child: Builder(
      builder: (context) => ShimmerColor(
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.of(context).shimmerBase,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}
