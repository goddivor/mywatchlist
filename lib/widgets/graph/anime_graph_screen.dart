import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:graphview/GraphView.dart';
import 'package:mywatchlist/constants/constants.dart' show showToast;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart'
    show NodeStatusValue;
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/select/select.dart';
import 'package:mywatchlist/widgets/graph/anime_graph_data.dart';
import 'package:mywatchlist/widgets/graph/anime_graph_node.dart';
import 'package:mywatchlist/widgets/graph/graph_share.dart';

/// Loads the relation graph of an anime. Replaced in tests.
@visibleForTesting
Future<AnimeGraphData> Function(int id) animeGraphLoader = (id) async {
  final json = await MwlApi.i.getAnimeGraph(id);
  return AnimeGraphData.fromJson(json);
};

enum _LoadState { loading, ready, empty, failed }

/// The relation graph of an anime: every title of its franchise as a node, relations as arrows.
///
/// Pan and zoom freely; tap a title for its details, long-press it to select it (the view
/// centers on it and, in "from the selected title" layout, the graph grows from it). The
/// layout button switches between that and a release-order layout, the camera button shares
/// the graph as a branded PNG.
class AnimeGraphScreen extends StatefulWidget {
  /// MAL id of the anime whose page opened the graph; selected at first.
  final int id;
  final String? title;

  /// List statuses (MAL's words) for titles the status cache may not know yet.
  final Map<int, String> fallbackStatuses;

  const AnimeGraphScreen(
      {super.key,
      required this.id,
      this.title,
      this.fallbackStatuses = const {}});

  @override
  State<AnimeGraphScreen> createState() => _AnimeGraphScreenState();
}

