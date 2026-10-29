import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/upload/image_upload.dart';
import 'package:mywatchlist/widgets/mal_web/message_composer/bbcode_editing.dart';
import 'package:mywatchlist/widgets/mal_web/message_composer/message_markup.dart';
import 'package:mywatchlist/widgets/mal_web/message_composer/message_markup_view.dart';

/// Picks a photo from [source]; null when the user backs out.
typedef MalImagePick = Future<UploadImage?> Function(ImageSource source);

/// image_picker, resized on the phone (2048 px, quality 85) so uploads stay small.
Future<UploadImage?> pickMalImage(ImageSource source) async {
  final file = await ImagePicker().pickImage(source: source, maxWidth: 2048, maxHeight: 2048, imageQuality: 85);
  if (file == null) return null;
  return UploadImage(name: file.name, read: file.readAsBytes);
}

/// Asks for a URL (link or picture); null when cancelled.
Future<String?> askMalUrl(BuildContext context, {required String title, String initial = ''}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _UrlDialog(title: title, initial: initial),
  );
}

class _UrlDialog extends StatefulWidget {
  const _UrlDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_UrlDialog> createState() => _UrlDialogState();
}

class _UrlDialogState extends State<_UrlDialog> {
  late final TextEditingController _url = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _done() {
    final value = _url.text.trim();
    if (!isWebUrl(value)) {
      setState(() => _error = S.current.Pmc_Url_Invalid);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _url,
        autofocus: true,
        keyboardType: TextInputType.url,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _done(),
        decoration: InputDecoration(hintText: 'https://', errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.Cancel)),
        TextButton(onPressed: _done, child: Text(s.Pmc_Insert)),
      ],
    );
  }
}

/// Applies [format] to [controller]'s selection, asking the URL for a link.
Future<void> applyMalFormatTo(BuildContext context, TextEditingController controller, MalFormat format,
    {FocusNode? focus}) async {
  final selection = controller.selection;
  String? url;
  if (format == MalFormat.link) {
    final selected = selection.isValid && !selection.isCollapsed ? selection.textInside(controller.text).trim() : '';
    url = await askMalUrl(context, title: S.current.Pmc_Link, initial: isWebUrl(selected) ? selected : '');
    if (url == null) return;
  }
  controller.value = applyMalFormat(controller.value.copyWith(selection: selection), format, url: url);
  focus?.requestFocus();
}

/// The text selection toolbar of a message field: the platform's items, then (when text is
/// selected) Bold, Italic, Underline, Strikethrough, Spoiler and Link, as in WhatsApp.
Widget malFormattingContextMenu(
  BuildContext context,
  EditableTextState state,
  TextEditingController controller, {
  FocusNode? focus,
}) {
  final value = state.textEditingValue;
  final items = [...state.contextMenuButtonItems];
  if (value.selection.isValid && !value.selection.isCollapsed) {
    for (final format in MalFormat.values) {
      items.add(ContextMenuButtonItem(
        label: format.label,
        onPressed: () {
          state.hideToolbar();
          unawaited(applyMalFormatTo(context, controller, format, focus: focus));
        },
      ));
    }
  }
  return AdaptiveTextSelectionToolbar.buttonItems(anchors: state.contextMenuAnchors, buttonItems: items);
}

/// One upload at a time: progress for the bar, the URL inserted at the cursor kept when the
/// photo was picked.
class MalImageAttacher extends ChangeNotifier {
  MalImageAttacher({ImageUploader? uploader, MalImagePick? pick})
      : _uploader = uploader,
        _pick = pick ?? pickMalImage;

  final ImageUploader? _uploader;
  final MalImagePick _pick;
  UploadCancel? _cancel;
  double? _progress;
  bool _busy = false;
  bool _disposed = false;

  ImageUploader get uploader => _uploader ?? CatboxUploader.instance;

  bool get busy => _busy;

  /// 0..1 while the bytes go; null before the first progress event.
  double? get progress => _progress;

  void cancel() => _cancel?.cancel();

