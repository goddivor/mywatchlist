import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/enums.dart' show ForumConstants;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/services/api/MAL/models/featured/featured_article.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/mal_scrapper.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/app_bar_menu.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/background.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:url_launcher/url_launcher.dart';

class FeaturedScreen extends StatefulWidget {
  final int id;
  final String? featureTitle;
  final String? imgUrl;
  final String category;

  const FeaturedScreen({
    super.key,
    required this.id,
    this.imgUrl,
    this.featureTitle,
    this.category = 'featured',
  });

  @override
  State<FeaturedScreen> createState() => _FeaturedScreenState();
}

class _FeaturedScreenState extends State<FeaturedScreen> {
  late Future<FeaturedArticle?> _articleFuture;

  @override
  void initState() {
    super.initState();
    _articleFuture = _fetchArticle();
  }

  Future<FeaturedArticle?> _fetchArticle() async {
    final result = await MalScraper().getFeaturedArticle(
      widget.id,
      widget.featureTitle,
      category: widget.category,
    );
    if (result != null) {
      return FeaturedArticle.fromJson(result);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FeaturedArticle?>(
      future: _articleFuture,
      builder: (context, snapshot) {
        final article = snapshot.data;
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting;

        if (snapshot.hasError && !isLoading) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.featureTitle ?? '')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  SB.h10,
                  Text(S.current.Fch_Article_Failed),
                  SB.h10,
                  FilledButton.tonal(
                    onPressed: () => setState(() => _articleFuture = _fetchArticle()),
                    child: Text(S.current.Fch_Retry),
                  ),
                ],
              ),
            ),
          );
        }

        final tabs = _generateTabs(article);

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  expandedHeight: 340,
                  flexibleSpace: isLoading
                      ? ShimmerColor(_headerPlaceholder())
                      : _headerWidget(article),
                  title: innerBoxIsScrolled
                      ? Text(widget.featureTitle ?? '')
                      : null,
                  actions: [
                    if (article != null)
                      AppBarMenu(
                        onShare: () => _share(article),
                        onOpenInBrowser: () => openLink(context, _pageUrl),
                      ),
                  ],
                  bottom: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: tabs.keys
                        .map((t) => Tab(text: t.standardize()))
                        .toList(),
                  ),
                ),
              ],
              body: isLoading
                  ? ShimmerColor(_bodyPlaceholder())
                  : TabBarView(children: tabs.values.toList()),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _headerWidget(FeaturedArticle? article) {
    final textTheme = Theme.of(context).textTheme;
    return FlexibleSpaceBar(
      background: Material(
        child: Stack(
          children: [
            Background(
              context: context,
              url: widget.imgUrl,
              forceBg: true,
            ),
            Padding(
              padding: const EdgeInsets.only(
                  top: 100.0, left: 15, right: 15, bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 80.0),
                    child: AutoSizeText(
                      article?.title ?? widget.featureTitle ?? '',
                      style: textTheme.titleLarge,
                      maxLines: 2,
                    ),
                  ),
                  SB.h30,
                  Text(
                    '${article?.postedBy ?? ""} \u00B7 ${article?.postedDate?.toLowerCase() ?? ""}',
                    style: textTheme.bodySmall,
                  ),
                  SB.h5,
                  Text(
                    '${article?.views ?? "0"} ${widget.category == "featured" ? S.current.Views : S.current.Comments}',
                    style: textTheme.bodySmall,
                  ),
                  SB.h15,
                  if (article != null && article.tags.isNotEmpty)
                    _tagsWidget(article.tags),
                  SB.h5,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerPlaceholder() {
    return FlexibleSpaceBar(
      background: Material(
        child: Stack(
          children: [
            Background(
              context: context,
              url: widget.imgUrl,
              forceBg: true,
            ),
            Padding(
              padding: const EdgeInsets.only(
                  top: 100.0, left: 15, right: 15, bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 250,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  SB.h30,
                  Container(
                    width: 180,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  SB.h10,
                  Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  SB.h15,
                  Row(
                    children: List.generate(
                      3,
                      (_) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Container(
                          width: 60,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bodyPlaceholder() {
    return Column(
      children: [
        SB.h20,
        ...List.generate(
          6,
          (_) => Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 15.0, vertical: 6.0),
            child: Container(
              width: double.infinity,
              height: 16,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tags
  // ---------------------------------------------------------------------------

  Widget _tagsWidget(List<String> tags) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: tags.length,
        separatorBuilder: (_, __) => SB.w5,
        itemBuilder: (context, index) {
          final tag = tags[index];
          final key = _searchKey(tag);
          return ActionChip(
            label: Text(tag, style: theme.textTheme.bodySmall),
            visualDensity: VisualDensity.compact,
            // A spoiler marker (or a tag the search does not know) is a label only.
            onPressed: key == null
                ? null
                : () => gotoPage(
                      context: context,
                      newPage: GeneralSearchScreen.byTag(
                        key,
                        news: widget.category == 'news',
                      ),
                    ),
          );
        },
      ),
    );
  }

  /// The search key of a tag shown on the page (matched ignoring case), or
  /// null when it cannot be searched: spoiler markers, and for featured
  /// articles tags outside the featured list (as DailyAL).
  String? _searchKey(String tag) {
    final lower = tag.trim().toLowerCase();
    if (lower.isEmpty || lower == 'spoiler') return null;
    for (final key in ForumConstants.tags.keys) {
      if (key.toLowerCase() == lower) return key == 'All' ? null : key;
    }
    if (widget.category == 'news') {
      for (final group in ForumConstants.newsTags.values) {
        for (final key in group.keys) {
          if (key.toLowerCase() == lower) return key == 'All' ? null : key;
        }
      }
      return tag.trim();
    }
    return null;
  }

  String get _pageUrl => 'https://myanimelist.net/'
      '${widget.category == 'news' ? 'news' : 'featured'}/${widget.id}';

  void _share(FeaturedArticle article) {
    final title = article.title ?? widget.featureTitle;
    showShareBuilder(
      context,
      subject: title,
      title: S.current.Fch_Share_Article,
      fields: [
        ShareField(label: S.current.Url, value: _pageUrl, labelled: false),
        if (title != null && title.isNotEmpty)
          ShareField(label: S.current.Title, value: title),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------------

  Map<String, Widget> _generateTabs(FeaturedArticle? article) {
    final Map<String, Widget> tabs = {};

    // General tab -- always present
    if (article == null) {
      tabs[S.current.general] = const SizedBox.shrink();
    } else {
      tabs[S.current.general] = _generalTab(article);
    }

    if (article == null) return tabs;

    // Related articles tab (only for featured category)
    if (widget.category == 'featured' && article.relatedArticles.isNotEmpty) {
      tabs[S.current.related_articles] =
          _relatedArticlesTab(article.relatedArticles);
    }

    // Dynamic tabs for related database entries (anime, manga, etc.)
    for (final entry in article.relatedDatabaseEntries.entries) {
      if (entry.value.isNotEmpty) {
        tabs[entry.key] = _relatedEntriesTab(entry.key, entry.value);
      }
    }

    // Comments tab (if has topicId)
    if (article.topicId != null) {
      tabs[S.current.Comments] = ForumPostsScreen(
        showAppbar: false,
        topic: ForumTopicsData(
          id: article.topicId,
          numberOfPosts: int.tryParse(article.views ?? ''),
        ),
      );
    }

    // Dynamic tabs for related news
    for (final entry in article.relatedNews.entries) {
      if (entry.value.isNotEmpty) {
        tabs[entry.key.replaceAll('More', '')] =
            _relatedArticlesTab(entry.value, category: 'news');
      }
    }

    return tabs;
  }

  // ---------------------------------------------------------------------------
  // General tab
  // ---------------------------------------------------------------------------

  Widget _generalTab(FeaturedArticle article) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(15.0),
      child: HtmlWidget(
        article.content ?? '',
        textStyle:
            TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
        onTapUrl: (url) async {
          final uri = Uri.tryParse(url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          return true;
        },
        customWidgetBuilder: (element) {
          // Spoiler handling
          if (element.localName == 'div' &&
              element.classes.contains('spoiler')) {
            final input = element.querySelector('input');
            final content = element.querySelector('.spoiler_content');
            if (content != null) {
              final label =
                  input?.attributes['value'] ?? S.current.Show_Spoiler;
              final innerHtml = content.innerHtml;
              return _SpoilerButton(label: label, innerHtml: innerHtml);
            }
          }
          // Image handling
          if (element.localName == 'img') {
            final src = element.attributes['src'];
            if (src != null && src.isNotEmpty) {
              return GestureDetector(
                onTap: () => zoomInImage(context, src),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AppImage(
                    url: src,
                    width: MediaQuery.sizeOf(context).width - 30,
                    fit: BoxFit.fitWidth,
                    errorWidget: (_) => const SizedBox.shrink(),
                  ),
                ),
              );
            }
          }
          return null;
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Related articles tab
  // ---------------------------------------------------------------------------

  Widget _relatedArticlesTab(List<RelatedArticle> articles,
      {String category = 'featured'}) {
    if (articles.isEmpty) {
      return showNoContent();
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 15),
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        return _relatedArticleTile(article, category: category);
      },
    );
  }

  Widget _relatedArticleTile(RelatedArticle article,
      {String category = 'featured'}) {
    return InkWell(
      onTap: article.id != null
          ? () => gotoPage(
                context: context,
                newPage: FeaturedScreen(
                  id: article.id!,
                  featureTitle: article.title,
                  imgUrl: article.imageUrl,
                  category: category,
                ),
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppImage(
                  url: article.imageUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholderColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  errorWidget: (_) => Container(
                    width: 80,
                    height: 80,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_not_supported, size: 24),
                  ),
                ),
              ),
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              SB.w10,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.title != null)
                    Text(
                      article.title!,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (article.summary != null &&
                      article.summary!.isNotEmpty) ...[
                    SB.h5,
                    Text(
                      article.summary!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (article.author != null &&
                      article.author!.isNotEmpty) ...[
                    SB.h5,
                    Text(
                      article.author!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Related database entries tab (anime, manga, etc.)
  // ---------------------------------------------------------------------------

  Widget _relatedEntriesTab(String category, List<RelatedEntry> entries) {
    if (entries.isEmpty) {
      return showNoContent();
    }
    final isTappable =
        category == 'anime' || category == 'manga';
    return ListView.builder(
      padding: const EdgeInsets.only(top: 15),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          title: Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isTappable
              ? const Icon(Icons.chevron_right, size: 20)
              : null,
          onTap: isTappable && entry.id != null
              ? () => gotoPage(
                    context: context,
                    newPage: ContentDetailedScreen(
                      node: null,
                      id: entry.id,
                      category: category,
                    ),
                  )
              : null,
        );
      },
    );
  }
}

/// Spoiler button that reveals content in a bottom sheet.
class _SpoilerButton extends StatelessWidget {
  final String label;
  final String innerHtml;

  const _SpoilerButton({required this.label, required this.innerHtml});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (ctx) => DraggableScrollableSheet(
                initialChildSize: 0.5,
                maxChildSize: 0.9,
                minChildSize: 0.3,
                expand: false,
                builder: (ctx, scrollController) => Material(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(15),
                    child: HtmlWidget(
                      '<div>$innerHtml</div>',
                      textStyle: TextStyle(
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          icon: const Icon(Icons.visibility, size: 16),
          label: Text(label),
        ),
      ),
    );
  }
}
