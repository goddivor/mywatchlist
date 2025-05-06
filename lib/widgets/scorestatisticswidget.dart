import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_statistics.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/widgets/custumfuture.dart';

class ScoreStatisticsWidget extends StatefulWidget {
  final int id;
  final VoidCallback? onPageChange;
  final String category;
  final double horizPadding;
  const ScoreStatisticsWidget(
      {super.key,
      required this.id,
      required this.category,
      this.onPageChange,
      required this.horizPadding});

  @override
  // ignore: library_private_types_in_public_api
  _ScoreStatisticsWidgetState createState() => _ScoreStatisticsWidgetState();
}

class _ScoreStatisticsWidgetState extends State<ScoreStatisticsWidget>
    with AutomaticKeepAliveClientMixin {
  late dynamic animestatsFuture;
  List<double> statList = [];
  List<double> statListHeight = [];
  List<String> statName = [];
  NumberFormat statFormat = NumberFormat.compact();
  @override
  void initState() {
    super.initState();
    animestatsFuture = JikanApi.getAnimeStatistics(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CFutureBuilder<dynamic>(
      future: animestatsFuture,
      done: (s) => _scoreStatsWidget(s.data.scores),
      loadingChild: loadingGraph(context),
    );
  }

  Widget _scoreStatsWidget(List<ScoreStatistics?> scoreList) {
    // Si la liste est vide ou null, retourne un placeholder
    if (scoreList.isEmpty) return showNoContent();

    // Remplir les données en fonction de scoreList
    for (var scoreStat in scoreList) {
      if (scoreStat != null) {
        statName
            .add(scoreStat.score.toString()); // Utiliser 'score' pour le nom
        statList.add(scoreStat.votes?.toDouble() ??
            0.0); // Utiliser 'votes' pour la hauteur
      }
    }

    // Calculer la hauteur des barres
    double maxVotes =
        statList.isNotEmpty ? statList.reduce((a, b) => a > b ? a : b) : 1;
    var multiplier = 100 / (maxVotes > 0 ? maxVotes : 1);

    statListHeight = statList.map((votes) => votes * multiplier).toList();

    // Construction du widget graphique
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
          child: SingleChildScrollView(
            scrollDirection:
                Axis.horizontal, // Permettre le défilement horizontal
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                  statList.length, (i) => _buildStatBar(i, scoreList)),
            ),
          ),
        ),
        const SizedBox(
          height: 20,
        ),
        Text(
          "Total Votes: ${statFormat.format(statList.reduce((a, b) => a + b))}",
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Column _buildStatBar(int i, List<ScoreStatistics?> scoreList) {
    final scoreStat = scoreList[i];

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "${scoreStat?.percentage?.toStringAsFixed(1) ?? '0'}%", // Afficher le pourcentage
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(
          height: 10,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: statListHeight[i] * 1.75,
            width: 20,
            decoration: BoxDecoration(
              color: Color(getColorForScore(i)), // Choisir une couleur adaptée
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
          statName[i], // Afficher le score
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(
          height: 10,
        ),
        Text(
          statFormat.format(statList[i]), // Afficher le nombre de votes
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        )
      ],
    );
  }

  int getColorForScore(int score) {
    switch (score) {
      case 0:
        return Colors.red.value; // Score 0
      case 1:
        return Colors.redAccent.value; // Score 1
      case 2:
        return Colors.orange.value; // Score 2
      case 3:
        return Colors.orangeAccent.value; // Score 3
      case 4:
        return Colors.yellow.value; // Score 4
      case 5:
        return Colors.lightGreen.value; // Score 5
      case 6:
        return Colors.green.value; // Score 6
      case 7:
        return Colors.greenAccent.value; // Score 7
      case 8:
        return Colors.lightBlue.value; // Score 8
      case 9:
        return Colors.blue.value; // Score 9
      case 10:
        return Colors.blueAccent.value; // Score 10
      default:
        return Colors.grey.value; // Should not reach here
    }
  }

  @override
  void dispose() {
    animestatsFuture?.cancel();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}
