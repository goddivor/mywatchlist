import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mywatchlist/widgets/avatar_widget.dart';
import 'package:mywatchlist/widgets/image_preview.dart';
import 'package:mywatchlist/widgets/shimmercolor.dart';


class HomePageNewsWidget extends StatelessWidget {
  final List<Map<String, String>> featuredList;
  const HomePageNewsWidget(this.featuredList, {super.key});

  @override
  Widget build(BuildContext context) {
    const radius = 12.0;
    return SizedBox(
      height: 250,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 12, right: 15),
        itemCount: featuredList.length,
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final node = featuredList[index];
          return SizedBox(
            width: 320,
            child: ShimmerConditionally(
              // ignore: unnecessary_null_comparison
              showShimmer: node == null,
              child: Card(
                child: InkWell(
                  onTap: () {
                    // doit renvoyer vers la page d'affichage des donné du news
                    // todo later
                  },
                  // onLongPress: node['imageUrl'] == null ? null : () => zoomInImage(context, node['imageUrl']!),
                  borderRadius: BorderRadius.circular(radius),
                  child: Stack(
                    children: [
                      if (node['imageUrl']!.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(radius),
                            child: Opacity(
                              opacity: .1,
                              child: CachedNetworkImage(
                                imageUrl: node['imageUrl']!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      _buildNewsTile(context, node, radius),
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

  Row _buildNewsTile(
      BuildContext context, Map<String, String> node, double radius) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (node['imageUrl']!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            child: AvatarWidget(
              height: 220,
              width: 120,
              url: node['imageUrl']!,
              onTap: () => zoomInImage(context, node['imageUrl']!),
              radius: BorderRadius.circular(radius),
              userRoundBorderforLoading: false,
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node['title']!,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 5,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    node['text']!,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.fade,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  node['tags']!,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
