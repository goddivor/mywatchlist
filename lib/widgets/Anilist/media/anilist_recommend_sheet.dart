import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media_detail.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_labels.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// "Recommend a title": a search sheet over the titles of [category]; answers the picked
/// one (null when closed). Nothing is sent from here.
Future<AnilistTitleRef?> pickAnilistRecommendation(
  BuildContext context, {
  required String category,
  required int excludeId,
  AnilistMediaDetailService? service,
}) =>
    showModalBottomSheet<AnilistTitleRef>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _RecommendSheet(
        category: category,
        excludeId: excludeId,
        service: service ?? AnilistMediaDetailService.instance,
      ),
    );

class _RecommendSheet extends StatefulWidget {
  const _RecommendSheet({required this.category, required this.excludeId, required this.service});

  final String category;
  final int excludeId;
  final AnilistMediaDetailService service;

  @override
  State<_RecommendSheet> createState() => _RecommendSheetState();
}

class _RecommendSheetState extends State<_RecommendSheet> {
  final TextEditingController _text = TextEditingController();
  Timer? _debounce;
  List<AnilistTitleRef> _items = const [];
  bool _loading = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String value) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final found = await widget.service.searchTitles(value, category: widget.category);
      if (!mounted || generation != _generation) return;
      setState(() => _items = [for (final t in found) if (t.id != widget.excludeId) t]);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _text,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _changed,
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: s.Amp_Recommend_Search,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_failed)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(s.Amp_Load_Failed, style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final t = _items[i];
                  return ListTile(
                    leading: AppImage(
                      url: t.coverUrl,
                      width: 40,
                      height: 56,
                      borderRadius: BorderRadius.circular(4),
                      placeholderColor: scheme.surfaceContainerHighest,
                    ),
                    title: Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text([
                      if (t.format != null) AnilistLabels.format(t.format!),
                      if (t.year != null) '${t.year}',
                    ].join(' · ')),
                    onTap: () => Navigator.of(context).pop(t),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
