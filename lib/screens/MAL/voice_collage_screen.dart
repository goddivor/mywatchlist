import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/gallery_saver.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/graph/graph_share.dart';

/// One character a voice actor voiced, as the person page lists it.
@immutable
class VoiceRole {
  const VoiceRole({required this.characterId, required this.name, this.image, this.anime, this.role});

  final int characterId;
  final String name;
  final String? image;

  /// The anime of the role (title), when the source gives it.
  final String? anime;

  /// MAL's role: `Main` or `Supporting`.
  final String? role;
}

/// The given name of a MAL name written "Family, Given" ("Saitou, Ena" gives "Ena"), as fan
/// collages print characters; a name without a comma stays whole.
String givenName(String name) {
  final i = name.indexOf(', ');
  final given = i < 0 ? '' : name.substring(i + 2).trim();
  return given.isEmpty ? name.trim() : given;
}

/// A MAL name written "Family, Given" in reading order ("Takahashi, Rie" gives "Rie Takahashi").
String naturalName(String name) {
  final i = name.indexOf(', ');
  if (i < 0) return name.trim();
  final given = name.substring(i + 2).trim();
  final family = name.substring(0, i).trim();
  return given.isEmpty ? family : '$given $family';
}

/// Where everything goes in a collage of [count] characters: an almost square grid of
/// [columns] by [rows] cells, the voice actor on the [actorSpan] by [actorSpan] block in the
/// middle, and the characters on the other cells in rings around it (the nearest cells first,
/// clockwise from the top), in the order given. Odd sizes keep the actor exactly in the middle.
@immutable
class CollageLayout {
  const CollageLayout._(this.columns, this.rows, this.cells);

  static const int actorSpan = 3;

  final int columns;
  final int rows;

  /// The cell (column, row) of each character, in order.
  final List<(int, int)> cells;

  int get actorColumn => (columns - actorSpan) ~/ 2;
  int get actorRow => (rows - actorSpan) ~/ 2;

  factory CollageLayout.of(int count) {
    int odd(int v) => v.isOdd ? v : v + 1;
    final total = count + actorSpan * actorSpan;
    final columns = math.max(5, odd(math.sqrt(total).ceil()));
    final rows = math.max(actorSpan, odd((total / columns).ceil()));
    final ac = (columns - actorSpan) ~/ 2;
    final ar = (rows - actorSpan) ~/ 2;
    // Centre of the actor block, in cell units.
    final cx = columns / 2;
    final cy = rows / 2;
    final free = <(int, int)>[
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < columns; c++)
          if (!(c >= ac && c < ac + actorSpan && r >= ar && r < ar + actorSpan)) (c, r),
    ];
    double ring((int, int) p) => math.max((p.$1 + 0.5 - cx).abs(), (p.$2 + 0.5 - cy).abs());
    double turn((int, int) p) {
      // Clockwise from the top: 0 straight up.
      final a = math.atan2(p.$1 + 0.5 - cx, -(p.$2 + 0.5 - cy));
      return a < 0 ? a + 2 * math.pi : a;
    }

    free.sort((a, b) {
      final c = ring(a).compareTo(ring(b));
      return c != 0 ? c : turn(a).compareTo(turn(b));
    });
    return CollageLayout._(columns, rows, List.unmodifiable(free.take(count)));
  }
}

/// A voice actor and every character they voiced as one picture, like the birthday collages
/// fans share: the actor large in the middle (name and birthday on bands), the characters all
/// around, each with its name and its anime. Pan and zoom like the relation graph; saved to the
/// gallery or shared as an image. Built from the person page's data (no extra request).
class VoiceCollageScreen extends StatefulWidget {
  const VoiceCollageScreen({
    super.key,
    required this.personId,
    required this.name,
    required this.roles,
    this.image,
    this.birthday,
  });

  final int personId;
  final String name;
  final String? image;
  final DateTime? birthday;
  final List<VoiceRole> roles;

  @override
  State<VoiceCollageScreen> createState() => _VoiceCollageScreenState();
}

