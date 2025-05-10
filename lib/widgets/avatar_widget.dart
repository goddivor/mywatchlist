// import 'package:flutter/material.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:mywatchlist/constants/constants.dart';
// import 'package:mywatchlist/widgets/image_preview.dart';

// class AvatarWidget extends StatelessWidget {
//   final double? height, width;
//   final Function? onTap;
//   final BorderRadius? radius;
//   final String? url;
//   final bool isNetworkImage;
//   final String? username;
//   final BoxFit? fit;
//   final bool? userRoundBorderforLoading;
//   final Function? onLongPress;

//   const AvatarWidget({
//     super.key,
//     this.height = 35,
//     this.width = 35,
//     this.onTap,
//     this.url,
//     this.radius,
//     this.onLongPress,
//     this.userRoundBorderforLoading = true,
//     this.username,
//     this.isNetworkImage = true,
//     this.fit = BoxFit.cover,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap as void Function()?,
//       onLongPress: onLongPress != null
//           ? onLongPress as void Function()?
//           : (url != null
//               ? () => zoomInImage(context, url!, isNetworkImage)
//               : null),
//       child: ClipRRect(
//         borderRadius: radius ?? BorderRadius.circular(50),
//         child: Container(
//           height: height,
//           width: width,
//           color: Colors.transparent,
//           child: url != null && isNetworkImage
//               ? CachedNetworkImage(
//                   imageUrl: url!,
//                   imageBuilder: (context, imageProvider) => Ink(
//                     decoration: BoxDecoration(
//                         borderRadius: radius ?? BorderRadius.circular(50),
//                         image: DecorationImage(fit: fit, image: imageProvider)),
//                   ),
//                   placeholder: (context, url) => cardLoading(
//                       borderRadius: userRoundBorderforLoading!
//                           ? BorderRadius.circular(32)
//                           : radius),
//                   errorWidget: (context, url, error) {
//                     return Ink(
//                       decoration: BoxDecoration(
//                         borderRadius: radius ?? BorderRadius.circular(28),
//                         image: DecorationImage(
//                           fit: fit,
//                           image: const AssetImage(
//                             ("assets/images/user_dal_old.png"),
//                           ),
//                         ),
//                       ),
//                     );
//                   },
//                 )
//               : Image.asset(
//                   'assets/images/user_dal_old.png',
//                   fit: fit,
//                 ),
//         ),
//       ),
//     );
//   }
// }

// Widget cachedImage(
//   BorderRadius? radius,
//   String? url, {
//   useUserImageOnError = true,
//   BoxFit? fit = BoxFit.cover,
//   userRoundBorderforLoading = true,
// }) {
//   return CachedNetworkImage(
//     imageUrl: url ?? '',
//     placeholder: (context, url) => cardLoading(
//         borderRadius:
//             userRoundBorderforLoading ? BorderRadius.circular(32) : radius),
//     errorWidget: (context, url, error) {
//       return Ink(
//         decoration: BoxDecoration(
//           borderRadius: radius ?? BorderRadius.circular(28),
//           image: DecorationImage(
//             fit: fit,
//             image: AssetImage(
//               (useUserImageOnError
//                   ? "assets/images/user_dal_old.png"
//                   : "assets/images/anime-collage.jpg"),
//             ),
//           ),
//         ),
//       );
//     },
//     imageBuilder: (context, imageProvider) => Ink(
//       decoration: BoxDecoration(
//           borderRadius: radius ?? BorderRadius.circular(28),
//           image: DecorationImage(fit: fit, image: imageProvider)),
//     ),
//   );
// }

import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mywatchlist/cache/cachemanager.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/widgets/image_preview.dart';

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

    return GestureDetector(
      onTap: onTap as void Function()?,
      onLongPress: onLongPress != null
          ? onLongPress as void Function()?
          : (url != null
              ? () => zoomInImage(context, url!, isNetworkImage)
              : null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: effectiveBorderColor,
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: effectiveBorderColor.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius ?? BorderRadius.circular(50),
          child: Container(
            height: height,
            width: width,
            color: Colors.transparent,
            child: url != null && isNetworkImage
                ? CachedNetworkImage(
                    imageUrl: url!,
                    imageBuilder: (context, imageProvider) => Container(
                      decoration: BoxDecoration(
                          borderRadius: radius ?? BorderRadius.circular(50),
                          image:
                              DecorationImage(fit: fit, image: imageProvider)),
                    ),
                    placeholder: (context, url) =>
                        _buildShimmerLoader(context, radius),
                    errorWidget: (context, url, error) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: radius ?? BorderRadius.circular(28),
                          image: DecorationImage(
                            fit: fit,
                            image: const AssetImage(
                              ("assets/images/user_dal_old.png"),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : Image.asset(
                    'assets/images/user_dal_old.png',
                    fit: fit,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoader(BuildContext context, BorderRadius? radius) {
    return Container(
      decoration: BoxDecoration(
        borderRadius:
            userRoundBorderforLoading! ? BorderRadius.circular(32) : radius,
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      child: Center(
        child: SizedBox(
          width: (height ?? 35) * 0.5,
          height: (width ?? 35) * 0.5,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

Widget cachedImage(
  BorderRadius? radius,
  String? url, {
  useUserImageOnError = true,
  BoxFit? fit = BoxFit.cover,
  userRoundBorderforLoading = true,
}) {
  return CachedNetworkImage(
    imageUrl: url ?? '',
    placeholder: (context, url) =>
        _shimmerLoader(context, radius, userRoundBorderforLoading),
    errorWidget: (context, url, error) {
      return Ink(
        decoration: BoxDecoration(
          borderRadius: radius ?? BorderRadius.circular(28),
          image: DecorationImage(
            fit: fit,
            image: AssetImage(
              (useUserImageOnError
                  ? "assets/images/user_dal_old.png"
                  : "assets/images/anime-collage.jpg"),
            ),
          ),
        ),
      );
    },
    imageBuilder: (context, imageProvider) => Ink(
      decoration: BoxDecoration(
          borderRadius: radius ?? BorderRadius.circular(28),
          image: DecorationImage(fit: fit, image: imageProvider)),
    ),
  );
}

Widget _shimmerLoader(BuildContext context, BorderRadius? radius,
    bool userRoundBorderforLoading) {
  return Container(
    decoration: BoxDecoration(
      borderRadius:
          userRoundBorderforLoading ? BorderRadius.circular(32) : radius,
      color: Theme.of(context).colorScheme.surfaceVariant,
    ),
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
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
      decoration: BoxDecoration(
        color: randomColor(username),
        shape: BoxShape.circle,
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
