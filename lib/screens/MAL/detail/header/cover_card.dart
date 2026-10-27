import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart'
    show TitleLang, loadingError, loadingInner;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/header/title_lang_switch.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';

/// Cover (tap: zoomable gallery), title language switch and More Info button.
class DetailCoverCard extends StatelessWidget {
  static const double height = 320.0;

  final DetailData data;
  final TitleLang titleLang;
  final ValueChanged<TitleLang> onTitleLangChanged;
  final VoidCallback? onMoreInfo;

  const DetailCoverCard({
    super.key,
    required this.data,
    required this.titleLang,
    required this.onTitleLangChanged,
    this.onMoreInfo,
  });

  @override
  Widget build(BuildContext context) {
    final urls = data.galleryUrls;
    final card = SizedBox(
      height: height,
      child: Stack(
        children: [
          InkWell(
            onTap: () => zoomInImageList(context, urls),
            borderRadius: BorderRadius.circular(6),
            child: AppImage(
              url: urls.first,
              height: height,
              placeholder: (context) => loadingInner(),
              errorWidget: (context) => loadingError(),
              imageBuilder: (context, imageProvider) => Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  image: DecorationImage(fit: BoxFit.cover, image: imageProvider),
                ),
              ),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: TitleLangSwitch(
              value: titleLang,
              onChanged: onTitleLangChanged,
            ),
          ),
          Positioned(bottom: 5, right: 5, child: _moreInfoButton(context)),
        ],
      ),
    );
    final heroTag = data.heroTag;
    return heroTag == null ? card : Hero(tag: heroTag, child: card);
  }

  Widget _moreInfoButton(BuildContext context) {
    return Tooltip(
      message: S.current.More_Info,
      child: SizedBox(
        width: 40,
        height: 40,
        child: ShadowButton(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          // No-op only while the details load (nothing to show yet).
          onPressed: onMoreInfo ?? () {},
          backgroundColor: Theme.of(context).cardColor,
          child: Icon(Icons.info, color: Theme.of(context).iconTheme.color),
        ),
      ),
    );
  }
}
