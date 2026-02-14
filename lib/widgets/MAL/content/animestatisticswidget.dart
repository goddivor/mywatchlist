import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';

class AnimeStatisticsWidget extends StatefulWidget {
  final Statistics stats;
  const AnimeStatisticsWidget({required this.stats, super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AnimeStatisticsWidgetState createState() => _AnimeStatisticsWidgetState();
}

class _AnimeStatisticsWidgetState extends State<AnimeStatisticsWidget> {
  int? touchedIndex;

  /// watching, onHold, ptw, dropped, completed
  List<double> statList = [0.0, 0.0, 0.0, 0.0, 0.0];
  List<double> statListHeight = [0.0, 0.0, 0.0, 0.0, 0.0];
  List<String> statName = [
    'Watching',
    'CMPL',
    'On Hold',
    'Dropped',
    'PTW',
  ];
  NumberFormat statFormat = NumberFormat.compact();

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero).then((value) {
      statList[0] = _toDouble(widget.stats.status.watching);
      statList[1] = _toDouble(widget.stats.status.completed);
      statList[2] = _toDouble(widget.stats.status.onHold);
      statList[3] = _toDouble(widget.stats.status.dropped);
      statList[4] = _toDouble(widget.stats.status.planToWatch);

      double maxProp = statList.reduce(max);
      if (maxProp == 0) maxProp = 1;
      var multiplier = 100 / maxProp;
      for (var i = 0; i < statList.length; i++) {
        statListHeight[i] = statList[i] * multiplier;
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          height: 14,
          width: double.infinity,
        ),
        SizedBox(
          height: 260,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(5, (i) => _buildStatBar(i)),
          ),
        ),
        const SizedBox(
          height: 20,
        ),
        Text(
          "Total ${NumberFormat.currency(name: "", decimalDigits: 0).format(widget.stats.numListUsers)} Members",
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Column _buildStatBar(int i) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "${NumberFormat.currency(name: "").format(statList[i] * (100 / formatZeroAsOne(widget.stats.numListUsers)))}%",
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(
          height: 10,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: statListHeight[i] * 1.75,
            width: 20,
            decoration: BoxDecoration(
              color: Color(getStatusColorInt(i)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        Text(
          statName[i],
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(
          height: 10,
        ),
        Text(
          statFormat.format(statList[i]),
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        )
      ],
    );
  }

  int formatZeroAsOne(int? number) {
    if (number == null || number == 0 || number == double.infinity) return 1;
    return number;
  }
}
