import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/screens/studios/studio_screen.dart';
import 'package:intl/intl.dart';
import 'package:mwl_commons/mwl_commons.dart' show CompanyHtml;
import 'package:mywatchlist/constants/constants.dart' show gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/search_sources.dart';
import 'package:mywatchlist/screens/studios/studios_pager.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the studios are laid out: rows, or a grid of 2 or 3 big logos per row.
enum StudiosDisplay { list, grid2, grid3 }

/// The 600×600 version of a MAL company logo (the directory gives 70×70). MAL's CDN serves
/// the bigger size without the signature of the small one; any other URL is kept.
String studioLogoLarge(String? url) {
  if (url == null) return '';
  final big = url.replaceFirst(RegExp(r'_\d+x\d+_i(\?.*)?$'), '_600x600_i');
  return big;
}

/// Every anime studio of MyAnimeList (its company directory: name, logo, number of anime,
/// favorites), most favorited first, with a search box. Scrolling down loads the next 50; a tap
/// opens the anime of that studio (`GeneralSearchScreen.byStudio`).
///
/// [initialQuery] starts with that search text (empty = the whole directory). Works without
/// Jikan: the pages come from MyAnimeList through the mwl-api `companies` route.
class StudiosScreen extends StatefulWidget {
  const StudiosScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<StudiosScreen> createState() => _StudiosScreenState();
}

class _StudiosScreenState extends State<StudiosScreen> {
  static const double _logoSize = 56;
  static const String _displayKey = 'studios_display_v1';
  static const Duration _searchDelay = Duration(milliseconds: 400);

