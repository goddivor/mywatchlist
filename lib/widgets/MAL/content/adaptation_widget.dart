import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';

class AdaptationsWidget extends StatelessWidget {
  final List<AdaptNode> nodes;
  const AdaptationsWidget({super.key, required this.nodes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 105,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17.0),
        itemBuilder: (context, index) => Card(
          child: InkWell(
            onTap: () => {}, //le url du link animeTitle sera utiliser ici
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 160,
              child: Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Opacity(
                        opacity: .5,
                        child: CachedNetworkImage(
                          fit: BoxFit.cover,
                          imageUrl: nodes[index].image,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          Expanded(
                          child: Text(
                            nodes[index].animeTitle.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              overflow: TextOverflow.fade,
                              fontWeight: FontWeight.bold,
                              ),
                            textAlign: TextAlign.center,
                          ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                          formatText(nodes[index].relation),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        itemCount: nodes.length,
      ),
    );
  }
}
