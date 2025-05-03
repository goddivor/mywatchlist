import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/shimmercolor.dart';


Widget loadingCardList({
  double? containerHeight,
  double height = 150.0,
  double width = 100.0,
  Axis axis = Axis.horizontal,
  int itemCount = 6,
  EdgeInsetsGeometry listPadding = EdgeInsets.zero,
}) {
  return ShimmerColor(
    SizedBox(
      height: containerHeight,
      child: ListView.builder(
        scrollDirection: axis,
        itemCount: itemCount,
        padding: listPadding,
        itemBuilder: (context, index) => LoadingCard(
          height: height,
          width: width,
        ),
      ),
    ),
  );
}

class LoadingCard extends StatelessWidget {
  final double height;
  final double width;

  // ignore: use_super_parameters
  const LoadingCard({
    Key? key,
    this.height = 150.0,
    this.width = 100.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(  // Utilisation de Expanded ici
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          // Container(
          //   height: 20,
          //   width: width,
          //   color: Colors.grey[300],
          // ),
        ],
      ),
    );
  }
}
