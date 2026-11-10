import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_thread_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_composer.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';

/// Opens the "new thread" editor; [mediaIds] links the thread to titles (AniList media ids),
/// [categoryId] preselects a category. The new thread opens in place of the editor.
Future<void> openAnilistThreadComposer(
  BuildContext context, {
  List<int> mediaIds = const [],
  int? categoryId,
  AnilistSocialService? service,
}) async {
  if (!requireAnilistSignIn(context, service: service)) return;
  await AppRoutes.push<void>(
    context,
    AnilistThreadComposerPage(mediaIds: mediaIds, categoryId: categoryId, service: service),
  );
}

/// Title, categories (at least one, like anilist.co), body with Write / Preview, Post.
class AnilistThreadComposerPage extends StatefulWidget {
  const AnilistThreadComposerPage({
    super.key,
    this.mediaIds = const [],
    this.categoryId,
    this.service,
  });

  final List<int> mediaIds;
  final int? categoryId;
  final AnilistSocialService? service;

  @override
  State<AnilistThreadComposerPage> createState() => _AnilistThreadComposerPageState();
}

class _AnilistThreadComposerPageState extends State<AnilistThreadComposerPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  late final Set<int> _categories = {if (widget.categoryId != null) widget.categoryId!};
  bool _preview = false;
  bool _saving = false;

  AnilistSocialService get _service => widget.service ?? AnilistSocialService.instance;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty && _categories.isNotEmpty;

  Future<void> _post() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final id = await runAnilistWrite(
      context,
      () => _service.saveThread(
        title: _title.text.trim(),
        markdown: _body.text.trim(),
        categories: _categories.toList(),
        mediaIds: widget.mediaIds,
      ),
      service: _service,
    );
    if (!mounted) return;
    if (id == null) {
      setState(() => _saving = false);
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => AnilistThreadPage(threadId: id, service: _service)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.Als_New_Thread),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton(
              onPressed: _valid && !_saving ? _post : null,
              child: Text(s.Als_Post),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: s.Als_Thread_Title,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(s.Als_Categories, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in AnilistForumCategory.all)
                FilterChip(
                  label: Text(anilistCategoryName(c)),
                  selected: _categories.contains(c.id),
                  onSelected: (on) => setState(() => on ? _categories.add(c.id) : _categories.remove(c.id)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(value: false, label: Text(s.Als_Write)),
                  ButtonSegment(value: true, label: Text(s.Preview)),
                ],
                selected: {_preview},
                onSelectionChanged: (v) {
                  FocusScope.of(context).unfocus();
                  setState(() => _preview = v.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_preview)
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 240,
                maxHeight: MediaQuery.sizeOf(context).height * 0.6,
              ),
              child: AnilistMarkdownPreview(markdown: _body.text, service: _service),
            )
          else
            TextField(
              controller: _body,
              minLines: 10,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
        ],
      ),
    );
  }
}

/// A forum category's name in the app language (AniList's English name for unknown ids).
String anilistCategoryName(AnilistForumCategory c) {
  final s = S.current;
  return switch (c.id) {
    1 => s.Als_Cat_Anime,
    2 => s.Als_Cat_Manga,
    3 => s.Als_Cat_Light_Novels,
    4 => s.Als_Cat_Visual_Novels,
    5 => s.Als_Cat_Release_Discussion,
    7 => s.Als_Cat_General,
    8 => s.Als_Cat_News,
    9 => s.Als_Cat_Music,
    10 => s.Als_Cat_Gaming,
    11 => s.Als_Cat_Site_Feedback,
    12 => s.Als_Cat_Bug_Reports,
    13 => s.Als_Cat_Site_Announcements,
    14 => s.Als_Cat_List_Customisation,
    15 => s.Als_Cat_Recommendations,
    16 => s.Als_Cat_Forum_Games,
    18 => s.Als_Cat_Anilist_Apps,
    19 => s.Als_Cat_Events,
    _ => c.name,
  };
}
