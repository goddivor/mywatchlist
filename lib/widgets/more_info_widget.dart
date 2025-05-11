import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';

class MoreInfoWidget extends StatelessWidget {
  final MalAnime? anime;
  final dynamic additionalTitles; // Use dynamic to allow for various types
  final double horizPadding;

  const MoreInfoWidget({
    Key? key,
    this.anime,
    this.additionalTitles,
    required this.horizPadding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (anime == null) return Container();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(context),
          const SizedBox(height: 30),
          _buildTitlesSection(context),
          const SizedBox(height: 30),
          _buildGenresAndThemesSection(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final infoItems = [
      InfoItem('Media Type', anime?.mediaType?.toUpperCase() ?? 'N/A'),
      InfoItem('Episodes', anime?.numEpisodes?.toString() ?? 'N/A'),
      InfoItem('Status', anime?.status ?? 'N/A'),
      InfoItem('MAL ID', anime?.id.toString() ?? 'N/A'),
      InfoItem('Premiered', _getPremiered(anime)),
      InfoItem('Aired', _getAiredPeriod(anime)),
      InfoItem('Source', anime?.source ?? 'N/A'),
      InfoItem('Broadcast', _getBroadcast(anime)),
      InfoItem('Duration', _getDuration(anime)),
      InfoItem('Rating', anime?.rating ?? 'N/A'),
      InfoItem('Studios', _getStudios(anime)),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            ...infoItems.map((item) => _buildInfoRow(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, InfoItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              item.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitlesSection(BuildContext context) {
    final synonyms = anime?.alternativeTitles?.synonyms ?? [];
    final titles = [
      if (anime?.title != null) ('Original', anime!.title),
      if (anime?.alternativeTitles?.en != null && anime!.alternativeTitles!.en.isNotEmpty) 
        ('English', anime!.alternativeTitles!.en),
      if (anime?.alternativeTitles?.ja != null && anime!.alternativeTitles!.ja.isNotEmpty) 
        ('Japanese', anime!.alternativeTitles!.ja),
      ...synonyms.map((s) => ('Synonym', s)),
      ..._getAdditionalTitles(),
    ];

    if (titles.isEmpty) return Container();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alternative Titles',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            ...titles.map((title) => _buildTitleRow(context, title.$1, title.$2)),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context, String type, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              type,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenresAndThemesSection(BuildContext context) {
    if (anime?.genres == null || anime!.genres!.isEmpty) return Container();
    
    return _buildTagsRow(context, 'Genres', anime!.genres!);
  }

  Widget _buildTagsRow(BuildContext context, String label, List<Genre> genres) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: genres.map((genre) => _buildGenreChip(context, genre)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreChip(BuildContext context, Genre genre) {
    return Chip(
      label: Text(
        genre.name,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      side: BorderSide(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
      ),
    );
  }

  String _getPremiered(MalAnime? anime) {
    if (anime?.startSeason == null) return 'N/A';
    return '${anime!.startSeason!.season.titleCase()} ${anime.startSeason!.year}';
  }

  String _getAiredPeriod(MalAnime? anime) {
    final start = anime?.startDate ?? '';
    final end = anime?.endDate ?? '';
    
    if (start.isEmpty && end.isEmpty) return 'N/A';
    if (end.isEmpty) return 'From $start';
    if (start.isEmpty) return 'To $end';
    return '$start to $end';
  }

  String _getBroadcast(MalAnime? anime) {
    if (anime?.broadcast == null) return 'N/A';
    final b = anime!.broadcast!;
    final day = b.dayOfTheWeek ?? '';
    final time = b.startTime ?? '';
    
    if (day.isEmpty && time.isEmpty) return 'N/A';
    if (time.isEmpty) return day;
    return '$day at $time';
  }

  String _getDuration(MalAnime? anime) {
    if (anime?.averageEpisodeDuration == null) return 'N/A';
    final minutes = anime!.averageEpisodeDuration!;
    if (minutes < 60) return '${minutes} min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return '${hours}h';
    return '${hours}h ${remainingMinutes}min';
  }

  String _getStudios(MalAnime? anime) {
    if (anime?.studios == null || anime!.studios!.isEmpty) return 'N/A';
    return anime.studios!.map((s) => s.name).join(', ');
  }

  List<(String, String)> _getAdditionalTitles() {
    if (additionalTitles == null) return [];
    if (additionalTitles is List) {
      try {
        final titles = additionalTitles as List<dynamic>;
        return titles.map<(String, String)>((t) {
          if (t is Map<String, dynamic>) {
            return (t['language'] ?? '', t['title'] ?? '');
          } else if (t.runtimeType.toString().contains('AdditionalTitle')) {
            // Dynamic access for AdditionalTitle objects
            return (t.language.toString(), t.title.toString());
          }
          return ('', '');
        }).where((tuple) => tuple.$1.isNotEmpty && tuple.$2.isNotEmpty).toList();
      } catch (e) {
        print('Error parsing additional titles: $e');
        return [];
      }
    }
    return [];
  }
}

class InfoItem {
  final String label;
  final String value;

  InfoItem(this.label, this.value);
}