// ignore_for_file: unnecessary_null_comparison, no_leading_underscores_for_local_identifiers

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/animecardbar.dart';
import 'package:mywatchlist/widgets/custombutton.dart';
import 'package:mywatchlist/widgets/fadingeffect.dart';
import 'package:mywatchlist/widgets/image_preview.dart';


final NumberFormat userCountFormat = NumberFormat.compact();
final NumberFormat ratingFormat = NumberFormat.currency(name: "");

class AnimeGridCard extends StatelessWidget {
  final Anime node;
  final String category;
  final Function? onTap;
  final bool showText;
  final bool showEdit;
  final bool showGenres;
  final double height;
  final double width;
  final double smallHeight;
  final double smallWidth;
  final double? aspectRatio;
  final int? numRecommendations;
  final bool updateCache;
  final double borderRadius;
  final bool showTime;
  final bool showMemberCount;
  final bool showCardBar;
  final VoidCallback? onEdit;
  final NodeStatusValue? parentNsv;
  final double horizPadding;
  final VoidCallback? onClose;
  final bool showSelfScoreInsteadOfStatus;
  final Widget? additionalWidget;
  final DisplaySubType? displaySubType;
  final double? gridHeight;

  const AnimeGridCard({
    super.key,
    required this.node,
    this.category = "anime",
    this.onTap,
    this.numRecommendations,
    this.showText = true,
    this.showEdit = false,
    this.updateCache = false,
    this.height = 200,
    this.width = 140,
    this.showGenres = false,
    this.showTime = false,
    this.borderRadius = 6,
    this.showCardBar = false,
    this.aspectRatio,
    this.smallHeight = 30,
    this.smallWidth = 30,
    this.showMemberCount = true,
    this.onEdit,
    this.parentNsv,
    this.horizPadding = 5.0,
    this.onClose,
    this.showSelfScoreInsteadOfStatus = false,
    this.additionalWidget,
    this.displaySubType,
    this.gridHeight,
  });

