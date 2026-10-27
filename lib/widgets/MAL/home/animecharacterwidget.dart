import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';

//this file will be renomed to content_character_widget.dart

/// Extracts the MAL ID from a URL like `/character/12345/...` or `/people/12345/...`
int? _extractMalId(String? url) {
  if (url == null || url.isEmpty) return null;
  final match = RegExp(r'/(?:character|people)/(\d+)').firstMatch(url);
  if (match != null) return int.tryParse(match.group(1)!);
  return null;
}

/// Determines the category from a URL (`character` or `person`)
String _extractCategory(String? url) {
  if (url == null) return 'character';
  if (url.contains('/people/')) return 'person';
  return 'character';
}

/// Characters (with their voice actor), manga characters or staff of a detail page, as
/// pages of rows (grid) or one list. Every picture is a clean circle ([RoundAvatar]).
class AnimeCharacterWidget extends StatelessWidget {
  final List<CharactersVoiceActors> animeCharacterList;
  final List<MangaCharacters>? mangaCharacterList;
  final List<CharacterNode>? staffList;
  final DisplayType type;
  const AnimeCharacterWidget({
    super.key,
    this.animeCharacterList = const [],
    this.mangaCharacterList,
    this.staffList,
    required double horizPadding,
    this.type = DisplayType.grid,
  });

  static const double _avatar = 56;
  static const double _rowHeight = 76;

  bool get _isStaff => staffList != null && staffList!.isNotEmpty;
  bool get _isManga => mangaCharacterList != null && mangaCharacterList!.isNotEmpty;
  List get _characters => _isStaff ? staffList! : (_isManga ? mangaCharacterList! : animeCharacterList);

  Widget _row(int index) {
    if (_isStaff) return _buildStaffWidget(staffList![index]);
    if (_isManga) return _buildMangaCharacterWidget(mangaCharacterList![index]);
    return _buildCharacterWidget(animeCharacterList[index]);
  }

  @override
  Widget build(BuildContext context) {
    if (type == DisplayType.grid) {
      final itemsPerPage = (_isManga || _isStaff) ? 4 : 3;
      return _CharacterPages(
        length: _characters.length,
        itemBuilder: (i, pageIndex) => _row(pageIndex * itemsPerPage + i),
        viewportFraction: .89,
        itemsPerPage: itemsPerPage,
        itemHeight: _rowHeight,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemExtent: _rowHeight,
      itemBuilder: (context, index) => _row(index),
      itemCount: _characters.length,
    );
  }

  EdgeInsets get _padding => type == DisplayType.grid
      ? const EdgeInsetsDirectional.only(end: 10).resolve(TextDirection.ltr)
      : const EdgeInsets.symmetric(horizontal: 12);

  Widget _buildCharacterWidget(CharactersVoiceActors details) {
    final character = details.character;
    final voice = details.voiceActor;
    final hasVoice = voice.name.name.isNotBlank;
    return Padding(
      padding: _padding,
      child: Row(
        children: [
          _avatarLink(character.name.url, character.image, character.name.name),
          const SizedBox(width: 12),
          Expanded(child: _NameAndRole(name: character.name.name, role: character.role)),
          if (hasVoice) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _NameAndRole(name: voice.name.name, role: voice.role, end: true),
            ),
            const SizedBox(width: 12),
            _avatarLink(voice.name.url, voice.image, voice.name.name, category: 'person'),
          ],
        ],
      ),
    );
  }

  Widget _buildMangaCharacterWidget(MangaCharacters details) {
    final character = details.character;
    return Padding(
      padding: _padding,
      child: Row(
        children: [
          _avatarLink(character.name.url, character.image, character.name.name),
          const SizedBox(width: 12),
          Expanded(child: _NameAndRole(name: character.name.name, role: character.role)),
        ],
      ),
    );
  }

  Widget _buildStaffWidget(CharacterNode staff) {
    return Padding(
      padding: _padding,
      child: Row(
        children: [
          _avatarLink(staff.name.url, staff.image, staff.name.name, category: 'person'),
          const SizedBox(width: 12),
          Expanded(child: _NameAndRole(name: staff.name.name, role: staff.role)),
        ],
      ),
    );
  }

  Widget _avatarLink(String? url, String? image, String name, {String? category}) {
    final id = _extractMalId(url);
    final kind = category ?? _extractCategory(url);
    return Builder(
      builder: (context) => RoundAvatar(
        url: image,
        size: _avatar,
        semanticLabel: name.isBlank ? null : S.current.Res_Open_Character(name),
        onTap: id == null
            ? null
            : () => gotoPage(context: context, newPage: CharacterScreen(id: id, category: kind)),
      ),
    );
  }
}

class _NameAndRole extends StatelessWidget {
  final String name;
  final String role;
  final bool end;

  const _NameAndRole({required this.name, required this.role, this.end = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = end ? TextAlign.end : TextAlign.start;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          name.isBlank ? S.current.Res_Unknown : name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: theme.textTheme.bodyMedium,
        ),
        if (role.isNotBlank) ...[
          const SizedBox(height: 3),
          Text(
            role,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Pages of [itemsPerPage] rows. The page controller lives in the state (it
/// used to be created on every build and never disposed) and each page is a
/// plain column of at most [itemsPerPage] rows.
class _CharacterPages extends StatefulWidget {
  final int length;
  final Widget Function(int, int) itemBuilder;
  final double viewportFraction;
  final int itemsPerPage;
  final double itemHeight;

  const _CharacterPages({
    required this.length,
    required this.itemBuilder,
    required this.viewportFraction,
    required this.itemsPerPage,
    required this.itemHeight,
  });

  @override
  State<_CharacterPages> createState() => _CharacterPagesState();
}

class _CharacterPagesState extends State<_CharacterPages> {
  late PageController _controller = _newController();

  PageController _newController() =>
      PageController(viewportFraction: widget.viewportFraction);

  @override
  void didUpdateWidget(_CharacterPages old) {
    super.didUpdateWidget(old);
    if (old.viewportFraction != widget.viewportFraction) {
      _controller.dispose();
      _controller = _newController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final length = widget.length;
    final perPage = widget.itemsPerPage;
    final noOfPages = (length / perPage).ceil();
    final lastPage = noOfPages - 1;
    final itemsOnSinglePage = noOfPages == 1 ? length : perPage;
    return SizedBox(
      height: itemsOnSinglePage * widget.itemHeight,
      child: PageView.builder(
        itemCount: noOfPages,
        controller: _controller,
        clipBehavior: Clip.none,
        itemBuilder: (context, pageIndex) {
          final rows = pageIndex == lastPage
              ? (length % perPage == 0 ? perPage : length % perPage)
              : perPage;
          return Column(
            children: [
              for (var i = 0; i < rows; i++)
                SizedBox(
                  height: widget.itemHeight,
                  child: widget.itemBuilder(i, pageIndex),
                ),
            ],
          );
        },
      ),
    );
  }
}
