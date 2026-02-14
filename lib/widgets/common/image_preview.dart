import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/utils/file_service.dart';
import 'package:mywatchlist/utils/streamutils.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

void zoomInImage(BuildContext context, String url, [bool showButtons = true]) {
  showDialog(
      context: context,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Stack(
              children: [
                PhotoView(
                  imageProvider: Image.network(url).image,
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
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
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
            if (showButtons) ...[
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => shareImage(url),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.save_alt),
                onPressed: () => saveImage(url),
              ),
              const SizedBox(width: 10),
              IconButton(
                  icon: const Icon(Icons.open_in_new), onPressed: () => {}
                  // launchURLWithConfirmation(url, context: context), //will be back soon
                  ),
              const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    ],
  );
}

Future<void> saveImageBytes(Uint8List bytes) async {
  try {
    var path = await FileStorage.getExternalDocumentPath();
    var fileName = '${Random().nextInt(10000000)}.jpg';
    var newPath = '$path/$fileName';
    File file = File(newPath);
    await file.writeAsBytes(bytes);
    // showToast('Image saved to $newPath');
  } catch (e) {
    // showToast('Error saving image');
  }
}

void saveImage(String url) async {
  var path = await downloadImage(url);
  File file = File(path);
  var fileName = _getFileName(path);
  var newPath = '${await FileStorage.getExternalDocumentPath()}/$fileName';
  file.copy(newPath);
  // showToast('Image saved to $newPath');
}

/// download image from url and share it
void shareImage(String url) async {
  var path = await downloadImage(url);
  XFile file = XFile(path);
  Share.shareXFiles([file], text: 'Image from MyWatchList');
}

Future<String> downloadImage(String url) async {
  var savePath = await getLocalImagePath(url);
  var response = await Dio().download(url, savePath);
  if (response.statusCode != 200) {
    // showToast('Error downloading file');
    throw Exception('Error downloading file');
  }
  return savePath;
}

Future<String> getLocalImagePath(String url) async {
  var path = await _getPathToDownload();
  return '$path/${_getFileName(url)}';
}

String _getFileName(String url) {
  var fileName = url.split('/').last;
  String? extension;
  if (fileName.contains('.')) {
    extension = fileName.split('.').last;
  }
  if (extension == null) {
    return '${Random().nextInt(10000000)}.jpg';
  } else {
    return fileName;
  }
}

Future<String?> _getPathToDownload() async {
  if (Platform.isAndroid) {
    final externalStorageFolder = await getExternalStorageDirectory();
    if (externalStorageFolder != null) {
      return p.join(externalStorageFolder.path, "Downloads");
    }
  } else {
    final downloadFolder = await getDownloadsDirectory();
    if (downloadFolder != null) {
      return downloadFolder.path;
    }
  }
  return null;
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
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Stack(
                children: [
                  PhotoViewGallery.builder(
                    pageController: pageController,
                    scrollPhysics: const BouncingScrollPhysics(),
                    builder: (BuildContext context, int i) {
                      var url = urlList[i];
                      return PhotoViewGalleryPageOptions(
                        imageProvider: Image.network(url).image,
                        initialScale: PhotoViewComputedScale.contained * 0.8,
                      );
                    },
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
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
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}
