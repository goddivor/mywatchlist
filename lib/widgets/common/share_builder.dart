import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:share_plus/share_plus.dart';

/// One piece of text the user may include when sharing: a translated [label]
/// (shown in the picker and, if [labelled], before the value in the output)
/// and its [value].
@immutable
class ShareField {
  final String label;
  final String value;
  final bool selected;
  final bool labelled;

  const ShareField({required this.label, required this.value, this.selected = true, this.labelled = true});

  ShareField copyWith({bool? selected}) =>
      ShareField(label: label, value: value, selected: selected ?? this.selected, labelled: labelled);
}

/// How [buildShareText] joins the selected fields.
@immutable
class ShareFormat {
  /// Written before each field (e.g. `'• '`).
  final String prefix;

  /// Between a field's label and its value.
  final String separator;

  /// Between two fields.
  final String joiner;

  /// Keep the label even when a single field is selected (by default a lone
  /// field is shared as its bare value, e.g. just the URL).
  final bool alwaysLabel;

  const ShareFormat({this.prefix = '', this.separator = ': ', this.joiner = '\n', this.alwaysLabel = false});
}

/// The text shared for the selected [fields] ('' when none is selected).
String buildShareText(List<ShareField> fields, {ShareFormat format = const ShareFormat()}) {
  final selected = fields.where((f) => f.selected).toList();
  if (selected.isEmpty) return '';
  if (selected.length == 1 && !format.alwaysLabel) return selected.first.value;
  return selected
      .map((f) => f.labelled ? '${format.prefix}${f.label}${format.separator}${f.value}' : '${format.prefix}${f.value}')
      .join(format.joiner);
}

/// Standard fields of an anime/manga page, tracker-agnostic: give what the
/// tracker provides, null values are skipped. The URL comes first, unlabelled.
List<ShareField> contentShareFields({
  String? url,
  String? title,
  int? rank,
  double? mean,
  int? members,
  List<String>? genres,
  String? synopsis,
}) {
  final count = NumberFormat.compact();
  return [
    if (url != null && url.isNotEmpty) ShareField(label: S.current.Url, value: url, labelled: false),
    if (title != null && title.isNotEmpty) ShareField(label: S.current.Title, value: title),
    if (rank != null) ShareField(label: S.current.Rank, value: '#$rank'),
    if (mean != null)
      ShareField(
        label: S.current.Score,
        value: members == null ? mean.toStringAsFixed(2) : '${mean.toStringAsFixed(2)} (${count.format(members)})',
      ),
    if (genres != null && genres.isNotEmpty) ShareField(label: S.current.Genres, value: genres.join(', ')),
    if (synopsis != null && synopsis.trim().isNotEmpty) ShareField(label: S.current.Synopsis, value: synopsis.trim()),
  ];
}

/// Standard fields of a character or person page; null values are skipped.
List<ShareField> personShareFields({String? url, String? name, int? favorites, String? about}) => [
      if (url != null && url.isNotEmpty) ShareField(label: S.current.Url, value: url, labelled: false),
      if (name != null && name.isNotEmpty) ShareField(label: S.current.Name, value: name),
      if (favorites != null) ShareField(label: S.current.Favorites, value: NumberFormat.decimalPattern().format(favorites)),
      if (about != null && about.trim().isNotEmpty) ShareField(label: S.current.About, value: about.trim()),
    ];

/// Sends the text to the platform share sheet. Tests replace it.
@visibleForTesting
Future<void> Function(String text, String? subject) shareTextSender =
    (text, subject) => Share.share(text, subject: subject);

/// Opens the share builder: the user picks which [fields] to include, sees a
/// preview, then copies or shares the text ([subject] is the e-mail subject
/// some targets use). With a single field it shares at once, no sheet.
///
/// ```dart
/// AppBarMenu(onShare: () => showShareBuilder(
///   context,
///   subject: anime.title,
///   fields: contentShareFields(url: url, title: anime.title, mean: anime.mean, synopsis: anime.synopsis),
/// ));
/// ```
Future<void> showShareBuilder(
  BuildContext context, {
  required List<ShareField> fields,
  String? subject,
  String? title,
  ShareFormat format = const ShareFormat(),
}) async {
  if (fields.isEmpty) return;
  if (fields.length == 1) return shareTextSender(fields.first.value, subject);
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => ShareBuilder(
      fields: fields,
      title: title,
      format: format,
      onCopy: (text) async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        await Clipboard.setData(ClipboardData(text: text));
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        messenger?.showSnackBar(SnackBar(content: Text(S.current.Copied_to_Clipboard)));
      },
      onShare: (text) {
        Navigator.of(sheetContext).pop();
        shareTextSender(text, subject);
      },
    ),
  );
}

/// Body of [showShareBuilder]: a checkbox per field (at least one stays
/// checked), "Select all" / "Select one", a live preview, and Copy / Share
/// buttons that receive the built text.
class ShareBuilder extends StatefulWidget {
  final List<ShareField> fields;
  final String? title;
  final ShareFormat format;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onShare;

  const ShareBuilder({
    super.key,
    required this.fields,
    required this.onCopy,
    required this.onShare,
    this.title,
    this.format = const ShareFormat(),
  });

  @override
  State<ShareBuilder> createState() => _ShareBuilderState();
}

class _ShareBuilderState extends State<ShareBuilder> {
  late List<ShareField> _fields = _normalized(widget.fields);

  static List<ShareField> _normalized(List<ShareField> fields) {
    if (fields.isEmpty || fields.any((f) => f.selected)) return List.of(fields);
    return [fields.first.copyWith(selected: true), ...fields.skip(1)];
  }

  @override
  void didUpdateWidget(covariant ShareBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.fields, widget.fields)) _fields = _normalized(widget.fields);
  }

  int get _selectedCount => _fields.where((f) => f.selected).length;

  void _toggle(int index, bool value) {
    // The last checked field cannot be unchecked: there is always something to share.
    if (!value && _selectedCount == 1) return;
    setState(() => _fields[index] = _fields[index].copyWith(selected: value));
  }

  void _selectAll() => setState(() => _fields = [for (final f in _fields) f.copyWith(selected: true)]);

  void _selectOne() => setState(() => _fields = [
        for (var i = 0; i < _fields.length; i++) _fields[i].copyWith(selected: i == 0),
      ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = buildShareText(_fields, format: widget.format);
    final allSelected = _selectedCount == _fields.length;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 12, 4),
            child: Row(
              children: [
                Expanded(child: Text(widget.title ?? S.current.Share, style: theme.textTheme.titleLarge)),
                TextButton(
                  onPressed: allSelected ? _selectOne : _selectAll,
                  child: Text(allSelected ? S.current.Select_One : S.current.Select_All),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (var i = 0; i < _fields.length; i++)
                  CheckboxListTile(
                    value: _fields[i].selected,
                    onChanged: (value) => _toggle(i, value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(_fields[i].label, style: theme.textTheme.titleSmall),
                    subtitle: Text(_fields[i].value, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    S.current.Kit_Share_Preview,
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(text, maxLines: 6, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onCopy(text),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(S.current.Copy),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => widget.onShare(text),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: Text(S.current.Share),
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
