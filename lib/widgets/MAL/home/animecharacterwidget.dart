import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

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

/// MAL's character role ("Main", "Supporting") in the app's language; any
/// other value is shown as MAL gives it.
String castRoleLabel(String? role) {
  final value = role?.trim() ?? '';
  return switch (value.toLowerCase()) {
    'main' => S.current.Dp_Role_Main,
    'supporting' => S.current.Dp_Role_Supporting,
    _ => value,
  };
}

/// A voice actor's language as MAL names it ("Japanese", "English"...), in the
/// app's language for the common ones.
String castLanguageLabel(String? language) {
  final value = language?.trim() ?? '';
  return switch (value.toLowerCase()) {
    'japanese' => S.current.Dp_Lang_Japanese,
    'english' => S.current.Dp_Lang_English,
    'french' => S.current.Dp_Lang_French,
    'german' => S.current.Dp_Lang_German,
    'spanish' => S.current.Dp_Lang_Spanish,
    'italian' => S.current.Dp_Lang_Italian,
    'korean' => S.current.Dp_Lang_Korean,
    'portuguese (br)' => S.current.Dp_Lang_Portuguese_Br,
    'mandarin' => S.current.Dp_Lang_Mandarin,
    _ => value,
  };
}

/// Which outer corners of a [CastPicture] are rounded: DailyAL rounds the
/// side facing the edge of the row (character on the left, voice actor on
/// the right).
enum CastPictureSide { start, end, all }

/// A character's, voice actor's or staff member's portrait in DailyAL's
/// shape: a 5:6 picture with rounded outer corners. Unlike DailyAL there is
/// no elevation and nothing painted behind the picture (owner's rule: no
/// grey shadow or box). A missing picture (MAL's question mark, broken link)
/// is the round person placeholder of [RoundAvatar], never a grey rectangle.
class CastPicture extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  final CastPictureSide side;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const CastPicture({
    super.key,
    required this.url,
    this.width = 100,
    this.height = 120,
    this.side = CastPictureSide.all,
    this.onTap,
    this.semanticLabel,
  });

  static const Radius _radius = Radius.circular(8);

  BorderRadiusDirectional get _corners => switch (side) {
        CastPictureSide.start => const BorderRadiusDirectional.horizontal(start: _radius),
        CastPictureSide.end => const BorderRadiusDirectional.horizontal(end: _radius),
        CastPictureSide.all => const BorderRadiusDirectional.all(_radius),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = _corners.resolve(Directionality.of(context));
    Widget placeholder(BuildContext _) => Center(
          child: RoundAvatar(url: null, size: (width < height ? width : height) * 0.7),
        );
    final picture = RoundAvatar.isPlaceholderUrl(url)
        ? placeholder(context)
        : AppImage(
            url: url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            // MAL pictures are portraits: keep the face.
            alignment: Alignment.topCenter,
            borderRadius: radius,
            placeholderColor: scheme.surfaceContainerHighest,
            errorWidget: placeholder,
          );
    final sized = SizedBox(width: width, height: height, child: picture);
    final tap = onTap;
    if (tap == null) return Semantics(label: semanticLabel, image: true, child: sized);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: tap, child: sized),
      ),
    );
  }
}

/// Characters (with their voice actor), manga characters or staff of a
/// detail page, laid out like DailyAL: pages of three rows (grid, swiped
/// sideways) or one vertical list. An anime row is the character's portrait,
/// name and role on the left, the voice actor's name, language and portrait
/// on the right; a manga or staff row is the portrait, the name and the role.
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

  static const double _pictureWidth = 100;
  static const double _pictureHeight = 120;
  static const double _rowPadding = 4;
  static const double _rowHeight = _pictureHeight + 2 * _rowPadding;
  static const int _rowsPerPage = 3;

  bool get _isStaff => staffList != null && staffList!.isNotEmpty;
  bool get _isManga => mangaCharacterList != null && mangaCharacterList!.isNotEmpty;
  int get _length =>
      _isStaff ? staffList!.length : (_isManga ? mangaCharacterList!.length : animeCharacterList.length);

  Widget _row(int index) {
    if (_isStaff) {
      final staff = staffList![index];
      return _SingleRow(node: staff, role: staff.role, category: 'person');
    }
    if (_isManga) {
      final character = mangaCharacterList![index].character;
      return _SingleRow(node: character, role: castRoleLabel(character.role));
    }
    return _CharacterVoiceRow(details: animeCharacterList[index]);
  }

  @override
  Widget build(BuildContext context) {
    if (type == DisplayType.grid) {
      return _CharacterPages(
        length: _length,
        itemBuilder: _row,
        // DailyAL shows a slice of the next page; manga rows are narrower.
        viewportFraction: (_isManga || _isStaff) ? .79 : .89,
        itemsPerPage: _rowsPerPage,
        itemHeight: _rowHeight,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      itemExtent: _rowHeight,
      itemBuilder: (context, index) => _row(index),
      itemCount: _length,
    );
  }
}

