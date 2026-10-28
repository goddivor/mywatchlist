import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mwl_commons/mwl_commons.dart' show CompanyHtml;
import 'package:mywatchlist/constants/constants.dart' show gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/search/search_sources.dart';
import 'package:mywatchlist/screens/studios/studios_pager.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

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
  static const Duration _searchDelay = Duration(milliseconds: 400);

  late final StudiosPager _pager = StudiosPager(onChanged: () {
    if (mounted) setState(() {});
  });
  late final TextEditingController _search = TextEditingController(text: widget.initialQuery);
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _pager.start(widget.initialQuery);
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
        newPage: GeneralSearchScreen.byStudio(id: studio.id, name: studio.name),
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
            child: _SearchField(
              controller: _search,
              onChanged: _onQueryChanged,
              onSubmitted: _submit,
              onClear: _clear,
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
  const _StudioTile({super.key, required this.studio, required this.logoSize, required this.onTap});

  final CompanyHtml studio;
  final double logoSize;
  final VoidCallback onTap;

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
