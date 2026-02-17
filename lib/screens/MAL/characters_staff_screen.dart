import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_character.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_staff.dart' as staff_models;
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

class CharactersStaffScreen extends StatefulWidget {
  final int id;
  final String category;
  final int initialTab;

  const CharactersStaffScreen({
    super.key,
    required this.id,
    required this.category,
    this.initialTab = 0,
  });

  @override
  State<CharactersStaffScreen> createState() => _CharactersStaffScreenState();
}

class _CharactersStaffScreenState extends State<CharactersStaffScreen> {
  List<AnimeCharacter>? _characters;
  List<staff_models.AnimeStaff>? _staff;
  bool _isLoading = true;
  String? _error;
  late int _currentTab;

  bool get _isAnime => widget.category == 'anime';
  bool get _hasStaff => _staff != null && _staff!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final jikan = JikanApi();

      if (_isAnime) {
        final results = await Future.wait([
          jikan.getAnimeCharacters(widget.id),
          jikan.getAnimeStaff(widget.id),
        ]);
        final characters = results[0] as List<AnimeCharacter>;
        final staff = results[1] as List<staff_models.AnimeStaff>;

        // Sort characters: Main first, then by favorites descending
        characters.sort((a, b) {
          final roleOrder = _roleWeight(a.role) - _roleWeight(b.role);
          if (roleOrder != 0) return roleOrder;
          final favA = a.favorites ?? 0;
          final favB = b.favorites ?? 0;
          return favB.compareTo(favA);
        });

        if (mounted) {
          setState(() {
            _characters = characters;
            _staff = staff;
            _isLoading = false;
          });
        }
      } else {
        // Manga: characters only, no staff
        final rawChars = await jikan.getMangaCharacters(widget.id);
        final characters = rawChars
            .map((e) => AnimeCharacter.fromJson(e))
            .toList();

        characters.sort((a, b) {
          final roleOrder = _roleWeight(a.role) - _roleWeight(b.role);
          if (roleOrder != 0) return roleOrder;
          return 0;
        });

        if (mounted) {
          setState(() {
            _characters = characters;
            _staff = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  int _roleWeight(String? role) {
    if (role == null) return 2;
    switch (role.toLowerCase()) {
      case 'main':
        return 0;
      case 'supporting':
        return 1;
      default:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.Characters_and_staff),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              SB.h15,
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              SB.h20,
              FilledButton.tonal(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _fetchData();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final characters = _characters ?? [];

    return CustomScrollView(
      slivers: [
        // Tab toggle (only if staff data exists)
        if (_hasStaff)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildTabToggle(),
            ),
          ),
        SB.lh10,
        // Content
        if (_currentTab == 0)
          characters.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: showNoContent(),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildCharacterTile(characters[index]),
                    childCount: characters.length,
                  ),
                ),
        if (_currentTab == 1)
          (_staff == null || _staff!.isEmpty)
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: showNoContent(),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildStaffTile(_staff![index]),
                    childCount: _staff!.length,
                  ),
                ),
        SB.lh30,
      ],
    );
  }

  Widget _buildTabToggle() {
    final headers = [S.current.Characters, S.current.Staff];
    return Row(
      children: List.generate(headers.length, (index) {
        final isSelected = _currentTab == index;
        return Padding(
          padding: EdgeInsets.only(right: index < headers.length - 1 ? 8 : 0),
          child: FilterChip(
            selected: isSelected,
            label: Text(headers[index]),
            onSelected: (_) {
              if (_currentTab != index) {
                setState(() => _currentTab = index);
              }
            },
            showCheckmark: false,
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
            labelStyle: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ShimmerColor(
                Container(
                  height: 80,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SB.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerColor(
                      Container(
                        height: 14,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    SB.h10,
                    ShimmerColor(
                      Container(
                        height: 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Character tile
  // ---------------------------------------------------------------------------

  Widget _buildCharacterTile(AnimeCharacter char) {
    final voiceActors = char.voiceActors ?? [];
    final hasMultipleVAs = voiceActors.length > 1;
    final hasSingleVA = voiceActors.length == 1;

    if (hasMultipleVAs) {
      return _buildCharacterAccordionTile(char);
    }
    return _buildCharacterSimpleTile(char, hasSingleVA);
  }

  Widget _buildCharacterSimpleTile(AnimeCharacter char, bool hasSingleVA) {
    final characterImageUrl = char.character.images?.jpg?.imageUrl;
    final characterName = char.character.name ?? '?';
    final role = char.role ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Character
          Expanded(
            child: Row(
              children: [
                _buildAvatarWidget(
                  imageUrl: characterImageUrl,
                  onTap: () => _onCharacterTap(char.character.malId),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                SB.w10,
                Expanded(
                  child: _buildNameAndRole(characterName, role, favorites: char.favorites),
                ),
              ],
            ),
          ),
          // Right side: Voice Actor (if single)
          if (hasSingleVA)
            Expanded(
              child: _buildSingleVAWidget(char.voiceActors!.first),
            ),
        ],
      ),
    );
  }

  Widget _buildCharacterAccordionTile(AnimeCharacter char) {
    final characterImageUrl = char.character.images?.jpg?.imageUrl;
    final characterName = char.character.name ?? '?';
    final role = char.role ?? '';
    final voiceActors = char.voiceActors ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
          leading: _buildAvatarWidget(
            imageUrl: characterImageUrl,
            onTap: () => _onCharacterTap(char.character.malId),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            ),
          ),
          title: _buildNameAndRole(characterName, role, favorites: char.favorites),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${voiceActors.length} VAs',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ),
          children: [
            _buildHorizontalVAList(voiceActors),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalVAList(List<VoiceActor> voiceActors) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: voiceActors.length,
        separatorBuilder: (_, __) => SB.w15,
        itemBuilder: (context, index) {
          final va = voiceActors[index];
          return _buildVACard(va);
        },
      ),
    );
  }

  Widget _buildVACard(VoiceActor va) {
    final imageUrl = va.person?.images?.jpg?.imageUrl;
    final name = va.person?.name ?? 'Unknown';
    final language = va.language ?? '';

    return GestureDetector(
      onTap: () => _onPersonTap(va.person?.malId),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AvatarWidget(
                userRoundBorderforLoading: false,
                height: 60,
                width: 60,
                radius: BorderRadius.circular(8),
                url: imageUrl,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (language.isNotEmpty)
              Text(
                language,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleVAWidget(VoiceActor va) {
    final imageUrl = va.person?.images?.jpg?.imageUrl;
    final name = va.person?.name ?? 'Unknown';
    final language = va.language ?? '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
              SB.h5,
              if (language.isNotEmpty)
                Text(
                  language,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
        SB.w10,
        _buildAvatarWidget(
          imageUrl: imageUrl,
          onTap: () => _onPersonTap(va.person?.malId),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Staff tile
  // ---------------------------------------------------------------------------

  Widget _buildStaffTile(staff_models.AnimeStaff staffMember) {
    final imageUrl = staffMember.person.images?.jpg?.imageUrl;
    final name = staffMember.person.name ?? 'Unknown';
    final positions = staffMember.positions?.join(', ') ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatarWidget(
            imageUrl: imageUrl,
            onTap: () => _onPersonTap(staffMember.person.malId),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            ),
          ),
          SB.w10,
          Expanded(
            child: _buildNameAndRole(name, positions),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------------

  Widget _buildAvatarWidget({
    required String? imageUrl,
    required VoidCallback onTap,
    required BorderRadius borderRadius,
    double height = 80,
    double width = 60,
  }) {
    return Material(
      color: Colors.transparent,
      elevation: 4,
      borderRadius: borderRadius,
      child: AvatarWidget(
        userRoundBorderforLoading: false,
        height: height,
        width: width,
        onTap: onTap,
        radius: borderRadius,
        url: imageUrl,
      ),
    );
  }

  Widget _buildNameAndRole(String name, String role, {int? favorites}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        SB.h5,
        if (role.isNotBlank)
          Text(
            role,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.8),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        if (favorites != null) ...[
          SB.h5,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
              const SizedBox(width: 5),
              Text(
                favorites.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _onCharacterTap(int? id) {
    if (id == null) return;
    gotoPage(
      context: context,
      newPage: CharacterScreen(id: id, category: 'character'),
    );
  }

  void _onPersonTap(int? id) {
    if (id == null) return;
    gotoPage(
      context: context,
      newPage: CharacterScreen(id: id, category: 'person'),
    );
  }
}