Widget _castPicture(
  BuildContext context,
  CharacterNode node, {
  required CastPictureSide side,
  String? category,
}) {
  final id = _extractMalId(node.name.url);
  final kind = category ?? _extractCategory(node.name.url);
  final name = node.name.name;
  return CastPicture(
    url: node.image,
    width: AnimeCharacterWidget._pictureWidth,
    height: AnimeCharacterWidget._pictureHeight,
    side: side,
    semanticLabel: name.isBlank ? null : S.current.Res_Open_Character(name),
    onTap: id == null
        ? null
        : () => gotoPage(context: context, newPage: CharacterScreen(id: id, category: kind)),
  );
}

/// DailyAL's anime row: character portrait | names | voice actor portrait.
class _CharacterVoiceRow extends StatelessWidget {
  final CharactersVoiceActors details;

  const _CharacterVoiceRow({required this.details});

  @override
  Widget build(BuildContext context) {
    final character = details.character;
    final voice = details.voiceActor;
    final hasVoice = voice.name.name.isNotBlank;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnimeCharacterWidget._rowPadding),
      child: Row(
        children: [
          _castPicture(context, character, side: CastPictureSide.start),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Flexible: two long names in a narrow row shrink instead of overflowing.
                  Flexible(
                    child: CastNameAndRole(name: character.name.name, role: castRoleLabel(character.role)),
                  ),
                  if (hasVoice)
                    Flexible(
                      child: CastNameAndRole(
                        name: voice.name.name,
                        role: castLanguageLabel(voice.role),
                        end: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (hasVoice) _castPicture(context, voice, side: CastPictureSide.end, category: 'person'),
        ],
      ),
    );
  }
}

/// DailyAL's manga row (also used for staff): portrait, then name and role.
class _SingleRow extends StatelessWidget {
  final CharacterNode node;
  final String role;
  final String? category;

  const _SingleRow({required this.node, required this.role, this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = node.name.name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnimeCharacterWidget._rowPadding),
      child: Row(
        children: [
          _castPicture(context, node, side: CastPictureSide.all, category: category),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isBlank ? S.current.Res_Unknown : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (role.isNotBlank) ...[
                  const SizedBox(height: 10),
                  Text(
                    role,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A name and, under it, a smaller role (DailyAL's two-line label). [end]
/// aligns both to the end of the row (voice actor side).
class CastNameAndRole extends StatelessWidget {
  final String name;
  final String role;
  final bool end;
  final int maxLines;

  const CastNameAndRole({
    super.key,
    required this.name,
    required this.role,
    this.end = false,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = end ? TextAlign.end : TextAlign.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            name.isBlank ? S.current.Res_Unknown : name,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        if (role.isNotBlank) ...[
          const SizedBox(height: 5),
          Text(
            role,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Pages of [itemsPerPage] rows (DailyAL's paging grid). The page controller
/// lives in the state (created once, disposed) and each page is a plain
/// column of at most [itemsPerPage] rows of a fixed height.
class _CharacterPages extends StatefulWidget {
  final int length;
  final Widget Function(int index) itemBuilder;
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

  PageController _newController() => PageController(viewportFraction: widget.viewportFraction);

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
    final rowsShown = noOfPages == 1 ? length : perPage;
    return SizedBox(
      height: rowsShown * widget.itemHeight,
      child: PageView.builder(
        itemCount: noOfPages,
        controller: _controller,
        itemBuilder: (context, pageIndex) {
          final rows = pageIndex == lastPage ? (length % perPage == 0 ? perPage : length % perPage) : perPage;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Column(
              children: [
                for (var i = 0; i < rows; i++)
                  SizedBox(
                    height: widget.itemHeight,
                    child: widget.itemBuilder(pageIndex * perPage + i),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
