import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/upload/image_upload.dart';
import 'package:mywatchlist/widgets/mal_web/message_composer/composer_controls.dart';

/// The reply bar of a conversation, like a chat app: photo button, rounded field (the
/// selection toolbar has the formats), send. While the field has focus the formatting row
/// sits above it, and a preview shows once the text holds BBCode.
class MalReplyComposer extends StatefulWidget {
  const MalReplyComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.hint,
    required this.onSend,
    this.uploader,
    this.pickImage,
  });

  final TextEditingController controller;
  final bool sending;
  final String hint;
  final VoidCallback onSend;
  final ImageUploader? uploader;
  final MalImagePick? pickImage;

  @override
  State<MalReplyComposer> createState() => _MalReplyComposerState();
}

class _MalReplyComposerState extends State<MalReplyComposer> {
  final FocusNode _focus = FocusNode();
  late final MalImageAttacher _attacher = MalImageAttacher(uploader: widget.uploader, pick: widget.pickImage);

  @override
  void dispose() {
    _focus.dispose();
    _attacher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final controller = widget.controller;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MalComposerPreview(controller: controller, maxHeight: 160),
            MalUploadProgress(attacher: _attacher),
            ListenableBuilder(
              listenable: _focus,
              builder: (context, _) => _focus.hasFocus
                  ? MalFormattingBar(
                      controller: controller,
                      attacher: _attacher,
                      focus: _focus,
                      enabled: !widget.sending,
                      showAttach: false,
                    )
                  : const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ListenableBuilder(
                    listenable: _attacher,
                    builder: (context, _) => IconButton(
                      tooltip: s.Pmc_Attach_Photo,
                      color: scheme.onSurfaceVariant,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      onPressed: widget.sending || _attacher.busy
                          ? null
                          : () => showMalAttachSheet(context, attacher: _attacher, controller: controller, focus: _focus),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: _focus,
                      enabled: !widget.sending,
                      minLines: 1,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      contextMenuBuilder: (context, state) =>
                          malFormattingContextMenu(context, state, controller, focus: _focus),
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ListenableBuilder(
                    listenable: Listenable.merge([controller, _attacher]),
                    builder: (context, _) => widget.sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton.filled(
                            tooltip: s.Pm_Send,
                            onPressed: controller.text.trim().isEmpty || _attacher.busy ? null : widget.onSend,
                            icon: const Icon(Icons.send_rounded),
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
