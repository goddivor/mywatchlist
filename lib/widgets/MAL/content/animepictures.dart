import 'package:flutter/material.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';

class AnimePictures extends StatelessWidget {
  final List<Picture> pictures;
  const AnimePictures({super.key, required this.pictures});

  @override
  Widget build(BuildContext context) {
    Widget avatarWidget(int index) {
      return AvatarWidget(
        width: 200,
        height: 100,
        onTap: () {
          zoomInImageList(
            context,
            pictures.map((e) => e.large).whereType<String>().toList(),
          );
        },
        url: pictures[index].large,
        // useUserImageOnError: false,
        radius: BorderRadius.circular(6),
        userRoundBorderforLoading: false,
      );
    }

    return SizedBox(
      height: 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pictures.length,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: avatarWidget(index),
        ),
      ),
    );
  }
}
