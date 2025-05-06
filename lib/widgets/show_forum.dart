// lib/widgets/show_forum.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_forum.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/widgets/shimmercolor.dart';
import 'package:url_launcher/url_launcher.dart';

class ShowAnimeForum extends StatefulWidget {
  final int animeId;

  const ShowAnimeForum({super.key, required this.animeId});

  @override
  State<ShowAnimeForum> createState() => _ShowAnimeForumState();
}

class _ShowAnimeForumState extends State<ShowAnimeForum> {
  List<AnimeForum>? forumTopics;
  List<AnimeForum> forumTopicsList = [];
  bool isLoading = true;
  bool hasError = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchForumTopics();
  }

  Future<void> _fetchForumTopics() async {
    try {
      final response = await JikanApi().getAnimeForum(
        widget.animeId,
        AnimeForumFilter.all,
      );

      setState(() {
        forumTopics = response.data;
        forumTopicsList.addAll(forumTopics ?? []);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
      });
      debugPrint('Error fetching forum topics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (hasError) {
      return _buildErrorState();
    }

    if (forumTopicsList.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      height: 350,
      padding: const EdgeInsets.only(left: 15.0),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: forumTopicsList.length,
        itemBuilder: (context, index) {
          final topic = forumTopicsList[index];
          return SizedBox(
            width: 300,
            child: Card(
              margin: const EdgeInsets.only(right: 12.0),
              child: InkWell(
                onTap: () async {
                  if (topic.url != null && topic.url!.isNotEmpty) {
                    final Uri url = Uri.parse(topic.url!);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _titleWidget(topic),
                      const Divider(),
                      _infoWidget(topic),
                      const Spacer(),
                      _commentsWidget(topic),
                      if (topic.lastComment != null) 
                        _lastCommentWidget(topic.lastComment!),
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

  Widget _titleWidget(AnimeForum topic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          topic.title ?? 'Sans titre',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _infoWidget(AnimeForum topic) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final date = topic.date != null 
        ? DateTime.tryParse(topic.date!)
        : null;
    
    final formattedDate = date != null 
        ? dateFormat.format(date)
        : 'Date inconnue';

    return Row(
      children: [
        const Icon(Icons.person, size: 16),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            topic.authorUsername ?? 'Utilisateur inconnu',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.calendar_today, size: 16),
        const SizedBox(width: 4),
        Text(
          formattedDate,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _commentsWidget(AnimeForum topic) {
    return Row(
      children: [
        const Icon(Icons.comment, size: 16),
        const SizedBox(width: 4),
        Text(
          '${topic.comments ?? 0} commentaires',
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _lastCommentWidget(LastComment lastComment) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final date = lastComment.date != null 
        ? DateTime.tryParse(lastComment.date!)
        : null;
    
    final formattedDate = date != null 
        ? dateFormat.format(date)
        : 'Date inconnue';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dernier commentaire:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  lastComment.authorUsername ?? 'Utilisateur inconnu',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formattedDate,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 350,
      padding: const EdgeInsets.only(left: 15.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) {
          return SizedBox(
            width: 300,
            child: Card(
              margin: const EdgeInsets.only(right: 12.0),
              child: ShimmerColor(
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 50,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 20,
                        color: Colors.white,
                      ),
                      const Spacer(),
                      Container(
                        height: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 60,
                        color: Colors.white,
                      ),
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

  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun sujet de forum disponible',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur lors du chargement des sujets du forum',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  hasError = false;
                });
                _fetchForumTopics();
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}