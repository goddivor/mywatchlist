import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/MAL/interest_stack_detail_screen.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';

class InterestStackContentList extends StatelessWidget {
  final DisplayType type;
  final double horizPadding;
  final List<InterestStack> interestStacks;
  static BorderRadius radius = BorderRadius.circular(12.0);
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  const InterestStackContentList({
    super.key,
    required this.horizPadding,
    required this.interestStacks,
    this.shrinkWrap = false,
    this.padding,
    this.type = DisplayType.list_horiz,
  });

  bool get isHoriz => type == DisplayType.list_horiz;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isHoriz ? 240 : null,
      child: ListView.builder(
        scrollDirection: isHoriz ? Axis.horizontal : Axis.vertical,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        padding: padding ??
            (isHoriz
                ? EdgeInsets.symmetric(horizontal: horizPadding + 15.0)
                : const EdgeInsets.symmetric(vertical: 20, horizontal: 5)),
        itemCount: interestStacks.length,
        itemBuilder: (context, index) {
          final item = interestStacks.tryAt(index);
          final imageList =
              List<String>.from((item!.imageUrls ?? <String>[]).reversed);
          return Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 5, vertical: isHoriz ? 0 : 10),
            child: SizedBox(
              width: isHoriz ? 310 : null,
              child: Material(
                borderRadius: radius,
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => gotoPage(
                    context: context,
                    newPage: InterestStackDetailScreen(stack: item),
                  ),
                  borderRadius: radius,
                  splashColor: Theme.of(context).splashColor,
                  child: Row(
                    crossAxisAlignment: isHoriz
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: isHoriz ? 170 : 130,
                        height: isHoriz ? null : 230,
                        child: _buildStackPicttures(context, imageList,
                            radius: radius),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isHoriz) const SizedBox(height: 10),
                            Text(
                              item.title?.standardize() ?? '',
                              maxLines: 5,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontSize: 16,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            ),
                            _usernameWidget(context, item.username),
                            const SizedBox(height: 15),
                            title(
                                '${item.entries ?? 0} ${Intl.message(
                                  'entries',
                                  name: 'Entries',
                                  desc: '',
                                  args: [],
                                )}',
                                fontSize: 11,
                                textOverflow: TextOverflow.fade,
                                textStyle:
                                    Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 5),
                            title(
                                '${item.reStacks ?? 0} ${Intl.message(
                                  'restacks',
                                  name: 'Restacks',
                                  desc: '',
                                  args: [],
                                )}',
                                fontSize: 11,
                                textOverflow: TextOverflow.fade,
                                textStyle:
                                    Theme.of(context).textTheme.bodyMedium),
                            if (!isHoriz &&
                                item.updatedAt != null &&
                                item.updatedAt!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              title(item.updatedAt, fontSize: 11),
                            ],
                            if (!isHoriz &&
                                item.description != null &&
                                item.description!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 240.0),
                                child: title(
                                  item.description,
                                  textOverflow: TextOverflow.fade,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _buildStackPicttures(BuildContext context, List<String> imageList,
    {BorderRadius? radius}) {
  if (nullOrEmpty(imageList)) {
    return cachedImage(radius ?? BorderRadius.circular(6.0), 'url',
        useUserImageOnError: false);
  }
  return Stack(
    children: imageList.asMap().entries.map((e) {
      return Positioned(
        right: e.key * 20.0,
        top: e.key * 10.0 + 10.0,
        bottom: e.key * 10.0 + 10.0,
        child: InkWell(
          onTap: () => zoomInImageList(context, imageList.reversed.toList()),
          child: Container(
            decoration:
                const BoxDecoration(boxShadow: [BoxShadow(blurRadius: 10.0)]),
            child: CachedNetworkImage(
              fit: BoxFit.cover,
              imageUrl: e.value,
            ),
          ),
        ),
      );
    }).toList(),
  );
}

Widget _usernameWidget(
  BuildContext context,
  String? username, [
  bool adBy = true,
  EdgeInsetsGeometry? padding,
]) {
  final String usernameText = adBy ? 'by ${username ?? "?"}' : (username ?? '');

  if (username != null) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(top: 15),
      child: conditional(
        on: !invalidUserNames.contains(username),
        child: title(usernameText,
            textOverflow: TextOverflow.fade,
            textStyle: Theme.of(context).textTheme.bodyMedium),
        parent: (ch) => ToolTipButton(
          message: usernameText,
          onTap: () => {},
          child: ch,
        ),
      ),
    );
  } else {
    return const SizedBox();
  }
}
