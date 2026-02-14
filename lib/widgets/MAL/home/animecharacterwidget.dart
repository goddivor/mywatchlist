import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';

//this file will be renomed to content_character_widget.dart

class AnimeCharacterWidget extends StatelessWidget {
  final List<CharactersVoiceActors> animeCharacterList;
  final List<MangaCharacters>? mangaCharacterList;
  final DisplayType type;
  const AnimeCharacterWidget({
    super.key,
    this.animeCharacterList = const [],
    this.mangaCharacterList,
    required double horizPadding,
    this.type = DisplayType.grid,
  });

  bool get _isManga => mangaCharacterList != null && mangaCharacterList!.isNotEmpty;
  List get _characters => _isManga ? mangaCharacterList! : animeCharacterList;

  @override
  Widget build(BuildContext context) {
    if (type == DisplayType.grid) {
      final itemsPerPage = _isManga ? 4 : 3;
      final itemHeight = _isManga ? 120.0 : 140.0;
      return _buildGridView(
          _characters.length,
          (i, pageIndex) {
            final idx = pageIndex * itemsPerPage + i;
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
                _characterWidget(null, details?.character.image),
                Expanded(child: _centerTextWidegt(details)),
                _seiyuuWidget(null, details?.voiceActor.image),
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
                _characterWidget(null, details?.character.image,
                    height: isGrid ? 110.0 : 120.0,
                    width: isGrid ? 85.0 : 100.0),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _buildNameAndRole(
                      details?.character.name.name ?? "?",
                      details?.character.role ?? "",
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
                chara?.character.name.name ?? "?", chara?.character.role ?? ""),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: _buildSeiyuuNameAndRole(
                chara?.voiceActor.name.name ?? 'Unknown',
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
  final pageController =
      PageController(initialPage: 0, viewportFraction: viewportFraction);
  final noOfPages = (length / itemsPerPage).ceilToDouble().toInt();
  final lastPage = noOfPages - 1;
  final itemsOnSinglePage = noOfPages == 1 ? length : itemsPerPage;
  return SizedBox(
    height: itemsOnSinglePage * itemHeight,
    child: PageView.builder(
      itemCount: noOfPages,
      controller: pageController,
      clipBehavior: Clip.none,
      itemBuilder: ((context, pageIndex) {
        return ListView.builder(
          itemCount: pageIndex == lastPage
              ? (length % itemsPerPage == 0 ? itemsPerPage : length % itemsPerPage)
              : itemsPerPage,
          scrollDirection: Axis.vertical,
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (_, i) => SizedBox(
            height: itemHeight,
            child: itemBuilder(i, pageIndex),
          ),
        );
      }),
    ),
  );
}

Widget _seiyuuWidget(
  int? id,
  String? imageUrl, {
  double height = 120.0,
  double width = 100.0,
}) {
  const borderRadius = BorderRadius.only(
      topRight: Radius.circular(8), bottomRight: Radius.circular(8));
  return Material(
    color: Colors.transparent,
    elevation: 4,
    borderRadius: borderRadius,
    child: AvatarWidget(
      userRoundBorderforLoading: false,
      height: height,
      width: width,
      onTap: () {
        if (id != null) {
          // gotoPage(
          //     context: MyApp.navigatorKey.currentContext!,
          //     newPage: CharacterScreen(
          //       id: id,
          //       charaCategory: "seiyuu",
          //     ));
        }
      },
      radius: borderRadius,
      url: imageUrl,
    ),
  );
}

Widget _characterWidget(
  int? id,
  String? imageUrl, {
  double height = 120.0,
  double width = 100.0,
}) {
  const borderRadius = BorderRadius.only(
      topRight: Radius.circular(8), bottomRight: Radius.circular(8));
  return Material(
    color: Colors.transparent,
    elevation: 4,
    borderRadius: borderRadius,
    child: AvatarWidget(
      userRoundBorderforLoading: false,
      height: height,
      width: width,
      onTap: () {
        // if (id != null) {
        //   gotoPage(
        //       context: MyApp.navigatorKey.currentContext!,
        //       newPage: CharacterScreen(id: id, charaCategory: category));
        // }
      },
      radius: const BorderRadius.only(
          topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
      url: imageUrl,
    ),
  );
}