class _VoiceCollageScreenState extends State<VoiceCollageScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final TransformationController _transform = TransformationController();
  late final CollageLayout _layout = CollageLayout.of(widget.roles.length);
  Size? _viewport;
  bool _placed = false;
  bool _busy = false;

  static const Color band = Color(0xFFFFB300);
  static const Color ink = Color(0xFF15110A);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color background = Color(0xFF0E0B07);

  static const double cellW = 120;
  static const double cellH = cellW * 1.62;
  static const double gap = 5;
  static const double pad = 8;

  double get _width => pad * 2 + _layout.columns * cellW + (_layout.columns - 1) * gap;
  double get _height => pad * 2 + _layout.rows * cellH + (_layout.rows - 1) * gap;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  static const int _span = CollageLayout.actorSpan;
  static const double _actorW = cellW * _span + gap * (_span - 1);
  static const double _actorH = cellH * _span + gap * (_span - 1);

  /// The opening view: the actor in the middle with half a character on each side.
  void _placeOnActor() {
    final view = _viewport;
    if (view == null) return;
    final scale = view.width / (_actorW + 2 * gap + cellW);
    final actorX = pad + _layout.actorColumn * (cellW + gap) + _actorW / 2;
    final actorY = pad + _layout.actorRow * (cellH + gap) + _actorH / 2;
    _transform.value = Matrix4.identity()
      ..translateByDouble(view.width / 2 - actorX * scale, view.height / 2 - actorY * scale, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  /// The whole collage on screen.
  void _fitAll() {
    final view = _viewport;
    if (view == null) return;
    final scale = math.min(view.width / _width, view.height / _height);
    _transform.value = Matrix4.identity()
      ..translateByDouble((view.width - _width * scale) / 2, (view.height - _height * scale) / 2, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  Future<void> _export({required bool save}) async {
    if (_busy) return;
    final boundary = _captureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return;
    setState(() => _busy = true);
    final s = S.current;
    final stem = '${widget.name}_${widget.personId}_characters';
    final png = await captureGraphPng(
      boundary: boundary,
      background: background,
      footerColor: Colors.black,
      footerTextColor: Colors.white,
      brand: s.Rg_Brand,
      logoAsset: 'assets/images/mwl-black-bg.png',
    );
    var ok = png != null;
    if (png != null) {
      ok = save ? await GallerySaver.savePng(png, graphGalleryName(stem, DateTime.now())) : await shareGraphPng(png, stem);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final text = save ? (ok ? s.Rg_Saved : s.Rg_Save_Failed) : (ok ? null : s.Rg_Share_Failed);
    if (text != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.Vc_Title),
            Text(
              s.Vc_Count(widget.roles.length),
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s.Vc_Fit,
            onPressed: _fitAll,
            icon: const Icon(Icons.fit_screen_outlined),
          ),
          IconButton(
            tooltip: s.Rg_Save,
            onPressed: _busy ? null : () => _export(save: true),
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: s.Rg_Share,
            onPressed: _busy ? null : () => _export(save: false),
            icon: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: s.Vc_Center,
        onPressed: _placeOnActor,
        child: const Icon(Icons.my_location),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = constraints.biggest;
          if (!_placed) {
            _placed = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _placeOnActor();
            });
          }
          return InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.05,
            maxScale: 4,
            transformationController: _transform,
            child: RepaintBoundary(
              key: _captureKey,
              child: Container(
                width: _width,
                height: _height,
                color: background,
                child: Stack(children: _tiles()),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _tiles() {
    Offset at(int column, int row) => Offset(pad + column * (cellW + gap), pad + row * (cellH + gap));
    final actor = at(_layout.actorColumn, _layout.actorRow);
    return [
      Positioned(
        left: actor.dx,
        top: actor.dy,
        width: _actorW,
        height: _actorH,
        child: _ActorTile(name: widget.name, image: widget.image, birthday: widget.birthday),
      ),
      for (var i = 0; i < _layout.cells.length; i++)
        Positioned(
          left: at(_layout.cells[i].$1, _layout.cells[i].$2).dx,
          top: at(_layout.cells[i].$1, _layout.cells[i].$2).dy,
          width: cellW,
          height: cellH,
          child: _RoleTile(role: widget.roles[i]),
        ),
    ];
  }
}

/// A character: its picture, a band with its name, a strip with its anime.
class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.role});

  final VoiceRole role;

  @override
  Widget build(BuildContext context) {
    final image = role.image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: image != null
                ? AppImage(url: image, fit: BoxFit.cover, alignment: Alignment.topCenter)
                : const ColoredBox(color: Color(0xFF2A241B)),
          ),
          Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: _VoiceCollageScreenState.band,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    child: Text(
                      givenName(role.name).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _VoiceCollageScreenState.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
                ColoredBox(
                  color: _VoiceCollageScreenState.paper,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    child: Text(
                      (role.anime ?? '').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _VoiceCollageScreenState.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 8.5,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
          ),
        ],
      ),
    );
  }
}

/// The voice actor in the middle: the photo, the name on a band, the birthday under it.
class _ActorTile extends StatelessWidget {
  const _ActorTile({required this.name, this.image, this.birthday});

  final String name;
  final String? image;
  final DateTime? birthday;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    final locale = Localizations.localeOf(context).toString();
    final born = birthday == null ? null : DateFormat.MMMMd(locale).format(birthday!).toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            AppImage(url: image, fit: BoxFit.cover, alignment: Alignment.topCenter)
          else
            const ColoredBox(color: Color(0xFF2A241B)),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _VoiceCollageScreenState.band,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      naturalName(name).toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _VoiceCollageScreenState.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 30,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                if (born != null)
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(
                        born,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
