import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/user/list/cards/custom_entry_card.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Opens the custom card layouts page (DailyAL `ContentCustomizer`).
Future<void> openCardLayouts(BuildContext context, {ListEntryView? sample}) =>
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => CardLayoutsPage(sample: sample),
    ));

void _saveProfiles(BuildContext context, List<ContentCardProps> Function(List<ContentCardProps>) edit) {
  final event = ListPreferencesChanged((p) => p.copyWith(cardProfiles: edit(p.cardProfiles)));
  try {
    context.read<PreferencesBloc>().add(event);
  } on ProviderNotFoundException {
    Preferences.bloc?.add(event);
  }
}

List<ContentCardProps> _profilesOf(BuildContext context) {
  try {
    return context.select((PreferencesBloc b) => b.state.list.cardProfiles);
  } on ProviderNotFoundException {
    return Preferences.list.cardProfiles;
  }
}

/// The user's custom card layouts: add, edit, delete.
class CardLayoutsPage extends StatelessWidget {
  final ListEntryView? sample;
  const CardLayoutsPage({super.key, this.sample});

  @override
  Widget build(BuildContext context) {
    final profiles = _profilesOf(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(S.current.UserList_Custom_Cards)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(S.current.UserList_New_Card),
      ),
      body: profiles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dashboard_customize_outlined,
                        size: 48, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(S.current.UserList_Custom_Cards_Empty,
                        textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: profiles.length,
              itemBuilder: (context, i) {
                final p = profiles[i];
                return ListTile(
                  leading: const Icon(Icons.view_agenda_outlined),
                  title: Text(p.profileName.isEmpty ? S.current.UserList_Untitled_Card : p.profileName),
                  subtitle: Text(S.current.Tap_to_edit),
                  onTap: () => _edit(context, p),
                  trailing: IconButton(
                    tooltip: S.current.UserList_Delete_Card,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _delete(context, p),
                  ),
                );
              },
            ),
    );
  }

  /// A new card starts from a built-in style (Comfortable, Compact, Spacious) or the default
  /// custom layout.
  Future<void> _create(BuildContext context) async {
    final start = await showModalBottomSheet<_CardStart>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(S.current.Cps_Start_From, style: Theme.of(sheet).textTheme.titleMedium),
            ),
            for (final start in _CardStart.values)
              ListTile(
                key: ValueKey('card-start-${start.name}'),
                leading: Icon(start.icon),
                title: Text(start.label),
                onTap: () => Navigator.pop(sheet, start),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (start == null || !context.mounted) return;
    final base = start.style == null ? ContentCardProps.defaultObject() : builtInCardLayout(start.style!);
    await _edit(
      context,
      base.copyWith(
        id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        profileName: start.style == null ? S.current.UserList_New_Card : start.label,
      ),
    );
  }

  Future<void> _edit(BuildContext context, ContentCardProps props) async {
    final saved = await Navigator.of(context).push<ContentCardProps>(MaterialPageRoute(
      builder: (_) => CardLayoutEditor(props: props, sample: sample),
    ));
    if (saved == null || !context.mounted) return;
    _saveProfiles(context, (list) {
      final next = [...list];
      final index = next.indexWhere((p) => p.id == saved.id);
      if (index >= 0) {
        next[index] = saved;
      } else {
        next.add(saved);
      }
      return next;
    });
  }

  Future<void> _delete(BuildContext context, ContentCardProps props) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.current.UserList_Delete_Card),
        content: Text(S.current.UserList_Delete_Card_Confirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(S.current.Cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true), child: Text(S.current.UserList_Delete)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    _saveProfiles(context, (list) => list.where((p) => p.id != props.id).toList());
  }
}

/// Where a new card starts.
enum _CardStart {
  comfortable(BuiltInCardStyle.comfortable, Icons.view_agenda_outlined),
  compact(BuiltInCardStyle.compact, Icons.view_headline_rounded),
  spacious(BuiltInCardStyle.spacious, Icons.view_day_outlined),
  blank(null, Icons.dashboard_customize_outlined);

  const _CardStart(this.style, this.icon);
  final BuiltInCardStyle? style;
  final IconData icon;

  String get label => switch (this) {
        _CardStart.comfortable => S.current.UserList_Comfortable,
        _CardStart.compact => S.current.UserList_Compact,
        _CardStart.spacious => S.current.UserList_Spacious,
        _CardStart.blank => S.current.Cps_Default_Card,
      };
}

/// Edits one card layout on a live preview; pops with the layout on save.
class CardLayoutEditor extends StatefulWidget {
  final ContentCardProps props;
  final ListEntryView? sample;

  const CardLayoutEditor({super.key, required this.props, this.sample});

  @override
  State<CardLayoutEditor> createState() => _CardLayoutEditorState();
}