  late final StudiosPager _pager = StudiosPager(onChanged: () {
    if (mounted) setState(() {});
  });
  late final TextEditingController _search = TextEditingController(text: widget.initialQuery);
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;
  StudiosDisplay _display = StudiosDisplay.list;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _pager.start(widget.initialQuery);
    _loadDisplay();
  }

  Future<void> _loadDisplay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_displayKey);
      final display = StudiosDisplay.values.where((d) => d.name == saved).firstOrNull;
      if (display != null && mounted) setState(() => _display = display);
    } catch (_) {}
  }

  Future<void> _setDisplay(StudiosDisplay display) async {
    setState(() => _display = display);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_displayKey, display.name);
    } catch (_) {}
  }

  /// A long press shows the studio's logo alone, big.
  void _preview(CompanyHtml studio) {
    final url = studioLogoLarge(studio.logo);
    if (url.isNotEmpty) zoomInImage(context, url, false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    _pager.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 800) _pager.loadMore();
  }

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(_searchDelay, () {
      if (text.trim() != _pager.query) _pager.start(text);
    });
  }

  void _submit(String text) {
    _debounce?.cancel();
    _pager.start(text);
  }

  void _clear() {
    _search.clear();
    _submit('');
  }

  void _open(CompanyHtml studio) => gotoPage(
        context: context,
        newPage: StudioScreen(id: studio.id, name: studio.name, logo: studio.logo),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surface,
        title: Text(S.current.Studios),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _SearchField(
                    controller: _search,
                    onChanged: _onQueryChanged,
                    onSubmitted: _submit,
                    onClear: _clear,
                  ),
                ),
                const SizedBox(width: 8),
                _DisplayButton(display: _display, onChanged: _setDisplay),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _pager.start(_search.text),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_pager.stage) {
      case StudiosStage.loading:
        return const _StudiosSkeleton(logoSize: _logoSize);
      case StudiosStage.error:
        final offline = _pager.failure == SearchFailureKind.offline;
        return _Message(
          icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
          title: offline ? S.current.Srs_Offline_Title : S.current.Srs_Source_Title,
          hint: offline ? S.current.Srs_Offline_Hint : S.current.Srs_Source_Hint,
          onRetry: _pager.retry,
        );
      case StudiosStage.empty:
        return _Message(
          icon: Icons.search_off_rounded,
          title: S.current.Srs_Studios_Empty,
          hint: S.current.Srs_Studios_Empty_Hint,
        );
      case StudiosStage.loaded:
        final items = _pager.items;
        final footer = _pager.hasMore || _pager.loadMoreFailed;
        if (_display != StudiosDisplay.list) {
          final columns = _display == StudiosDisplay.grid2 ? 2 : 3;
          return CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: columns == 2 ? 0.78 : 0.7,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final studio = items[index];
                    return _StudioGridTile(
                      key: ValueKey(studio.id),
                      studio: studio,
                      compact: columns == 3,
                      onTap: () => _open(studio),
                      onLongPress: () => _preview(studio),
                    );
                  },
                ),
              ),
              if (footer)
                SliverToBoxAdapter(
                  child: _Footer(failed: _pager.loadMoreFailed, onRetry: _pager.retry),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        }
        return ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: items.length + (footer ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return _Footer(failed: _pager.loadMoreFailed, onRetry: _pager.retry);
            }
            final studio = items[index];
            return _StudioTile(
              key: ValueKey(studio.id),
              studio: studio,
              logoSize: _logoSize,
              onTap: () => _open(studio),
              onLongPress: () => _preview(studio),
            );
          },
        );
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: S.current.Srs_Studios_Search_Hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: S.current.Srs_Studios_Clear,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                ),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _StudioTile extends StatelessWidget {
  const _StudioTile({
    super.key,
    required this.studio,
    required this.logoSize,
    required this.onTap,
    required this.onLongPress,
  });

  final CompanyHtml studio;
  final double logoSize;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final numbers = NumberFormat.decimalPattern(Localizations.localeOf(context).toString());
    final meta = [
      if (studio.animeCount != null) S.current.Srs_Studios_Anime_Count(numbers.format(studio.animeCount)),
      if ((studio.favorites ?? 0) > 0) S.current.Srs_Studios_Favorites(numbers.format(studio.favorites)),
    ].join(' · ');
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      label: S.current.Srs_Studios_Open(studio.name),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox.square(
                dimension: logoSize,
                child: AppImage(
                  url: studio.logo,
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.cover,
                  borderRadius: radius,
                  placeholderColor: colors.shimmerBase,
                  errorWidget: (context) => DecoratedBox(
                    decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: radius),
                    child: Center(
                      child: Text(
                        studio.name.characters.first.toUpperCase(),
                        style: theme.textTheme.titleLarge?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      studio.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurface),
                    ),
                    if (studio.japaneseName != null)
                      Text(
                        studio.japaneseName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// The display menu at the end of the search bar.
class _DisplayButton extends StatelessWidget {
  const _DisplayButton({required this.display, required this.onChanged});

  final StudiosDisplay display;
  final ValueChanged<StudiosDisplay> onChanged;

  static IconData _icon(StudiosDisplay d) => switch (d) {
        StudiosDisplay.list => Icons.view_list_rounded,
        StudiosDisplay.grid2 => Icons.grid_view_rounded,
        StudiosDisplay.grid3 => Icons.apps_rounded,
      };

  static String _label(StudiosDisplay d) => switch (d) {
        StudiosDisplay.list => S.current.Sdv_List,
        StudiosDisplay.grid2 => S.current.Sdv_Grid_2,
        StudiosDisplay.grid3 => S.current.Sdv_Grid_3,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<StudiosDisplay>(
      key: const ValueKey('studios-display'),
      tooltip: S.current.Sdv_Display,
      initialValue: display,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final d in StudiosDisplay.values)
          PopupMenuItem(
            value: d,
            child: Row(
              children: [
                Icon(_icon(d), size: 20),
                const SizedBox(width: 12),
                Text(_label(d)),
              ],
            ),
          ),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: scheme.surfaceContainerHigh, shape: BoxShape.circle),
        child: Icon(_icon(display), color: scheme.onSurface),
      ),
    );
  }
}

/// A studio as a big logo with its name and number of anime under it.
class _StudioGridTile extends StatelessWidget {
  const _StudioGridTile({
    super.key,
    required this.studio,
    required this.compact,
    required this.onTap,
    required this.onLongPress,
  });

  final CompanyHtml studio;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final numbers = NumberFormat.compact(locale: Localizations.localeOf(context).toString());
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      label: S.current.Srs_Studios_Open(studio.name),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
                clipBehavior: Clip.antiAlias,
                padding: EdgeInsets.all(compact ? 6 : 10),
                child: AppImage(
                  url: studioLogoLarge(studio.logo),
                  fit: BoxFit.contain,
                  placeholderColor: Colors.white,
                  errorWidget: (context) => ColoredBox(
                    color: colors.shimmerBase,
                    child: Center(
                      child: Text(
                        studio.name.characters.first.toUpperCase(),
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              studio.name,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: (compact ? theme.textTheme.labelMedium : theme.textTheme.titleSmall)
                  ?.copyWith(color: scheme.onSurface),
            ),
            if (studio.animeCount != null)
              Text(
                S.current.Srs_Studios_Anime_Count(numbers.format(studio.animeCount)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!failed) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3))),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Text(
            S.current.Srs_Load_More_Failed,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(S.current.Srch_Retry),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.hint, this.onRetry});

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // A scroll view, so pull to refresh also works on a message.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 24),
      children: [
        Icon(icon, size: 56, color: scheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface)),
        const SizedBox(height: 6),
        Text(hint, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(S.current.Srch_Retry),
            ),
          ),
        ],
      ],
    );
  }
}

class _StudiosSkeleton extends StatelessWidget {
  const _StudiosSkeleton({required this.logoSize});

  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final block = AppColors.of(context).shimmerBase;
    final radius = BorderRadius.circular(12);
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 10,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: block, borderRadius: radius),
              child: SizedBox.square(dimension: logoSize),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: index.isEven ? 0.6 : 0.45,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(4)),
                      child: const SizedBox(height: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FractionallySizedBox(
                    widthFactor: 0.3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(4)),
                      child: const SizedBox(height: 10),
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
}
