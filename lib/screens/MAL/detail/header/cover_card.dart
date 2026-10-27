import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show TitleLang, loadingError, loadingInner;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/header/title_lang_switch.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';

/// Cover (tap: zoomable gallery), title language switch and More Info button.
class DetailCoverCard extends StatelessWidget {
  static const double height = 300.0;

  final DetailData data;
  final TitleLang titleLang;
  final ValueChanged<TitleLang> onTitleLangChanged;

  /// Null while the details load: the button is then disabled, not dead.
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
    final radius = BorderRadius.circular(10);
    final card = SizedBox(
      height: height,
      child: Stack(
        children: [
          InkWell(
            onTap: () => zoomInImageList(context, urls),
            borderRadius: radius,
            child: AppImage(
              url: urls.first,
              height: height,
              placeholder: (context) => loadingInner(),
              errorWidget: (context) => loadingError(),
              imageBuilder: (context, imageProvider) => Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  image: DecorationImage(fit: BoxFit.cover, image: imageProvider),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 6,
            end: 6,
            child: TitleLangSwitch(value: titleLang, onChanged: onTitleLangChanged),
          ),
          PositionedDirectional(
            bottom: 6,
            end: 6,
            child: _MoreInfoButton(onPressed: onMoreInfo),
          ),
        ],
      ),
    );
    final heroTag = data.heroTag;
    return heroTag == null ? card : Hero(tag: heroTag, child: card);
  }
}

class _MoreInfoButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _MoreInfoButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: S.current.Dh_More_Info,
      child: Material(
        color: scheme.surface.withValues(alpha: onPressed == null ? .5 : .9),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.info_outline,
              size: 22,
              color: onPressed == null ? scheme.onSurface.withValues(alpha: .4) : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
