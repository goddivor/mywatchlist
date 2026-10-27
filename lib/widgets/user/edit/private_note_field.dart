import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/private_notes/private_notes_store.dart';

/// Whether the private note is shown: the `showPrivateNotes` preference,
/// watched on [PreferencesBloc] when one is provided.
bool watchShowPrivateNotes(BuildContext context) =>
    context.select<PreferencesBloc?, bool>((bloc) =>
        (bloc?.state ?? Preferences.current).content.showPrivateNotes);

/// Local-only note of one entry (DAL e773650): loaded from
/// [PrivateNotesStore], saved shortly after typing stops and when the sheet
/// closes. Never sent to a tracker.
class PrivateNoteField extends StatefulWidget {
  final int id;
  final String category;
  final PrivateNotesStore? store;

  const PrivateNoteField({
    super.key,
    required this.id,
    required this.category,
    this.store,
  });

  @override
  State<PrivateNoteField> createState() => _PrivateNoteFieldState();
}

class _PrivateNoteFieldState extends State<PrivateNoteField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool _dirty = false;
  bool _loaded = false;

  PrivateNotesStore get _store => widget.store ?? PrivateNotesStore.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final note = await _store.read(widget.id, widget.category);
    if (!mounted) return;
    // Text typed before the note arrived wins.
    if (!_dirty && note != null) _controller.text = note;
    setState(() => _loaded = true);
  }

  void _onChanged(String _) {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    if (!_dirty) return;
    _dirty = false;
    await _store.write(widget.id, widget.category, _controller.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_dirty) {
      // Fire and forget: the store does not need the widget.
      _store.write(widget.id, widget.category, _controller.text);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('edit-private-note'),
      controller: _controller,
      enabled: _loaded,
      minLines: 3,
      maxLines: 8,
      keyboardType: TextInputType.multiline,
      onChanged: _onChanged,
      decoration: InputDecoration(
        hintText: S.current.Private_Note_Hint,
        helperText: S.current.Private_Note_Local_Only,
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.lock_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
