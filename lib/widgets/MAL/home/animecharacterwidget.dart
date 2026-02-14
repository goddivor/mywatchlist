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
      return _buildGridView(
          _characters.length,
          (i, pageIndex) {
            final idx = pageIndex * 3 + i;
            if (_isManga) {
              return _buildMangaCharacterWidget(mangaCharacterList![idx]);
            }
            return _buildCharacterWidget(animeCharacterList[idx]);
          });
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
]) {
  const double itemHeight = 140.0;
  final pageController =
      PageController(initialPage: 0, viewportFraction: viewportFraction);
  final noOfPages = (length / 3).ceilToDouble().toInt();
  final lastPage = noOfPages - 1;
  final itemsOnSinglePage = noOfPages == 1 ? length : 3;
  return SizedBox(
    height: itemsOnSinglePage * itemHeight,
    child: PageView.builder(
      itemCount: noOfPages,
      controller: pageController,
      clipBehavior: Clip.none,
      itemBuilder: ((context, pageIndex) {
        return ListView.builder(
          itemCount:
              pageIndex == lastPage ? (length % 3 == 0 ? 3 : length % 3) : 3,
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

// class MangaCharacterWidget extends StatelessWidget {
//   final DisplayType type;
//   final List<MangaCharacterHtml> mangaCharacters;
//   const MangaCharacterWidget({
//     Key? key,
//     required this.mangaCharacters,
//     this.type = DisplayType.grid,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     if (type == DisplayType.grid) {
//       return _buildGridView(
//         mangaCharacters.length,
//         (i, pageIndex) =>
//             _buildCharacterRow(mangaCharacters.tryAt(pageIndex * 3 + i)),
//         .79,
//       );
//     } else {
//       return ListView.builder(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
//         itemBuilder: (_, i) => _buildCharacterRow(mangaCharacters.tryAt(i)),
//         itemCount: mangaCharacters.length,
//       );
//     }
//   }

//   Padding _buildCharacterRow(MangaCharacterHtml? char) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 5),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           _characterWidget(
//             char?.characterId,
//             char?.animePicture,
//           ),
//           SB.w15,
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               title(
//                 char?.characterName ?? "?",
//                 opacity: 1,
//                 fontSize: 16,
//               ),
//               SB.h10,
//               if (char?.characterType != null) title(char!.characterType!),
//             ],
//           )
//         ],
//       ),
//     );
//   }
// }

// class AllCharsWidget extends StatefulWidget {
//   final String category;
//   final int id;
//   const AllCharsWidget({Key? key, required this.category, required this.id})
//       : super(key: key);

//   @override
//   State<AllCharsWidget> createState() => _AllCharsWidgetState();
// }

// class _AllCharsWidgetState extends State<AllCharsWidget> {
//   late Future<ContentAllCharData> allCharsAndStaffFuture;
//   final _roleMap = {'m': 'Main', 's': 'Supporting'};
//   final _headers = [S.current.Characters, S.current.Staff];
//   int _currIndex = 0;
//   @override
//   void initState() {
//     super.initState();
//     allCharsAndStaffFuture =
//         DalApi.i.getAllCharsAndStaff(widget.category, widget.id);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return CFutureBuilder<ContentAllCharData>(
//       future: allCharsAndStaffFuture,
//       done: (sp) => buildWidget(sp.data),
//       loadingChild: loadingBelowText(),
//     );
//   }

//   Widget buildWidget(ContentAllCharData? dd) {
//     if (dd?.data == null) return showNoContent();
//     final chars = dd?.data?.characters ?? [];
//     final staffs = dd?.data?.staffs ?? [];
//     return CustomScrollView(
//       slivers: [
//         if (staffs.isNotEmpty)
//           SliverWrapper(Padding(
//             padding: const EdgeInsets.only(top: 30),
//             child: HeaderWidget(
//               header: _headers,
//               selectedIndex: _currIndex,
//               shouldAnimate: false,
//               onPressed: (index) {
//                 if (mounted)
//                   setState(() {
//                     _currIndex = index;
//                   });
//               },
//             ),
//           )),
//         SB.lh30,
//         if (_currIndex == 0)
//           chars.isEmpty
//               ? showNoContentSliver()
//               : SliverList(
//                   delegate: SliverChildBuilderDelegate(
//                   (context, index) => _buildCharTile(chars[index]),
//                   childCount: chars.length,
//                 )),
//         if (_currIndex == 1)
//           SliverList(
//               delegate: SliverChildBuilderDelegate(
//             (context, index) => _buildStaffTile(staffs[index]),
//             childCount: staffs.length,
//           ))
//       ],
//     );
//   }

//   Widget _buildCharTile(Character char) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Expanded(
//             child: Row(
//               children: [
//                 _characterWidget(
//                   char.charInfo?.id,
//                   char.characterImage?.large ?? char.characterImage?.medium,
//                   height: 80,
//                   width: 60,
//                 ),
//                 SB.w10,
//                 Expanded(
//                   child: _buildNameAndRole(char.charInfo?.name ?? '',
//                       _roleMap[char.charInfo?.role ?? 's'] ?? 'Unknown'),
//                 )
//               ],
//             ),
//           ),
//           if (char.staffInfoList != null && char.staffInfoList!.isNotEmpty)
//             Expanded(
//               child: Padding(
//                 padding: EdgeInsets.only(
//                     top: char.staffInfoList!.length == 1 ? 0 : 25),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: char.staffInfoList
//                       !.map((staff) => Padding(
//                             padding: const EdgeInsets.only(bottom: 10),
//                             child: Row(
//                               children: [
//                                 Expanded(
//                                     child: _buildSeiyuuNameAndRole(
//                                         staff.name!, staff.language!)),
//                                 SB.w10,
//                                 _seiyuuWidget(
//                                   staff.id,
//                                   staff.image?.large ?? staff.image?.medium,
//                                   height: 80,
//                                   width: 60,
//                                 ),
//                               ],
//                             ),
//                           ))
//                       .toList(),
//                 ),
//               ),
//             )
//         ],
//       ),
//     );
//   }

//   Widget _buildStaffTile(Staff staff) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Expanded(
//             child: Row(
//               children: [
//                 _characterWidget(
//                     staff.id, staff.image?.large ?? staff.image?.medium,
//                     height: 80, width: 60, category: 'seiyuu'),
//                 SB.w10,
//                 Expanded(
//                   child: _buildNameAndRole(
//                     staff.name!,
//                     staff.role ?? 'Unknown',
//                   ),
//                 )
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
