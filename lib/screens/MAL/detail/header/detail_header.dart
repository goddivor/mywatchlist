import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show TitleLang;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/header/cover_card.dart';
import 'package:mywatchlist/screens/MAL/detail/header/header_meta.dart';
import 'package:mywatchlist/widgets/common/auto_size_copy_text.dart';
import 'package:mywatchlist/widgets/common/background.dart';

/// Expanded part of the app bar: blurred cover background, title, cover card
/// and the meta column.
class DetailHeader extends StatelessWidget {
  final DetailData data;
  final String title;
  final TitleLang titleLang;
  final ValueChanged<TitleLang> onTitleLangChanged;
  final VoidCallback? onMoreInfo;

  const DetailHeader({
    super.key,
    required this.data,
    required this.title,
    required this.titleLang,
    required this.onTitleLangChanged,
    this.onMoreInfo,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 35),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: SizedBox(
            height: 40.0,
            width: double.infinity,
            child: Center(
              child: AutoSizeCopyText(
                title,
                style: const TextStyle(fontSize: 24),
                overflow: TextOverflow.fade,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(child: SizedBox()),
            Expanded(
              flex: 9,
              child: DetailCoverCard(
                data: data,
                titleLang: titleLang,
                onTitleLangChanged: onTitleLangChanged,
                onMoreInfo: onMoreInfo,
              ),
            ),
            const Expanded(child: SizedBox()),
            Expanded(flex: 7, child: DetailHeaderMeta(data: data)),
          ],
        ),
        const SizedBox(height: 15),
      ],
    );
    return Stack(children: [
      Background(
        context: context,
        forceBg: true,
        url: data.content?.mainPicture?.large,
      ),
      if (data.hasContent)
        Material(color: Colors.transparent, child: content)
      else
        content,
    ]);
  }
}