  @override
  Widget build(BuildContext context) {
    String nodeTitle = node.title;
    String? time;
    if (showTime && node.startDate != null) {
      time = node.startDate;
    }

    if (_compact || _coverOnly) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0, left: 6.0, right: 6.0),
        child: _buildImage(context, nodeTitle, null),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizPadding),
      child: SizedBox(
        height: gridHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (gridHeight != null)
              Expanded(child: _buildImage(context, nodeTitle, time)),
            if (isEditable) _comfortableEdit(context),
            if (showText) _textWidget(nodeTitle),
            if (showGenres) genreWidget(context),
            if (gridHeight != null) const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, String nodeTitle, String? time) {
    if (aspectRatio != null) {
      return AspectRatio(
        aspectRatio: aspectRatio!,
        child: cardWidget(context, nodeTitle,
            borderRadius: borderRadius, time: time),
      );
    } else {
      return SizedBox(
        height: gridHeight ?? height,
        width: width,
        child: cardWidget(context, nodeTitle,
            borderRadius: borderRadius, time: time),
      );
    }
  }

  Widget _textWidget(String nodeTitle) {
    return Container(
      width: width,
      padding: const EdgeInsets.only(top: 10),
      child: ToolTipButton(
        message: nodeTitle,
        padding: EdgeInsets.zero,
        child: _title(nodeTitle),
      ),
    );
  }

  Text _title(String nodeTitle) {
    return Text(
      nodeTitle,
      textAlign: TextAlign.left,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14),
    );
  }

  DisplaySubType get _displaySubType =>
      displaySubType ?? DisplaySubType.comfortable;

  bool get _compact => _displaySubType == DisplaySubType.compact;

  bool get _comfortable => _displaySubType == DisplaySubType.comfortable;

  bool get _coverOnly => _displaySubType == DisplaySubType.cover_only_grid;

  Widget _editAndText(
      BuildContext context, String nodeTitle, double borderRadius) {
    final value = parentNsv ?? NodeStatusValue.fromStatus(node);
    return Align(
      alignment: AlignmentDirectional.bottomCenter,
      child: Row(
        mainAxisSize: MainAxisSize.min, // Réduit la taille de l'axe principal
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 45.0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
                child: Text(
                  nodeTitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: Colors.white,
                      overflow: TextOverflow.fade,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        const Shadow(
                          color: Colors.black,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        )
                      ]),
                ),
              ),
            ),
          ),
          if (isEditable)
            editIconButton(
                value, () => _onEdit(context), borderRadius, node.myListStatus),
        ],
      ),
    );
  }

  void _onEdit(BuildContext context) {
    if (onEdit != null) {
      onEdit!();
    } else {
      showContentEditSheet(
        context,
        category,
        node,
        updateCache: updateCache,
      );
    }
  }

  AnimeCardBar _comfortableEdit(BuildContext context) {
    return AnimeCardBar(
      radius: borderRadius,
      nsv: parentNsv ?? NodeStatusValue.fromStatus(node),
      node: node,
      showEdit: showEdit,
      smallHeight: smallHeight,
      smallWidth: width,
      showMemberCount: showMemberCount,
      showSelfScoreInsteadOfStatus: showSelfScoreInsteadOfStatus,
      myListStatus: node.myListStatus,
      onTap: () => _onEdit(context),
    );
  }

  Widget genreWidget(BuildContext context) {
    // final content = node;
    final genres = [
      'Action',
      'Adventure',
      'Fantasy'
    ]; // Replace with actual genres
    final genreString = genres.join(", ");
    final int length = genres.length;

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: ToolTipButton(
          message: genreString,
          padding: EdgeInsets.zero,
          child: Text(
            genres.getRange(0, min(3, length)).join(", "),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9),
          ),
        ),
      ),
    );
  }

  Widget animePicture(BuildContext context, [double borderRadius = 6.0]) {
    String? url = node.imageUrl;
    return InkWell(
      onTap: () {
        if (onTap != null) onTap!();
      },
      onLongPress: url == null ? null : () => zoomInImage(context, url),
      customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius)),
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              placeholder: (context, url) {
                return cardLoading(
                    radius: borderRadius,
                    height: gridHeight ?? height,
                    width: width);
                // return const CircularProgressIndicator();
              },
              errorWidget: (context, url, error) => loadingError(),
              imageBuilder: (context, imageProvider) =>
                  loadedImage(imageProvider),
            )
          // ignore: avoid_unnecessary_containers
          : Container(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: Image.asset("assets/images/error_image.png"),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "No Image",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget cardWidget(BuildContext context, String nodeTitle,
      {double borderRadius = 6.0, String? time}) {
    return Material(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit
            .expand, // S'assure que les enfants s'adaptent correctement à l'espace disponible
        children: [
          aspectRatio != null
              ? AspectRatio(
                  aspectRatio: aspectRatio!,
                  child: animePicture(context, borderRadius))
              : animePicture(context, borderRadius),
          if (_compact) ...[
            _blackBGforText(borderRadius),
            _editAndText(context, nodeTitle, borderRadius),
            _episodeWatchProgressBar(node.myListStatus),
            _memberCountMeanScore(time),
          ],
          if (time != null) _timeCard(time),
          if (numRecommendations != null) _recomWidget(context, borderRadius),
          if (additionalWidget != null && !_coverOnly) additionalWidget!,
        ],
      ),
    );
  }

  Positioned _blackBGforText(double borderRadius) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 20,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: CustomPaint(
              foregroundPainter: FadingEffect(
                color: Colors.black,
                start: 5,
                end: 255,
                extend: 10,
              ),
              child: const SizedBox.shrink()),
        ),
      ),
    );
  }

  Widget _memberCountMeanScore(String? time) {
    if (showMemberCount) {
      // ignore: unnecessary_nullable_for_final_variable_declarations
      final int? memberCount = node.members;
      // ignore: unnecessary_nullable_for_final_variable_declarations
      final double? meanScore = node.score;
      if (memberCount == null && meanScore == null) {
        return const SizedBox.shrink();
      }
      return Positioned(
        top: time != null ? 22 : 7,
        left: 5,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Center(
              child: Text(
                "${meanScore == null || meanScore == 0 ? '' : '${meanScore.toStringAsFixed(2)} | '}${memberCount == null ? '' : userCountFormat.format(memberCount)}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _episodeWatchProgressBar(MyListStatus? myListStatus) {
    double? watchProgress;
    double? releaseProgress;
    final episodes = node.numEpisodes;
    final watched = myListStatus?.numEpisodesWatched;

    if (episodes != null && episodes > 1) {
      releaseProgress = (episodes - 1) / episodes;
    }
    if (watched != null && episodes != null && episodes > 0) {
      watchProgress = watched / episodes;
    }

    if (watchProgress == null) return const SizedBox.shrink();

    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius * 2),
          child: Container(
            height: 2.5,
            width: width,
            color: Colors.grey[500],
            child: Stack(
              children: [
                if (releaseProgress != null)
                  LinearProgressIndicator(
                    value: releaseProgress,
                    backgroundColor: Colors.transparent,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                LinearProgressIndicator(
                  value: watchProgress,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Transform _recomWidget(BuildContext context, double borderRadius) {
    return Transform.translate(
      offset: const Offset(-3, -3),
      child: Container(
        width: smallWidth,
        height: smallHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(borderRadius),
            bottomRight: Radius.circular(borderRadius),
          ),
        ),
        child: Center(
          child: Text(
            numRecommendations.toString(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }

  bool get isEditable =>
      showCardBar && (category == 'anime' || category == 'manga');

  Widget loadedImage(ImageProvider<Object> imageProvider) {
    return Stack(
      children: [
        Ink(
          decoration: BoxDecoration(
            borderRadius: isEditable && _comfortable
                ? BorderRadius.only(
                    topRight: Radius.circular(borderRadius),
                    topLeft: Radius.circular(borderRadius),
                  )
                : BorderRadius.circular(borderRadius),
            image: DecorationImage(fit: BoxFit.cover, image: imageProvider),
          ),
        ),
        if (onClose != null)
          Positioned(
            right: 0,
            child: IconButton.filled(
                onPressed: onClose!, icon: const Icon(Icons.clear)),
          ),
      ],
    );
  }

  Widget _timeCard(String time) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 20,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(borderRadius),
            topRight: Radius.circular(borderRadius),
          ),
        ),
        child: Center(
          child: AutoSizeText(
            time,
            textAlign: TextAlign.center,
            maxFontSize: 10.0,
            minFontSize: 7.0,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

Widget editIconButton(
  NodeStatusValue? value,
  VoidCallback onEdit,
  double borderRadius, [
  dynamic myListStatus,
  OutlinedBorder? shape,
]) {
  Widget child;
  final score = myListStatus?.score as int?;
  final hasScore = score != null && score > 0;
  final bgColor = value?.color ?? Colors.black;
  final textColor = getTextColor(bgColor);
  if (hasScore) {
    child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.star, size: 16, color: textColor),
        Text(
          score.toString(),
          style: TextStyle(color: textColor, fontSize: 12),
        ),
      ],
    );
  } else {
    child = Icon(
      Icons.edit,
      size: 16,
      color: textColor,
    );
  }
  return SizedBox(
    width: hasScore ? 40 : 30,
    height: 30,
    child: TextButton(
      style: TextButton.styleFrom(
        backgroundColor: bgColor,
        shape: shape ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(borderRadius * 2),
                bottomRight: Radius.circular(borderRadius),
              ),
            ),
        padding: EdgeInsets.zero,
      ),
      onPressed: onEdit,
      child: child,
    ),
  );
}

class NodeStatusValue {
  String? status;
  Color? color;
  int? index;

  NodeStatusValue({required status, color = Colors.transparent});

  NodeStatusValue.fromListStatus(MyListStatus myListStatus) {
    setDynStatus(myListStatus.status);
  }

  NodeStatusValue.fromStatus(Anime node) {
    // Vérifie si myListStatus est non nul avant d'accéder à son statut
    if (node.myListStatus != null) {
      setDynStatus(node.myListStatus!.status);
    } else {
      // Passe null à setDynStatus si myListStatus est null
      setDynStatus(null);
    }
  }

  NodeStatusValue.fromString(String _status) {
    setDynStatus(_status);
  }

  void setDynStatus(String? dynStatus) {
    if (dynStatus != null) {
      String lowStatus = dynStatus.toLowerCase();
      if (lowStatus == "watching" || lowStatus == "reading") {
        status = (lowStatus == "watching") ? "CW" : "CR";
        index = 0;
      } else if (lowStatus == "completed") {
        status = "CMP";
        index = 1;
      } else if (lowStatus == "on_hold") {
        status = "OH";
        index = 2;
      } else if (lowStatus == "dropped") {
        status = "DP";
        index = 3;
      } else if (lowStatus == "plan_to_watch" || lowStatus == "plan_to_read") {
        status = (lowStatus == "plan_to_watch") ? "PTW" : "PTR";
        index = 4;
      }
      if (index != null) {
        color = getStatusColor(index!);
      }
    }
  }
}


Color getTextColor(Color bgColor) {
  return bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

class PriorityBadge {
  String? status;
  Color? color;
}

void showContentEditSheet(BuildContext context, String category, Anime node,
    {bool updateCache = false}) {
  // Implement your content edit logic here
}