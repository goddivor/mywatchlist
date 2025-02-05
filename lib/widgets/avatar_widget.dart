import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap as void Function()?,
      onLongPress: onLongPress != null
          ? onLongPress as void Function()?
          : (url != null
              ? () => zoomInImage(context, url!, isNetworkImage)
              : null),
      child: ClipRRect(
        borderRadius: radius ?? BorderRadius.circular(50),
        child: Container(
          height: height,
          width: width,
          color: Colors.transparent,
          child: url != null && isNetworkImage
              ? CachedNetworkImage(
                  imageUrl: url!,
                  imageBuilder: (context, imageProvider) => Ink(
                    decoration: BoxDecoration(
                        borderRadius: radius ?? BorderRadius.circular(50),
                        image: DecorationImage(fit: fit, image: imageProvider)),
                  ),
                  placeholder: (context, url) => cardLoading(
                      borderRadius: userRoundBorderforLoading!
                          ? BorderRadius.circular(32)
                          : radius),
                  errorWidget: (context, url, error) {
                    return Ink(
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
    placeholder: (context, url) => cardLoading(
        borderRadius:
            userRoundBorderforLoading ? BorderRadius.circular(32) : radius),
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
