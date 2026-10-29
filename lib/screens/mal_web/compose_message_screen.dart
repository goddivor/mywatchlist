import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/mal_web/mal_web_form_errors.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_form_submitter.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/mal_web/message_tiles.dart';

/// Opens the compose screen, the recipient filled with [to] when given. Completes with true
/// once a message was sent.
Future<bool> openComposeMalMessage(BuildContext context, {String? to}) async {
  final sent = await AppRoutes.push<bool>(context, ComposeMalMessageScreen(to: to));
  return sent ?? false;
}

/// A new private message: recipient (friends first, then MAL's user search), subject, body.
class ComposeMalMessageScreen extends StatefulWidget {
  const ComposeMalMessageScreen({super.key, this.to, this.api, this.session});

  final String? to;
  final MalMessagesApi? api;
  final MalWebSession? session;

  @override
  State<ComposeMalMessageScreen> createState() => _ComposeMalMessageScreenState();
}

class _ComposeMalMessageScreenState extends State<ComposeMalMessageScreen> {
  late final TextEditingController _to = TextEditingController(text: widget.to ?? '');
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final FocusNode _toFocus = FocusNode();
  final FocusNode _subjectFocus = FocusNode();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  bool _sending = false;
  bool _sent = false;
  List<MalUserSuggestion> _friends = const [];
  int _search = 0;

  MalMessagesApi get _api => widget.api ?? MalMessagesApi.instance;
  MalWebSession get _session => widget.session ?? _api.client.session;

  bool get _dirty =>
      _subject.text.trim().isNotEmpty ||
      _body.text.trim().isNotEmpty ||
      (_to.text.trim().isNotEmpty && _to.text.trim() != (widget.to ?? '').trim());

  @override
  void initState() {
    super.initState();
    unawaited(_loadFriends());
    if ((widget.to ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _subjectFocus.requestFocus();
      });
    }
  }

  Future<void> _loadFriends() async {
    try {
      await _session.ensureLoaded();
      final friends = await _api.friends();
      if (mounted) setState(() => _friends = friends);
    } catch (_) {
      // Suggestions are optional: MAL's user search still answers.
    }
  }

  @override
  void dispose() {
    _to.dispose();
    _subject.dispose();
    _body.dispose();
    _toFocus.dispose();
    _subjectFocus.dispose();
    super.dispose();
  }

  Future<Iterable<MalUserSuggestion>> _suggest(TextEditingValue value) async {
    final q = value.text.trim().toLowerCase();
    final friends = q.isEmpty
        ? _friends
        : _friends.where((f) => f.name.toLowerCase().contains(q)).toList();
    if (q.length < 3 || friends.length >= 5) return friends.take(8);
    final generation = ++_search;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (generation != _search || !mounted) return friends.take(8);
    try {
      final found = await _api.searchUsers(q);
      final merged = <MalUserSuggestion>{...friends, ...found};
      return merged.take(8);
    } catch (_) {
      return friends.take(8);
    }
  }

  Future<void> _send() async {
    if (_sending || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
      await _api.send(to: _to.text, subject: _subject.text, body: _body.text);
      if (!mounted) return;
      _sent = true;
      showMessageSnack(context, S.current.Pm_Sent);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showMessageSnack(context, malFormErrorText(e));
    }
  }

  Future<void> _maybeLeave() async {
    final s = S.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(s.Pm_Discard_Confirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.Cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(s.Discard)),
        ],
      ),
    );
    if ((discard ?? false) && mounted) {
      _sent = true;
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_subject, _body, _to]),
      builder: (context, child) => PopScope(
        canPop: _sent || !_dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _maybeLeave();
        },
        child: child!,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.Pm_Compose),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      tooltip: s.Pm_Send,
                      icon: const Icon(Icons.send_rounded),
                      onPressed: _session.isConnected ? _send : null,
                    ),
            ),
          ],
        ),
        body: MalWebFormHost(
          child: MalSessionGate(
            session: _session,
            connected: (context) => _fields(context),
          ),
        ),
      ),
    );
  }

  Widget _fields(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final border = UnderlineInputBorder(borderSide: BorderSide(color: scheme.outlineVariant));
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          border: border,
          enabledBorder: border,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        );
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          RawAutocomplete<MalUserSuggestion>(
            textEditingController: _to,
            focusNode: _toFocus,
            displayStringForOption: (o) => o.name,
            optionsBuilder: _suggest,
            onSelected: (_) => _subjectFocus.requestFocus(),
            fieldViewBuilder: (context, controller, focus, onSubmit) => TextFormField(
              controller: controller,
              focusNode: focus,
              enabled: !_sending,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: deco(s.Pm_To),
              validator: (v) => (v ?? '').trim().isEmpty ? s.Pm_Recipient_Required : null,
              onFieldSubmitted: (_) => _subjectFocus.requestFocus(),
            ),
            optionsViewBuilder: (context, onSelected, options) => _Suggestions(
              options: options.toList(),
              onSelected: onSelected,
            ),
          ),
          TextFormField(
            controller: _subject,
            focusNode: _subjectFocus,
            enabled: !_sending,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: deco(s.Pm_Subject).copyWith(counterText: ''),
            validator: (v) => (v ?? '').trim().isEmpty ? s.Pm_Subject_Required : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _body,
            enabled: !_sending,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: s.Pm_Body,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
            validator: (v) => (v ?? '').trim().isEmpty ? s.Pm_Body_Required : null,
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.options, required this.onSelected});

  final List<MalUserSuggestion> options;
  final AutocompleteOnSelected<MalUserSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Material(
        elevation: 3,
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 280,
            maxWidth: MediaQuery.sizeOf(context).width - 32,
          ),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, i) {
              final o = options[i];
              return ListTile(
                dense: true,
                leading: ForumAvatar(username: o.name, url: o.imageUrl, size: 32, tappable: false),
                title: Text(o.name, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface)),
                trailing: o.isFriend
                    ? Icon(Icons.people_alt_outlined, size: 18, color: scheme.onSurfaceVariant, semanticLabel: s.Pm_Friend)
                    : null,
                onTap: () => onSelected(o),
              );
            },
          ),
        ),
      ),
    );
  }
}