class _AnimeGraphScreenState extends State<AnimeGraphScreen>
    with SingleTickerProviderStateMixin {
  static const double _focusScale = 0.8;
  static const double _pad = 40;
  static const Color _footerColor = Color(0xFF151515);

  /// Graphs fetched during this session, so reopening one is instant.
  static final Map<int, AnimeGraphData> _sessionCache = {};

  final TransformationController _transform = TransformationController();
  final GlobalKey _captureKey = GlobalKey();
  late final ValueNotifier<int> _selected = ValueNotifier<int>(widget.id);
  late final AnimationController _focusAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  Animation<Matrix4>? _focusTween;

  AnimeGraphData _data = AnimeGraphData.empty;
  _LoadState _state = _LoadState.loading;
  GraphOrder _order = GraphOrder.fromSelected;

  SugiyamaAlgorithm? _algorithm;
  Widget? _graphView;
  Color? _builtForColor;
  Size _viewport = Size.zero;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _focusAnim.addListener(_onFocusTick);
    _load();
  }

  @override
  void dispose() {
    _focusAnim.dispose();
    _transform.dispose();
    _selected.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cached = _sessionCache[widget.id];
    if (cached != null) {
      _show(cached);
      return;
    }
    setState(() => _state = _LoadState.loading);
    try {
      final data = await animeGraphLoader(widget.id);
      if (!mounted) return;
      if (!data.isEmpty) _sessionCache[widget.id] = data;
      _show(data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _LoadState.failed);
    }
  }

  void _show(AnimeGraphData data) {
    setState(() {
      _data = data;
      _state = data.isEmpty ? _LoadState.empty : _LoadState.ready;
      _graphView = null;
    });
    if (!data.isEmpty) _focusAfterLayout(animate: false);
  }

  // ---------------------------------------------------------------- graph

  Color _edgeColor(GraphRelation relation, ColorScheme scheme) =>
      switch (relation) {
        GraphRelation.sequel => Colors.green,
        GraphRelation.prequel => Colors.red,
        _ => scheme.primary,
      };

  /// Builds the graph and its view once; later frames reuse the same widget instance, so a
  /// selection or a status change never re-runs the layout.
  Widget _buildGraphView(ColorScheme scheme) {
    final graph = Graph()..isTree = false;
    for (final edge in _data.orderedEdges(_order)) {
      final long = edge.relation == GraphRelation.sequel ||
          edge.relation == GraphRelation.prequel;
      graph.addEdge(
        Node.Id(edge.source),
        Node.Id(edge.target),
        paint: Paint()
          ..color = _edgeColor(edge.relation, scheme)
          ..strokeWidth = long ? 3 : 2
          ..style = PaintingStyle.stroke,
      );
    }
    final algorithm = SugiyamaAlgorithm(SugiyamaConfiguration()
      ..bendPointShape = CurvedBendPointShape(curveLength: 120)
      ..nodeSeparation = 40
      ..levelSeparation = 90);
    _algorithm = algorithm;
    _builtForColor = scheme.primary;
    return GraphView(
      graph: graph,
      algorithm: algorithm,
      animated: false,
      builder: (node) {
        final id = node.key?.value as int;
        final data = _data.nodes[id];
        if (data == null) return const SizedBox.shrink();
        return AnimeGraphNode(
          node: data,
          selectedId: _selected,
          fallbackStatus: widget.fallbackStatuses[id],
          onTap: () => _showNodeSheet(data),
          onLongPress: () => _select(id),
        );
      },
    );
  }

  Offset? _centerOf(int id) {
    final algorithm = _algorithm;
    if (algorithm == null) return null;
    for (final node in algorithm.nodeData.keys) {
      if (node.key?.value == id) {
        return node.position +
            Offset(kGraphNodeSize.width / 2 + _pad,
                kGraphNodeSize.height / 2 + _pad);
      }
    }
    return null;
  }

  /// Centers the view on the selected title once the layout of the current frame exists.
  void _focusAfterLayout({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusSelected(animate: animate);
    });
  }

  void _focusSelected({required bool animate}) {
    final center = _centerOf(_selected.value) ?? _centerOf(widget.id);
    if (center == null || _viewport.isEmpty) return;
    final target = Matrix4.translationValues(
        _viewport.width / 2 - center.dx * _focusScale,
        _viewport.height / 2 - center.dy * _focusScale,
        0)
      ..scaleByDouble(_focusScale, _focusScale, 1, 1);
    if (!animate) {
      _focusAnim.stop();
      _focusTween = null;
      _transform.value = target;
      return;
    }
    _focusTween = Matrix4Tween(begin: _transform.value, end: target).animate(
        CurvedAnimation(
            parent: _focusAnim, curve: const Cubic(0.23, 1, 0.32, 1)));
    _focusAnim.forward(from: 0);
  }

  void _onFocusTick() {
    final tween = _focusTween;
    if (tween != null) _transform.value = tween.value;
  }

  void _select(int id) {
    if (_selected.value == id) return;
    _selected.value = id;
    _focusSelected(animate: true);
  }

  void _changeOrder(GraphOrder order) {
    if (order == _order) return;
    setState(() {
      _order = order;
      _graphView = null;
    });
    _focusAfterLayout(animate: false);
  }

  // ---------------------------------------------------------------- sheets

  void _showNodeSheet(GraphNodeData node) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => _NodeSheet(
        node: node,
        isSelected: _selected.value == node.id,
        isCurrent: node.id == widget.id,
        fallbackStatus: widget.fallbackStatuses[node.id],
        onSelect: () {
          Navigator.pop(sheetContext);
          _select(node.id);
        },
        onOpen: () {
          Navigator.pop(sheetContext);
          if (node.id == widget.id) {
            Navigator.pop(context);
          } else {
            AppRoutes.openContent(context, id: node.id);
          }
        },
      ),
    );
  }

  void _showLegend() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.current.Rg_Legend,
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 16),
            _LegendRow(color: Colors.green, label: S.current.Rg_Legend_Sequel),
            _LegendRow(color: Colors.red, label: S.current.Rg_Legend_Prequel),
            _LegendRow(color: scheme.primary, label: S.current.Rg_Legend_Other),
            const SizedBox(height: 12),
            Text(
              S.current.Rg_Legend_Hint,
              style: Theme.of(sheetContext)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share() async {
    if (_sharing) return;
    final boundary = _captureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return;
    setState(() => _sharing = true);
    final background = Theme.of(context).scaffoldBackgroundColor;
    final brand = S.current.Rg_Brand;
    final stem = '${widget.title ?? 'anime_graph'}_${widget.id}';
    final ok = await shareGraphImage(
      boundary: boundary,
      fileStem: stem,
      background: background,
      footerColor: _footerColor,
      footerTextColor: Colors.white,
      brand: brand,
      logoAsset: 'assets/images/mwl-black-bg.png',
    );
    if (!mounted) return;
    setState(() => _sharing = false);
    if (!ok) showToast(S.current.Rg_Share_Failed);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final ready = _state == _LoadState.ready;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.current.Rg_Graph),
            if (ready)
              Text(
                S.current.Rg_Titles(_data.nodes.length),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        actions: [
          if (ready) ...[
            SelectButton<GraphOrder>(
              icon: Icons.account_tree_outlined,
              title: S.current.Rg_Order,
              selected: _order,
              options: [
                SelectOption(
                    GraphOrder.fromSelected, S.current.Rg_Order_From_Selected,
                    icon: Icons.my_location),
                SelectOption(GraphOrder.bySequel, S.current.Rg_Order_By_Sequel,
                    icon: Icons.timeline),
              ],
              onChanged: _changeOrder,
            ),
            IconButton(
              tooltip: S.current.Rg_Legend,
              onPressed: _showLegend,
              icon: const Icon(Icons.info_outline),
            ),
            IconButton(
              tooltip: S.current.Rg_Share,
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ios_share),
            ),
          ],
        ],
      ),
      body: switch (_state) {
        _LoadState.loading =>
          _Message(loading: true, text: S.current.Rg_Loading),
        _LoadState.empty =>
          _Message(icon: Icons.hub_outlined, text: S.current.Rg_Unavailable),
        _LoadState.failed => _Message(
            icon: Icons.cloud_off_outlined,
            text: S.current.Rg_Unavailable_Offline,
            onRetry: _load,
          ),
        _LoadState.ready => _graphBody(context),
      },
      floatingActionButton: ready
          ? FloatingActionButton.small(
              tooltip: S.current.Rg_Locate,
              onPressed: () {
                _selected.value = widget.id;
                _focusSelected(animate: true);
              },
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }

  Widget _graphBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_graphView == null || _builtForColor != scheme.primary) {
      _graphView = _buildGraphView(scheme);
      _focusAfterLayout(animate: false);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        return InteractiveViewer(
          constrained: false,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.05,
          maxScale: 3,
          transformationController: _transform,
          child: RepaintBoundary(
            key: _captureKey,
            child:
                Padding(padding: const EdgeInsets.all(_pad), child: _graphView),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  final IconData? icon;
  final bool loading;
  final String text;
  final VoidCallback? onRetry;

  const _Message(
      {this.icon, this.loading = false, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5))
            else
              Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                  onPressed: onRetry, child: Text(S.current.Rg_Retry)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _NodeSheet extends StatelessWidget {
  final GraphNodeData node;
  final bool isSelected;
  final bool isCurrent;
  final String? fallbackStatus;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  const _NodeSheet({
    required this.node,
    required this.isSelected,
    required this.isCurrent,
    required this.fallbackStatus,
    required this.onSelect,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cached = ListStatusCache.instance.statusOf(node.id) ?? fallbackStatus;
    final status = cached == null ? null : NodeStatusValue.fromString(cached);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppImage(
                url: node.imageUrl,
                width: 72,
                height: 104,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      graphNodeSummary(node),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (node.mean != null)
                          _Pill(
                              icon: Icons.star_rounded,
                              label: node.mean!.toStringAsFixed(2),
                              color: Colors.amber),
                        _Pill(
                          icon: status == null
                              ? Icons.add_circle_outline
                              : Icons.bookmark,
                          label: status?.fullLabel ?? S.current.Rg_Not_Listed,
                          color: status?.color,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSelected ? null : onSelect,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(
                      isSelected ? S.current.Rg_Selected : S.current.Rg_Select),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(S.current.Rg_Open),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _Pill({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: tint),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