  /// Picks from [source], uploads and inserts `[img]URL[/img]` in [controller]. Completes with
  /// the failure to show, null on success or when the user backed out.
  Future<Object?> attach(ImageSource source, TextEditingController controller) async {
    if (_busy) return null;
    final UploadImage? image;
    try {
      image = await _pick(source);
    } catch (e) {
      return const ImageUploadFailed(ImageUploadError.unreadable);
    }
    if (image == null || _disposed) return null;
    final at = controller.selection;
    _busy = true;
    _progress = null;
    _cancel = UploadCancel();
    notifyListeners();
    try {
      final url = await uploader.upload(image, cancel: _cancel, onProgress: (p) {
        if (_disposed) return;
        _progress = p;
        notifyListeners();
      });
      if (_disposed) return null;
      controller.value = insertMalImage(controller.value.copyWith(selection: at), url.toString());
      return null;
    } on ImageUploadCancelled {
      return null;
    } catch (e) {
      return e;
    } finally {
      _busy = false;
      _cancel = null;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel?.cancel();
    super.dispose();
  }
}

/// The text for a failed upload.
String malUploadErrorText(Object error) {
  final s = S.current;
  if (error is ImageUploadFailed) {
    return switch (error.reason) {
      ImageUploadError.offline => s.Pmc_Upload_Offline,
      ImageUploadError.tooLarge => s.Pmc_Upload_Too_Large,
      ImageUploadError.unreadable => s.Pmc_Upload_Unreadable,
      ImageUploadError.refused => s.Pmc_Upload_Failed,
    };
  }
  return s.Pmc_Upload_Failed;
}

/// Gallery, camera or an existing picture link; uploads, inserts, reports a failure.
Future<void> showMalAttachSheet(
  BuildContext context, {
  required MalImageAttacher attacher,
  required TextEditingController controller,
  FocusNode? focus,
}) async {
  final s = S.of(context);
  final choice = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(s.Pmc_Gallery),
            onTap: () => Navigator.pop(context, 0),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(s.Pmc_Camera),
            onTap: () => Navigator.pop(context, 1),
          ),
          ListTile(
            leading: const Icon(Icons.add_link_rounded),
            title: Text(s.Pmc_Image_Link),
            onTap: () => Navigator.pop(context, 2),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 2) {
    final url = await askMalUrl(context, title: s.Pmc_Image_Link);
    if (url == null) return;
    controller.value = insertMalImage(controller.value, url);
    focus?.requestFocus();
    return;
  }
  final error = await attacher.attach(choice == 0 ? ImageSource.gallery : ImageSource.camera, controller);
  if (error != null && context.mounted) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(malUploadErrorText(error))));
  }
}

/// The upload in progress: a thin bar with the percentage and a cancel button; nothing when
/// idle.
class MalUploadProgress extends StatelessWidget {
  const MalUploadProgress({super.key, required this.attacher});

  final MalImageAttacher attacher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    return ListenableBuilder(
      listenable: attacher,
      builder: (context, _) {
        if (!attacher.busy) return const SizedBox.shrink();
        final p = attacher.progress;
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 0),
          child: Row(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p == null ? s.Pmc_Uploading : s.Pmc_Uploading_Percent((p * 100).round()),
                      style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: p, borderRadius: BorderRadius.circular(2)),
                  ],
                ),
              ),
              IconButton(
                tooltip: s.Cancel,
                icon: const Icon(Icons.close_rounded),
                onPressed: attacher.cancel,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The small formatting row above the keyboard: the six formats for the cursor or the
/// selection, then picture link and photo.
class MalFormattingBar extends StatelessWidget {
  const MalFormattingBar({
    super.key,
    required this.controller,
    required this.attacher,
    this.focus,
    this.enabled = true,
    this.showAttach = true,
  });

  final TextEditingController controller;
  final MalImageAttacher attacher;
  final FocusNode? focus;
  final bool enabled;
  final bool showAttach;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = S.of(context);
    Widget button(IconData icon, String tooltip, VoidCallback? onPressed) => IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          color: scheme.onSurfaceVariant,
          icon: Icon(icon, size: 22),
          onPressed: enabled ? onPressed : null,
        );
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          for (final f in MalFormat.values)
            button(f.icon, f.label, () => applyMalFormatTo(context, controller, f, focus: focus)),
          button(Icons.add_link_rounded, s.Pmc_Image_Link, () async {
            final url = await askMalUrl(context, title: s.Pmc_Image_Link);
            if (url == null) return;
            controller.value = insertMalImage(controller.value, url);
            focus?.requestFocus();
          }),
          if (showAttach)
            ListenableBuilder(
              listenable: attacher,
              builder: (context, _) => button(
                Icons.add_photo_alternate_outlined,
                s.Pmc_Attach_Photo,
                attacher.busy
                    ? null
                    : () => showMalAttachSheet(context, attacher: attacher, controller: controller, focus: focus),
              ),
            ),
        ],
      ),
    );
  }
}

/// What the message will look like, shown while the text holds BBCode.
class MalComposerPreview extends StatelessWidget {
  const MalComposerPreview({
    super.key,
    required this.controller,
    this.maxHeight,
    this.margin = const EdgeInsets.fromLTRB(12, 8, 12, 0),
  });

  final TextEditingController controller;
  final double? maxHeight;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (!hasMalMarkup(value.text)) return const SizedBox.shrink();
        final body = MalMessageMarkup(
          bbcodeToHtml(value.text.trim()),
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
          imageWidth: 180,
        );
        return Container(
          width: double.infinity,
          margin: margin,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.Pmc_Preview, style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary)),
              const SizedBox(height: 4),
              if (maxHeight == null)
                body
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight!),
                  child: SingleChildScrollView(child: body),
                ),
            ],
          ),
        );
      },
    );
  }
}
