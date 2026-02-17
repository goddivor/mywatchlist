// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_characterfull.dart'
    as chara;
import 'package:mywatchlist/services/api/Jikan/jikan_personfull.dart'
    as person;
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/MAL/search/headerwidget.dart';
import 'package:mywatchlist/widgets/common/background.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

/// A screen that displays details for a MAL character or person (seiyuu/staff).
///
/// Pass [category] = `'character'` (default) for characters, or `'person'`
/// for voice actors / staff members.
class CharacterScreen extends StatefulWidget {
  final int id;
  final String category;

  const CharacterScreen({
    super.key,
    required this.id,
    this.category = 'character',
  });

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  chara.CharacterFull? _characterInfo;
  person.PersonFull? _personInfo;
  final List<String> _pictures = [];
  int _pageIndex = 0;
  int _currentImageIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // Auto-play carousel state
  final PageController _carouselController =
      PageController(viewportFraction: 0.45);
  Timer? _autoPlayTimer;

  bool get _isCharacter => widget.category == 'character';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data fetching
  // ---------------------------------------------------------------------------

  Future<void> _fetchData() async {
    try {
      if (_isCharacter) {
        await Future.wait([
          _fetchCharacterDetails(),
          _fetchPicturesFromApi('characters'),
        ]);
      } else {
        await Future.wait([
          _fetchPersonDetails(),
          _fetchPicturesFromApi('people'),
        ]);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = S.current.Couldnt_retreive_Content;
          _isLoading = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() => _isLoading = false);
      _startAutoPlay();
    }
  }

  Future<void> _fetchCharacterDetails() async {
    final info = await JikanApi().getCharacterFullById(widget.id);
    if (!mounted) return;
    final mainImage = info.images?.jpg?.imageUrl;
    if (mainImage != null && mainImage.isNotEmpty) {
      _pictures.insert(0, mainImage);
    }
    setState(() => _characterInfo = info);
  }

  Future<void> _fetchPersonDetails() async {
    final info = await JikanApi().getPersonFullById(widget.id);
    if (!mounted) return;
    final mainImage = info.images?.jpg?.imageUrl;
    if (mainImage != null && mainImage.isNotEmpty) {
      _pictures.insert(0, mainImage);
    }
    setState(() => _personInfo = info);
  }

  /// Fetches additional picture URLs from the Jikan pictures endpoint.
  /// [kind] is either `'characters'` or `'people'`.
  Future<void> _fetchPicturesFromApi(String kind) async {
    try {
      final url = '${Constants.jikanV4}/$kind/${widget.id}/pictures';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as List? ?? [];
        final urls = data
            .map((e) {
              final jpg = e['jpg'] as Map<String, dynamic>?;
              return jpg?['image_url'] as String?;
            })
            .where((u) => u != null && u.isNotEmpty)
            .cast<String>()
            .toList();
        if (mounted && urls.isNotEmpty) {
          setState(() => _pictures.addAll(urls));
        }
      }
    } catch (_) {
      // Pictures are supplementary; don't fail the whole screen.
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (_pictures.length <= 1) return;
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_carouselController.hasClients) return;
      final nextPage = (_currentImageIndex + 1) % _pictures.length;
      _carouselController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Computed getters
  // ---------------------------------------------------------------------------

  String get _appbarTitle =>
      _characterInfo?.name ??
      _personInfo?.name ??
      (_isCharacter ? S.current.Character : S.current.Seiyuu);

  String get _nameDisplay =>
      (_isCharacter ? _characterInfo?.name : _personInfo?.name) ??
      S.current.Loading_Content;

  String get _alternateNameDisplay {
    if (_isCharacter) return _characterInfo?.nameKanji ?? '';
    final given = _personInfo?.givenName ?? '';
    final family = _personInfo?.familyName ?? '';
    if (given.isEmpty && family.isEmpty) return '';
    if (given.isEmpty) return family;
    if (family.isEmpty) return given;
    return '$given, $family';
  }

  String get _favoritesDisplay {
    if (_isCharacter) return _characterInfo?.favorites?.toString() ?? '?';
    return _personInfo?.favorites?.toString() ?? '?';
  }

