// lib/widgets/show_forum.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_forum.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/widgets/shimmercolor.dart';
// import 'package:url_launcher/url_launcher.dart';

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
  final DateFormat dateFormat = DateFormat('dd MMM yyyy');

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

    return SizedBox(
      height: 270, // Reduced height
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: forumTopicsList.length,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemBuilder: (context, index) {
          final topic = forumTopicsList[index];
          return _buildForumCard(topic);
        },
      ),
    );
  }

  Widget _buildForumCard(AnimeForum topic) {
    return SizedBox(
      width: 280,
      child: Card(
        margin: const EdgeInsets.only(right: 10),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () async {
            if (topic.url != null && topic.url!.isNotEmpty) {
              // final Uri url = Uri.parse(topic.url!);
              // if (await canLaunchUrl(url)) {
              //   await launchUrl(url, mode: LaunchMode.externalApplication);
              // }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Topic title
                Text(
                  topic.title ?? 'Sans titre',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Author info
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        topic.authorUsername ?? 'Inconnu',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Date and comments info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Date
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(topic.date),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),

                    // Comments count
                    Row(
                      children: [
                        const Icon(Icons.comment_outlined, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '${topic.comments ?? 0}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),

                const Divider(height: 16),

                // Last comment section if available
                if (topic.lastComment != null)
                  Expanded(
                    child: _buildLastComment(topic.lastComment!),
                  )
                else
                  const Spacer(),

                // "View discussion" button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      if (topic.url != null && topic.url!.isNotEmpty) {
                        // final Uri url = Uri.parse(topic.url!);
                        // if (await canLaunchUrl(url)) {
                        //   await launchUrl(url, mode: LaunchMode.externalApplication);
                        // }
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Voir la discussion',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Date inconnue';

    try {
      final date = DateTime.parse(dateStr);
      return dateFormat.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildLastComment(LastComment lastComment) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Last comment author
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        lastComment.authorUsername ?? 'Inconnu',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Last comment date
              Text(
                _formatDate(lastComment.date),
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // "Last reply" indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Last reply',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 270,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 280,
            child: Card(
              margin: const EdgeInsets.only(right: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ShimmerColor(
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 32,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 150,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            height: 14,
                            width: 100,
                            color: Colors.white,
                          ),
                          Container(
                            height: 14,
                            width: 50,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Expanded(
                        child: Container(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          height: 14,
                          width: 100,
                          color: Colors.white,
                        ),
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
