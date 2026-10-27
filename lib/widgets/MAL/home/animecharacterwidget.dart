import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';

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

  bool get _isStaff => staffList != null && staffList!.isNotEmpty;
  bool get _isManga => mangaCharacterList != null && mangaCharacterList!.isNotEmpty;
  List get _characters => _isStaff ? staffList! : (_isManga ? mangaCharacterList! : animeCharacterList);

  @override
  Widget build(BuildContext context) {
    if (type == DisplayType.grid) {
      final itemsPerPage = (_isManga || _isStaff) ? 4 : 3;
      final itemHeight = (_isManga || _isStaff) ? 120.0 : 140.0;
      return _buildGridView(
          _characters.length,
          (i, pageIndex) {
            final idx = pageIndex * itemsPerPage + i;
            if (_isStaff) {
              return _buildStaffWidget(staffList![idx]);
            }
            if (_isManga) {
              return _buildMangaCharacterWidget(mangaCharacterList![idx]);
            }
            return _buildCharacterWidget(animeCharacterList[idx]);
          },
          .89,
          itemsPerPage,
          itemHeight);
    } else {
      return _buildListView();
    }
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemBuilder: (context, index) {
        if (_isStaff) {
          return _buildStaffWidget(staffList![index]);
        }
        if (_isManga) {
          return _buildMangaCharacterWidget(mangaCharacterList![index]);
        }
        return _buildCharacterWidget(animeCharacterList[index]);
      },
      itemCount: _characters.length,
    );
  }

  Widget _buildCharacterWidget(CharactersVoiceActors? details) {
    return Padding(
      padding: type == DisplayType.grid
          ? const EdgeInsets.fromLTRB(0, 5, 10, 5)
          : const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: SizedBox(
        width: double.infinity,
        child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _characterWidget(
                  _extractMalId(details?.character.name.url),
                  details?.character.image,
                  category: _extractCategory(details?.character.name.url),
                ),
                Expanded(child: _centerTextWidegt(details)),
                _seiyuuWidget(
                  _extractMalId(details?.voiceActor.name.url),
                  details?.voiceActor.image,
                ),
              ],
            )),
      ),
    );
  }

  Widget _buildMangaCharacterWidget(MangaCharacters? details) {
    final isGrid = type == DisplayType.grid;
    return Padding(
      padding: isGrid
          ? const EdgeInsets.fromLTRB(0, 3, 10, 3)
          : const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: SizedBox(
        width: double.infinity,
        child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _characterWidget(
                    _extractMalId(details?.character.name.url),
                    details?.character.image,
                    height: isGrid ? 110.0 : 120.0,
                    width: isGrid ? 85.0 : 100.0,
                    category: _extractCategory(details?.character.name.url)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _buildNameAndRole(
                      details?.character.name.name ?? S.current.Card_Unknown,
                      details?.character.role ?? "",
                    ),
                  ),
                ),
              ],
            )),
      ),
    );
  }

  Widget _buildStaffWidget(CharacterNode staff) {
    final isGrid = type == DisplayType.grid;
    final hasQuestionmark = staff.image.contains('questionmark');
    final staffId = _extractMalId(staff.name.url);
    return Padding(
      padding: isGrid
          ? const EdgeInsets.fromLTRB(0, 3, 10, 3)
          : const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: SizedBox(
        width: double.infinity,
        child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                hasQuestionmark
                    ? _assetImageWidget(
                        height: isGrid ? 110.0 : 120.0,
                        width: isGrid ? 85.0 : 100.0)
                    : _characterWidget(staffId, staff.image,
                        height: isGrid ? 110.0 : 120.0,
                        width: isGrid ? 85.0 : 100.0,
                        category: 'person'),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _buildNameAndRole(
                      staff.name.name,
                      staff.role,
                    ),
                  ),
                ),
              ],
            )),
      ),
    );
  }

  Padding _centerTextWidegt(CharactersVoiceActors? chara) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: _buildNameAndRole(
                chara?.character.name.name ?? S.current.Card_Unknown, chara?.character.role ?? ""),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: _buildSeiyuuNameAndRole(
                chara?.voiceActor.name.name ?? S.current.Card_Unknown,
                chara?.voiceActor.role ?? ''),
          ),
        ],
      ),
    );
  }
}

Widget _buildSeiyuuNameAndRole(String name, String origin) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.end,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      title(name, opacity: 1, align: TextAlign.end),
      const SizedBox(height: 5),
      if (origin.isNotBlank)
        title(origin, opacity: .8, fontSize: 11, align: TextAlign.end),
    ],
  );
}

Widget _buildNameAndRole(String characterName, String characterType) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title(characterName, opacity: 1, align: TextAlign.start),
      const SizedBox(height: 5),
      if (characterType.isNotBlank)
        title(characterType, opacity: .8, fontSize: 11, align: TextAlign.start),
    ],
  );
}

Widget _buildGridView(
  final int length,
  Widget Function(int, int) itemBuilder, [
  final double viewportFraction = .89,
  final int itemsPerPage = 3,
  final double itemHeight = 140.0,
]) {
  return _CharacterPages(
    length: length,
    itemBuilder: itemBuilder,
    viewportFraction: viewportFraction,
    itemsPerPage: itemsPerPage,
    itemHeight: itemHeight,
  );
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

const BorderRadiusDirectional _startRadius = BorderRadiusDirectional.only(
    topStart: Radius.circular(8), bottomStart: Radius.circular(8));
const BorderRadiusDirectional _endRadius = BorderRadiusDirectional.only(
    topEnd: Radius.circular(8), bottomEnd: Radius.circular(8));

Widget _seiyuuWidget(
  int? id,
  String? imageUrl, {
  double height = 120.0,
  double width = 100.0,
}) {
  return Builder(
    builder: (context) => AvatarWidget(
      userRoundBorderforLoading: false,
      height: height,
      width: width,
      onTap: () {
        if (id != null) {
          gotoPage(
            context: context,
            newPage: CharacterScreen(id: id, category: 'person'),
          );
        }
      },
      radius: _endRadius.resolve(Directionality.of(context)),
      url: imageUrl,
    ),
  );
}

Widget _characterWidget(
  int? id,
  String? imageUrl, {
  double height = 120.0,
  double width = 100.0,
  String category = 'character',
}) {
  return Builder(
    builder: (context) => AvatarWidget(
      userRoundBorderforLoading: false,
      height: height,
      width: width,
      onTap: () {
        if (id != null) {
          gotoPage(
            context: context,
            newPage: CharacterScreen(id: id, category: category),
          );
        }
      },
      radius: _startRadius.resolve(Directionality.of(context)),
      url: imageUrl,
    ),
  );
}

Widget _assetImageWidget({
  double height = 120.0,
  double width = 100.0,
}) {
  return Builder(
    builder: (context) => ClipRRect(
      borderRadius: _startRadius.resolve(Directionality.of(context)),
      child: Image.asset(
        'assets/images/user_dal.png',
        height: height,
        width: width,
        fit: BoxFit.cover,
        cacheWidth: 200,
      ),
    ),
  );
}