  bool get _hasData => _characterInfo != null || _personInfo != null;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appbarTitle),
        actions: [
          if (_hasData)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'browser') {
                  final url = _isCharacter
                      ? 'https://myanimelist.net/character/${widget.id}'
                      : 'https://myanimelist.net/people/${widget.id}';
                  launchURLWithConfirmation(url, context: context);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'browser',
                  child: Row(
                    children: [
                      const Icon(Icons.open_in_browser, size: 20),
                      SB.w10,
                      const Text('Open in browser'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            SB.h20,
            Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    final content = _buildMobileLayout();
    if (_isLoading) return ShimmerColor(content);
    return content;
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              // Faded background image
              if (_pictures.isNotEmpty)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.3,
                    child: Background(
                      context: context,
                      url: _pictures[
                          _currentImageIndex.clamp(0, _pictures.length - 1)],
                      forceBg: true,
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Column(
                  children: [
                    // ----- Name -----
                    heading(_nameDisplay, alignment: Alignment.center),
                    SB.h30,

                    // ----- Alternate name (kanji / given + family) -----
                    if (_alternateNameDisplay.isNotEmpty)
                      heading(
                        _alternateNameDisplay,
                        alignment: Alignment.center,
                        fontSize: 18,
                      ),
                    SB.h30,

                    // ----- Image carousel -----
                    _buildImageCarousel(),
                    SB.h30,

                    // ----- Favorites count row -----
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite, color: Colors.red),
                        SB.w15,
                        title(
                          _favoritesDisplay,
                          opacity: 1,
                          align: TextAlign.center,
                          fontSize: 27,
                        ),
                        SB.w15,
                        const Icon(Icons.people),
                      ],
                    ),
                    SB.h30,

                    // ----- Tab toggle: About / Details -----
                    HeaderWidget(
                      header: [S.current.About, S.current.Details],
                      selectedIndex: _pageIndex,
                      onPressed: (index) {
                        setState(() => _pageIndex = index);
                      },
                    ),

                    // ----- Tab content -----
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _pageIndex == 0
                              ? _buildAboutWidget()
                              : _buildDetailsWidget(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Image carousel (PageView with auto-play, no external carousel package)
  // ---------------------------------------------------------------------------

  Widget _buildImageCarousel() {
    final isEmpty = _pictures.isEmpty;

    return GestureDetector(
      onTap: () {
        if (isEmpty) return;
        zoomInImageList(context, _pictures, _currentImageIndex);
      },
      child: SizedBox(
        height: 200,
        child: PageView.builder(
          controller: _carouselController,
          itemCount: isEmpty ? 1 : _pictures.length,
          onPageChanged: (index) {
            if (mounted) setState(() => _currentImageIndex = index);
          },
          itemBuilder: (context, index) {
            if (isEmpty) return _buildPlaceholderImage();
            return _buildCarouselItem(_pictures[index]);
          },
        ),
      ),
    );
  }

  Widget _buildCarouselItem(String imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipOval(
        child: AspectRatio(
          aspectRatio: 1.5,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => ShimmerColor(
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Image.asset(
              'assets/images/user_dal_old.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipOval(
        child: AspectRatio(
          aspectRatio: 1.5,
          child: Image.asset(
            'assets/images/user_dal_old.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // About tab
  // ---------------------------------------------------------------------------

  Widget _buildAboutWidget() {
    final aboutText = _isCharacter
        ? (_characterInfo?.about ?? '...')
        : (_personInfo?.about ?? '...');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SB.h30,
        SelectableText(aboutText, style: const TextStyle(fontSize: 16)),
        SB.h30,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Details tab
  // ---------------------------------------------------------------------------

  Widget _buildDetailsWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SB.h30,
        if (_isCharacter) ..._buildCharacterDetails(),
        if (!_isCharacter) ..._buildPersonDetails(),
        SB.h30,
      ],
    );
  }

  List<Widget> _buildCharacterDetails() {
    return [
      // Animeography
      _buildDetailSection(
        sectionTitle: 'Animeography',
        category: 'anime',
        items: _characterInfo?.anime
                ?.map((e) => _DetailItem(
                      malId: e.anime?.malId,
                      title: e.anime?.title,
                      imageUrl: e.anime?.images?.jpg?.imageUrl,
                      subtitle: e.role,
                    ))
                .toList() ??
            [],
      ),
      // Mangaography
      _buildDetailSection(
        sectionTitle: 'Mangaography',
        category: 'manga',
        items: _characterInfo?.manga
                ?.map((e) => _DetailItem(
                      malId: e.manga?.malId,
                      title: e.manga?.title,
                      imageUrl: e.manga?.images?.jpg?.imageUrl,
                      subtitle: e.role,
                    ))
                .toList() ??
            [],
      ),
      // Voice Actors
      _buildDetailSection(
        sectionTitle: S.current.Voice_Actors,
        category: 'person',
        items: _characterInfo?.voices
                ?.map((e) => _DetailItem(
                      malId: e.person?.malId,
                      title: e.person?.name,
                      imageUrl: e.person?.images?.jpg?.imageUrl,
                      subtitle: e.language,
                    ))
                .toList() ??
            [],
      ),
    ];
  }

  List<Widget> _buildPersonDetails() {
    // PersonFull uses library-private types (_VoiceRole, _AnimeStaff, etc.)
    // that are exposed publicly via the ignore_for_file directive.
    // We access them through dynamic casts.
    return [
      // Voice Acting Roles
      _buildDetailSection(
        sectionTitle: S.current.Voice_Acting_Roles,
        category: 'character',
        items: _extractPersonVoices(),
      ),
      // Anime Staff Positions
      _buildDetailSection(
        sectionTitle: S.current.Anime_Staff,
        category: 'anime',
        items: _extractPersonAnime(),
      ),
      // Published Manga
      _buildDetailSection(
        sectionTitle: S.current.Published_Manga,
        category: 'manga',
        items: _extractPersonManga(),
      ),
    ];
  }

  List<_DetailItem> _extractPersonVoices() {
    final voices = _personInfo?.voices;
    if (voices == null) return [];
    return voices.map((e) {
      final d = e as dynamic;
      return _DetailItem(
        malId: d.character?.malId as int?,
        title: d.character?.name as String?,
        imageUrl: d.character?.images?.jpg?.imageUrl as String?,
        subtitle: d.role as String?,
      );
    }).toList();
  }

  List<_DetailItem> _extractPersonAnime() {
    final anime = _personInfo?.anime;
    if (anime == null) return [];
    return anime.map((e) {
      final d = e as dynamic;
      return _DetailItem(
        malId: d.anime?.malId as int?,
        title: d.anime?.title as String?,
        imageUrl: d.anime?.images?.jpg?.imageUrl as String?,
        subtitle: d.position as String?,
      );
    }).toList();
  }

  List<_DetailItem> _extractPersonManga() {
    final manga = _personInfo?.manga;
    if (manga == null) return [];
    return manga.map((e) {
      final d = e as dynamic;
      return _DetailItem(
        malId: d.manga?.malId as int?,
        title: d.manga?.title as String?,
        imageUrl: d.manga?.images?.jpg?.imageUrl as String?,
        subtitle: d.position as String?,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Detail section builder (horizontal scrollable list of cards)
  // ---------------------------------------------------------------------------

  Widget _buildDetailSection({
    required String sectionTitle,
    required String category,
    required List<_DetailItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionTitle.isNotEmpty)
          title(sectionTitle, opacity: 1, fontSize: 22),
        SB.h20,
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: showNoContent(),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (_, index) {
                final item = items[index];
                if (item.malId == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _DetailCard(item: item, category: category),
                );
              },
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// Helper model for detail section items
// =============================================================================

class _DetailItem {
  final int? malId;
  final String? title;
  final String? imageUrl;
  final String? subtitle;

  const _DetailItem({this.malId, this.title, this.imageUrl, this.subtitle});
}

// =============================================================================
// Detail card - navigates to CharacterScreen or ContentDetailedScreen
// =============================================================================

class _DetailCard extends StatelessWidget {
  final _DetailItem item;
  final String category;

  const _DetailCard({required this.item, required this.category});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    final title = item.title ?? '?';

    return GestureDetector(
      onTap: () => _onTap(context),
      child: SizedBox(
        width: 105,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 140,
                width: 105,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => ShimmerColor(
                          Container(color: Colors.white),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: const Icon(Icons.image_not_supported, size: 30),
                        ),
                      )
                    : Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported, size: 30),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            if (item.subtitle != null && item.subtitle!.isNotEmpty)
              Text(
                item.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    if (category == 'character' || category == 'person') {
      gotoPage(
        context: context,
        newPage: CharacterScreen(
          id: item.malId!,
          category: category,
        ),
      );
    } else {
      gotoPage(
        context: context,
        newPage: ContentDetailedScreen(
          category: category,
          id: item.malId,
          node: Anime(
            id: item.malId!,
            title: item.title ?? '?',
            imageUrl: item.imageUrl ?? '',
            score: 0,
            members: 0,
          ),
        ),
      );
    }
  }
}
