import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_html.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';

/// Opens the AniList markdown composer (status, reply, comment, edit) in a bottom sheet:
/// Write / Preview (AniList's own rendering), then [submit]. The sheet stays open while
/// [submit] runs and when it fails (the error shows in a snackbar); it closes on success.
/// Returns true when [submit] succeeded.
///
/// [submit] returns false to report a failure it already showed; any error it throws is
/// shown by the composer.
Future<bool> showAnilistComposer(
  BuildContext context, {
  required String title,
  required Future<bool> Function(String markdown) submit,
  String initialText = '',
  String? sendLabel,
  AnilistSocialService? service,
}) async {
  if (!requireAnilistSignIn(context, service: service)) return false;
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => AnilistComposer(
      title: title,
      initialText: initialText,
      sendLabel: sendLabel,
      submit: submit,
      service: service,
    ),
  );
  return sent == true;
}

/// The composer of [showAnilistComposer].
class AnilistComposer extends StatefulWidget {
  const AnilistComposer({
    super.key,
    required this.title,
    required this.submit,
    this.initialText = '',
    this.sendLabel,
    this.service,
  });

  final String title;
  final String initialText;
  final String? sendLabel;
  final Future<bool> Function(String markdown) submit;
  final AnilistSocialService? service;

  @override
  State<AnilistComposer> createState() => _AnilistComposerState();
}

class _AnilistComposerState extends State<AnilistComposer> {
  late final TextEditingController _text = TextEditingController(text: widget.initialText);
  bool _preview = false;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final markdown = _text.text.trim();
    if (markdown.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    var ok = false;
    try {
      ok = await widget.submit(markdown);
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(anilistErrorText(e))));
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title, style: theme.textTheme.titleMedium)),
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
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 140,
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: _preview
                ? AnilistMarkdownPreview(markdown: _text.text, service: widget.service)
                : TextField(
                    controller: _text,
                    autofocus: widget.initialText.isEmpty,
                    minLines: 5,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: s.Als_Composer_Hint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: _text.text.trim().isEmpty || _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(widget.sendLabel ?? s.Als_Post),
            ),
          ),
        ],
      ),
    );
  }
}

/// AniList's rendering of a markdown draft (asked once per text).
class AnilistMarkdownPreview extends StatefulWidget {
  const AnilistMarkdownPreview({super.key, required this.markdown, this.service});

  final String markdown;
  final AnilistSocialService? service;

  @override
  State<AnilistMarkdownPreview> createState() => _AnilistMarkdownPreviewState();
}

class _AnilistMarkdownPreviewState extends State<AnilistMarkdownPreview> {
  late Future<String> _html;

  @override
  void initState() {
    super.initState();
    _html = _render();
  }

  @override
  void didUpdateWidget(AnilistMarkdownPreview old) {
    super.didUpdateWidget(old);
    if (old.markdown != widget.markdown) _html = _render();
  }

  Future<String> _render() =>
      (widget.service ?? AnilistSocialService.instance).preview(widget.markdown);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: FutureBuilder<String>(
        future: _html,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 3));
          }
          if (snap.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() => _html = _render()),
                child: Text(s.Al_Retry),
              ),
            );
          }
          final html = snap.data ?? '';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: html.isEmpty
                ? Text(s.Als_Nothing_To_Preview,
                    style: TextStyle(color: scheme.onSurfaceVariant))
                : AnilistHtml(html, maxImageWidth: MediaQuery.sizeOf(context).width - 56),
          );
        },
      ),
    );
  }
}
