// lib/widgets/review/sort_dropdown.dart

import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/review/review_filters.dart';

class SortDropdown extends StatelessWidget {
  final ReviewSortType sortType;
  final ValueChanged<ReviewSortType?> onChanged;
  final Map<int, int>? scoreDistribution;
  
  const SortDropdown({
    super.key,
    required this.sortType,
    required this.onChanged,
    this.scoreDistribution,
  });
  
  @override
  Widget build(BuildContext context) {
    return DropdownButton<ReviewSortType>(
      value: sortType,
      onChanged: onChanged,
      underline: Container(
        height: 1,
        color: Theme.of(context).colorScheme.primary,
      ),
      items: [
        const DropdownMenuItem(
          value: ReviewSortType.dateDesc,
          child: Text('Date (Récent → Ancien)'),
        ),
        const DropdownMenuItem(
          value: ReviewSortType.dateAsc,
          child: Text('Date (Ancien → Récent)'),
        ),
        DropdownMenuItem(
          value: ReviewSortType.scoreDesc,
          child: Row(
            children: [
              const Text('Score (Haut → Bas)'),
              if (scoreDistribution != null && scoreDistribution!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.bar_chart, size: 16),
                  onPressed: () => _showScoreDistribution(context),
                  tooltip: 'Voir la distribution des scores',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        const DropdownMenuItem(
          value: ReviewSortType.scoreAsc,
          child: Text('Score (Bas → Haut)'),
        ),
      ],
    );
  }
  
  void _showScoreDistribution(BuildContext context) {
    if (scoreDistribution == null || scoreDistribution!.isEmpty) return;
    
    // Find max count for scaling
    final maxCount = scoreDistribution!.values.reduce((a, b) => a > b ? a : b);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Distribution des scores'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(11, (index) {
                    // Score ranges from 0 to 10
                    final count = scoreDistribution![index] ?? 0;
                    final barHeight = count > 0 
                        ? (count / maxCount * 200) 
                        : 0.0;
                    
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              count.toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: _getScoreColor(index),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              index.toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Score'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
  
  Color _getScoreColor(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 5) return Colors.amber;
    return Colors.red;
  }
}