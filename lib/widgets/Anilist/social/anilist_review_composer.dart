import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_composer.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumMessage, ForumSkeleton;

/// Opens the editor of the signed-in user's review of title [mediaId] (empty for a new one,
/// filled with their review otherwise). Completes with the saved review id, `0` when the
/// review was deleted, null when nothing changed.
Future<int?> openAnilistReviewComposer(
  BuildContext context, {
  required int mediaId,
  String? mediaTitle,
  AnilistSocialService? service,
}) async {
  if (!requireAnilistSignIn(context, service: service)) return null;
  return AppRoutes.push<int>(
    context,
    AnilistReviewComposerPage(mediaId: mediaId, mediaTitle: mediaTitle, service: service),
  );
}

/// The review editor: summary, text (Write / Preview), score 0-100, private, Save; Delete
/// for an existing review. Counters show AniList's lengths and Save waits until both fit.
class AnilistReviewComposerPage extends StatefulWidget {
  const AnilistReviewComposerPage({
    super.key,
    required this.mediaId,
    this.mediaTitle,
    this.service,
  });

  final int mediaId;
  final String? mediaTitle;
  final AnilistSocialService? service;

  @override
  State<AnilistReviewComposerPage> createState() => _AnilistReviewComposerPageState();
}

class _AnilistReviewComposerPageState extends State<AnilistReviewComposerPage> {
  final _summary = TextEditingController();
  final _body = TextEditingController();
  double _score = 70;
  bool _private = false;
  bool _preview = false;
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  int? _existingId;

  AnilistSocialService get _service => widget.service ?? AnilistSocialService.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _summary.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mine = await _service.myReview(widget.mediaId);
      if (!mounted) return;
      setState(() {
        if (mine != null) {
          _existingId = mine.review.id;
          _summary.text = mine.review.summary;
          _body.text = mine.markdown;
          _score = mine.review.score.clamp(0, 100).toDouble();
          _private = mine.review.isPrivate;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  bool get _valid {
    final summary = _summary.text.trim().length;
    return summary >= AnilistReviewRules.summaryMin &&
        summary <= AnilistReviewRules.summaryMax &&
        _body.text.trim().length >= AnilistReviewRules.bodyMin;
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final id = await runAnilistWrite(
      context,
      () => _service.saveReview(
        mediaId: widget.mediaId,
        summary: _summary.text.trim(),
        markdown: _body.text.trim(),
        score: _score.round(),
        isPrivate: _private,
        id: _existingId,
      ),
      service: _service,
    );
    if (!mounted) return;
    if (id != null) {
      Navigator.of(context).pop(id);
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final id = _existingId;
    if (id == null) return;
    if (!await confirmAnilistDelete(context, S.of(context).Als_Delete_Review)) return;
    if (!mounted) return;
    final done = await runAnilistWrite(context, () async {
      await _service.deleteReview(id);
      return true;
    }, service: _service);
    if (done == true && mounted) Navigator.of(context).pop(0);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summaryLength = _summary.text.trim().length;
    final bodyLength = _body.text.trim().length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mediaTitle ?? (_existingId == null ? s.Als_Write_Review : s.Als_Edit_Review),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_existingId != null)
            IconButton(
              tooltip: s.Delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton(
              onPressed: _valid && !_saving && !_loading ? _save : null,
              child: Text(s.Save),
            ),
          ),
        ],
      ),
      body: _loading
          ? const ForumSkeleton(count: 5)
          : _error != null
              ? ForumMessage(
                  icon: Icons.cloud_off_outlined,
                  title: anilistErrorText(_error!),
                  onRetry: _load,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    TextField(
                      controller: _summary,
                      maxLength: AnilistReviewRules.summaryMax,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: s.Summary,
                        border: const OutlineInputBorder(),
                        errorText: summaryLength > 0 && summaryLength < AnilistReviewRules.summaryMin
                            ? s.Als_Min_Characters(AnilistReviewRules.summaryMin)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(s.Score, style: theme.textTheme.titleSmall),
                        Expanded(
                          child: Slider(
                            value: _score,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            label: '${_score.round()}',
                            onChanged: (v) => setState(() => _score = v),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '${_score.round()}/100',
                            textAlign: TextAlign.end,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.Als_Private),
                      value: _private,
                      onChanged: (v) => setState(() => _private = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text(s.Review, style: theme.textTheme.titleSmall)),
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
                        minLines: 12,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      s.Als_Characters_Count(bodyLength, AnilistReviewRules.bodyMin),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: bodyLength >= AnilistReviewRules.bodyMin
                            ? scheme.onSurfaceVariant
                            : scheme.error,
                      ),
                    ),
                  ],
                ),
    );
  }
}
