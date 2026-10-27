import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:mywatchlist/cache/cachemanager.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';

class AvatarWidget extends StatelessWidget {
  final double? height, width;
  final Function? onTap;
  final BorderRadius? radius;
  final String? url;
  final bool isNetworkImage;
  final String? username;
  final BoxFit? fit;
  final bool? userRoundBorderforLoading;
  final Function? onLongPress;
  final Color? borderColor;
  final double borderWidth;

  const AvatarWidget({
    super.key,
    this.height = 35,
    this.width = 35,
    this.onTap,
    this.url,
    this.radius,
    this.onLongPress,
    this.userRoundBorderforLoading = true,
    this.username,
    this.isNetworkImage = true,
    this.fit = BoxFit.cover,
    this.borderColor,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBorderColor = borderColor ?? theme.colorScheme.primary;

    final isCircular = userRoundBorderforLoading ?? true;

    final clipRadius = radius ?? BorderRadius.circular(50);

    final image = SizedBox(
      height: height,
      width: width,
      child: url != null && isNetworkImage
          ? AppImage(
              url: url,
              width: width,
              height: height,
              fit: fit ?? BoxFit.cover,
              borderRadius: clipRadius,
              placeholder: (context) => _buildShimmerLoader(context, radius),
              errorAsset: _userFallbackAsset,
            )
          : ClipRRect(
              borderRadius: clipRadius,
              child: Image.asset(
                url ?? _userFallbackAsset,
                fit: fit,
              ),
            ),
    );

    return GestureDetector(
      onTap: onTap as void Function()?,
      onLongPress: onLongPress != null
          ? onLongPress as void Function()?
          : (url != null
              ? () => zoomInImage(context, url!, isNetworkImage)
              : null),
      // A plain border: avatars repeat in lists, a blurred shadow on each one is re-rasterized
      // on every scrolled frame (docs/PERFORMANCE.md).
      child: isCircular
          ? DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: effectiveBorderColor,
                  width: borderWidth,
                ),
              ),
              child: image,
            )
          : image,
    );
  }

  Widget _buildShimmerLoader(BuildContext context, BorderRadius? radius) {
    return ShimmerColor(
      Container(
        decoration: BoxDecoration(
          borderRadius:
              userRoundBorderforLoading! ? BorderRadius.circular(32) : radius,
          color: Colors.white,
        ),
      ),
    );
  }
}

const String _userFallbackAsset = 'assets/images/user_dal_old.png';

/// Network image with an `Ink` decoration (so the enclosing InkWell ripple stays visible),
/// decoded at the slot's size and shown without fade (DailyAL: `fadeInDuration: Duration.zero`).
Widget cachedImage(
  BorderRadius? radius,
  String? url, {
  useUserImageOnError = true,
  BoxFit? fit = BoxFit.cover,
  userRoundBorderforLoading = true,
}) {
  final effectiveRadius = radius ?? BorderRadius.circular(28);
  final effectiveFit = fit ?? BoxFit.cover;
  return AppImage(
    url: url,
    fit: effectiveFit,
    placeholder: (context) =>
        _shimmerLoader(context, radius, userRoundBorderforLoading),
    errorWidget: (context) => Ink(
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        image: DecorationImage(
          fit: effectiveFit,
          image: AssetImage(
            (useUserImageOnError
                ? _userFallbackAsset
                : "assets/images/anime-collage.jpg"),
          ),
        ),
      ),
    ),
    imageBuilder: (context, imageProvider) => Ink(
      decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          image: DecorationImage(fit: effectiveFit, image: imageProvider)),
    ),
  );
}

Widget _shimmerLoader(BuildContext context, BorderRadius? radius,
    bool userRoundBorderforLoading) {
  return ShimmerColor(
    Container(
      decoration: BoxDecoration(
        borderRadius:
            userRoundBorderforLoading ? BorderRadius.circular(32) : radius,
        color: Colors.white,
      ),
    ),
  );
}

class AvatarAspect extends StatelessWidget {
  final double aspectRatio;
  final Function? onTap;
  final BorderRadius? radius;
  final String? url;
  final bool localFile;
  final bool isNetworkImage;
  final VoidCallback? onLongPress;
  final bool useUserImageOnError;
  final String? username;
  final bool userRoundBorderforLoading;

  AvatarAspect({
    this.onTap,
    this.url,
    this.aspectRatio = 1.0,
    this.radius,
    this.useUserImageOnError = true,
    this.username,
    this.localFile = false,
    this.onLongPress,
    this.isNetworkImage = true,
    this.userRoundBorderforLoading = false,
  });
  @override
  Widget build(BuildContext context) {
    if (username != null && url != null) {
      CacheManager.instance.setUserImage(username, url);
    }
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius ?? BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  onTap!();
                },
          onLongPress: onLongPress,
          customBorder: RoundedRectangleBorder(
              borderRadius: radius ?? BorderRadius.circular(28)),
          child: localFile
              ? Image.file(
                  File(url!),
                  fit: BoxFit.cover,
                )
              : (username != null && url == null)
                  ? FutureBuilder<String?>(
                      future: CacheManager.instance.getUserImage(username),
                      builder: (_, snapshot) {
                        if (snapshot.hasData) {
                          return cachedImage(radius, snapshot.data);
                        } else {
                          return url == null || !isNetworkImage
                              ? userImage(radius, url,
                                  useUserImageOnError: useUserImageOnError)
                              : cachedImage(radius, url,
                                  useUserImageOnError: useUserImageOnError);
                        }
                      })
                  : url == null || !isNetworkImage
                      ? userImage(radius, url,
                          useUserImageOnError: useUserImageOnError,
                          username: username)
                      : cachedImage(
                          radius,
                          url,
                          useUserImageOnError: useUserImageOnError,
                          userRoundBorderforLoading: userRoundBorderforLoading,
                        ),
        ),
      ),
    );
  }
}

Widget userImage(BorderRadius? radius, String? url,
    {useUserImageOnError = true, String? username}) {
  if (useUserImageOnError && username != null) {
    username = username.toLowerCase();
    username = username.substring(0, username.length > 2 ? 2 : 1);
    return Container(
      decoration: BoxDecoration(
        color: randomColor(username),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: AutoSizeText(
          username,
          maxLines: 1,
          minFontSize: 10,
          style: TextStyle(
            fontSize: 22,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
  return Container(
    child: Ink(
      decoration: BoxDecoration(
        borderRadius: radius ?? BorderRadius.circular(28),
        image: DecorationImage(
          fit: BoxFit.cover,
          image: AssetImage(
            url ??
                (useUserImageOnError
                    ? "assets/images/user-unknown.jpg"
                    : "assets/images/error_image.png"),
          ),
        ),
      ),
    ),
  );
}

Color randomColor(String username) {
  final cd = username.hashCode;
  return Color.fromARGB(255, cd % 150, cd % 125, cd % 100);
}