class _CardLayoutEditorState extends State<CardLayoutEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.props.profileName);
  late List<CustomizableField> _fields = _completeFields(widget.props.fields);
  late double _height = widget.props.height.clamp(_minHeight, _maxHeight).toDouble();
  late double _imageWidth = widget.props.imageWidth;

  static const double _minHeight = 48;
  static const double _maxHeight = 260;
  CustomizableFieldType? _selected;
  bool _changed = false;

  static const double _step = 4;

  /// Every field type once, saved ones first in their order (a type added by
  /// a later version appears hidden at its default place).
  static List<CustomizableField> _completeFields(List<CustomizableField> saved) {
    final seen = <CustomizableFieldType>{};
    final result = <CustomizableField>[];
    for (final f in saved) {
      if (seen.add(f.type)) result.add(f);
    }
    for (final d in defaultCustomizableFields) {
      if (seen.add(d.type)) result.add(d.copyWith(hidden: true));
    }
    return result;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  ListEntryView get _sample =>
      widget.sample ??
      ListEntryView(
        id: 0,
        category: 'anime',
        title: S.current.UserList_Sample_Title,
        mediaType: 'tv',
        releaseState: ReleaseState.releasing,
        meanScore: 8.42,
        members: 512000,
        total: 24,
        episodeSeconds: 24 * 60,
        genres: const ['Action', 'Fantasy'],
        releaseStart: DateTime.now().subtract(const Duration(days: 40)).toIso8601String().substring(0, 10),
        broadcast: const BroadcastSlot(DateTime.saturday, 23 * 60),
        status: ListEntryStatus.current,
        score: 9,
        progress: 4,
        priority: 2,
      );

  void _update(CustomizableFieldType type, CustomizableField Function(CustomizableField) edit) {
    setState(() {
      _changed = true;
      _fields = [for (final f in _fields) f.type == type ? edit(f) : f];
    });
  }

  void _move(CustomizableFieldType type, Offset delta) {
    _update(type, (f) {
      final p = f.position;
      double? clampV(double? v) => v?.clamp(-40.0, 600.0);
      return f.copyWith(
        position: FieldPosition(
          top: clampV(p.top == null ? null : p.top! + delta.dy),
          bottom: clampV(p.bottom == null ? null : p.bottom! - delta.dy),
          left: clampV(p.left == null ? null : p.left! + delta.dx),
          right: clampV(p.right == null ? null : p.right! - delta.dx),
        ),
      );
    });
  }

  void _reorder(CustomizableFieldType type, int by) {
    final i = _fields.indexWhere((f) => f.type == type);
    final j = i + by;
    if (i < 0 || j < 0 || j >= _fields.length) return;
    setState(() {
      _changed = true;
      final next = [..._fields];
      final f = next.removeAt(i);
      next.insert(j, f);
      _fields = next;
    });
  }

  ContentCardProps get _result => widget.props.copyWith(
        profileName: _name.text.trim(),
        height: _height,
        fields: _fields,
        imageWidth: _imageWidth,
      );

  Future<bool> _confirmDiscard() async {
    if (!_changed) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.current.UserList_Discard_Changes),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(S.current.Cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(S.current.UserList_Discard)),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final selected = _selected == null
        ? null
        : _fields.firstWhere((f) => f.type == _selected, orElse: () => _fields.first);
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(S.current.UserList_Edit_Card),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_result),
              child: Text(S.current.UserList_Save),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: S.current.UserList_Card_Name,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _changed = true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(S.current.UserList_Card_Height(_height.round()),
                  style: theme.textTheme.titleSmall),
            ),
            Slider(
              value: _height,
              min: _minHeight,
              max: _maxHeight,
              divisions: ((_maxHeight - _minHeight) / 4).round(),
              label: '${_height.round()}',
              onChanged: (v) => setState(() {
                _changed = true;
                _height = v;
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(S.current.Cps_Cover_Width(_imageWidth.round()),
                  style: theme.textTheme.titleSmall),
            ),
            Slider(
              key: const ValueKey('card-cover-width'),
              value: _imageWidth,
              min: ContentCardProps.minImageWidth,
              max: ContentCardProps.maxImageWidth,
              divisions: ((ContentCardProps.maxImageWidth - ContentCardProps.minImageWidth) / 4).round(),
              label: '${_imageWidth.round()}',
              onChanged: (v) => setState(() {
                _changed = true;
                _imageWidth = v;
              }),
            ),
            CustomEntryCard(
              props: _result,
              entry: _sample,
              now: DateTime.now(),
              locale: locale,
              fields: _fields,
              selected: _selected,
              onFieldTap: (t) => setState(() => _selected = _selected == t ? null : t),
              onFieldDrag: _move,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                _selected == null ? S.current.Tap_to_select : S.current.UserList_Drag_Hint,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in _fields)
                    ChoiceChip(
                      label: Text(f.type.label),
                      avatar: Icon(f.hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 16),
                      selected: _selected == f.type,
                      tooltip: f.type.description,
                      onSelected: (_) =>
                          setState(() => _selected = _selected == f.type ? null : f.type),
                    ),
                ],
              ),
            ),
            if (selected != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(selected.type.label, style: theme.textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  IconButton.filledTonal(
                    tooltip: S.current.UserList_Move_Up,
                    onPressed: () => _move(selected.type, const Offset(0, -_step)),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                  IconButton.filledTonal(
                    tooltip: S.current.UserList_Move_Down,
                    onPressed: () => _move(selected.type, const Offset(0, _step)),
                    icon: const Icon(Icons.arrow_downward_rounded),
                  ),
                  IconButton.filledTonal(
                    tooltip: S.current.UserList_Move_Left,
                    onPressed: () => _move(selected.type, const Offset(-_step, 0)),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  IconButton.filledTonal(
                    tooltip: S.current.UserList_Move_Right,
                    onPressed: () => _move(selected.type, const Offset(_step, 0)),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: Text(selected.hidden ? S.current.UserList_Show_Field : S.current.UserList_Hide_Field),
                    avatar: Icon(selected.hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        size: 18),
                    selected: false,
                    onSelected: (_) =>
                        _update(selected.type, (f) => f.copyWith(hidden: !f.hidden)),
                  ),
                  ActionChip(
                    label: Text(S.current.UserList_Bring_Forward),
                    avatar: const Icon(Icons.flip_to_front_rounded, size: 18),
                    onPressed: () => _reorder(selected.type, 1),
                  ),
                  ActionChip(
                    label: Text(S.current.UserList_Send_Backward),
                    avatar: const Icon(Icons.flip_to_back_rounded, size: 18),
                    onPressed: () => _reorder(selected.type, -1),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
