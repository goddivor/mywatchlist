import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';

class AnimeCardBar extends StatelessWidget {
  final NodeStatusValue? nsv;
  final double smallHeight;
  final double smallWidth;
  final double radius;
  final Anime? node;
  final bool showMemberCount;
  final bool showNsv;
  final VoidCallback? onTap;
  final bool showEdit;
  final bool showSelfScoreInsteadOfStatus;
  final MyListStatus? myListStatus;

  const AnimeCardBar({
    super.key,
    this.nsv,
    this.radius = 6,
    this.smallHeight = 30,
    this.smallWidth = 30,
    this.onTap,
    this.showMemberCount = true,
    this.showNsv = true,
    this.showEdit = true,
    this.node,
    this.showSelfScoreInsteadOfStatus = false,
    this.myListStatus,
  });

  @override
  Widget build(BuildContext context) {
    final editWidget = Icon(
      Icons.edit,
      color: nsv?.color == null ? Colors.black : Colors.white,
      size: 16,
    );

    final badgeWidget = Center(
      child: Text(
        nsv?.status ?? "",
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );

    const memberCountStyle = TextStyle(
      overflow: TextOverflow.ellipsis,
      fontSize: 13,
    );

    final badgeStatusWidget = Container(
      decoration: BoxDecoration(
          color: nsv?.color ?? Colors.white,
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(radius),
          )),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(width: 5),
          if (showSelfScoreInsteadOfStatus)
            starField(
              '${(myListStatus as dynamic)?.score?.toString() ?? '0'} · ',
              starHeight: 10,
              textStyle: memberCountStyle,
            ),
          badgeWidget,
          const SizedBox(width: 5),
          editWidget,
          const SizedBox(width: 5),
        ],
      ),
    );

    starMemberWidget(detailed) => Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SB.w10,
            SizedBox(
              height: 14,
              child: Image.asset("assets/images/star.png"),
            ),
            const SizedBox(width: 5),
            title(
                (detailed.score == null || detailed.score == 0
                    ? '-'
                    : ratingFormat.format(detailed.score)),
                fontSize: 14,
                opacity: 1),
            const SizedBox(width: 5),
            if (showMemberCount && detailed.members != null && detailed.members != 0)
              Expanded(
                child: title(
                  '(${userCountFormat.format(detailed.members)})',
                  textOverflow: TextOverflow.ellipsis,
                  fontSize: 9,
                  opacity: .7,
                ),
              )
          ],
        );

    final borderRadius = BorderRadius.only(
      bottomRight: Radius.circular(radius),
      bottomLeft: Radius.circular(radius),
    );

    final materialWidget = Material(
      elevation: 5,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: starMemberWidget(node)),
            if (showNsv && showEdit) ...[
              const SizedBox(width: 5),
              badgeStatusWidget,
            ]
          ],
        ),
      ),
    );

    return SizedBox(
      width: smallWidth,
      height: smallHeight,
      child: materialWidget,
    );
  }
}

class StatusBadge extends StatelessWidget {
  final double height;
  final double width;
  final NodeStatusValue nsv;
  const StatusBadge(this.nsv,
      {this.height = 30.0, this.width = 40.0, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        height: height,
        width: width,
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
            color: nsv.color, borderRadius: BorderRadius.circular(16)),
        child: Center(
          child: title(nsv.status ?? "",
              opacity: 1, fontSize: 11, colorVal: Colors.white.toARGB32()),
        ));
  }
}
