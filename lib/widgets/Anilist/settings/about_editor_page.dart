import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_settings_service.dart';

/// Edits the AniList "about" text (markdown) with a preview rendered by AniList's own
/// `Markdown` query, and the donator badge text when the account has one.
/// [onSave] saves and returns normally on success; it throws to keep the editor open.
class AboutEditorPage extends StatefulWidget {
  final AnilistSettings settings;
  final AnilistSettingsService service;
  final Future<void> Function(String about, String? badge) onSave;

  const AboutEditorPage({
    super.key,
    required this.settings,
    required this.service,
    required this.onSave,
  });

  @override
  State<AboutEditorPage> createState() => _AboutEditorPageState();
}

class _AboutEditorPageState extends State<AboutEditorPage> with SingleTickerProviderStateMixin {
  late final TextEditingController _about = TextEditingController(text: widget.settings.about);
  late final TextEditingController _badge = TextEditingController(text: widget.settings.donatorBadge);
  late final TabController _tabs = TabController(length: 2, vsync: this)..addListener(_onTab);
  Future<String>? _preview;
  bool _saving = false;

  @override
  void dispose() {
    _tabs.dispose();
    _about.dispose();
    _badge.dispose();
    super.dispose();
  }

  void _onTab() {
    if (_tabs.indexIsChanging || _tabs.index != 1) return;
    FocusScope.of(context).unfocus();
    setState(() => _preview = widget.service.previewMarkdown(_about.text));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _about.text,
        widget.settings.donatorTier > 0 ? _badge.text.trim() : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.Als_About),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(S.current.Save)),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [Tab(text: S.current.Als_About_Write), Tab(text: S.current.Preview)],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _about,
                minLines: 10,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: S.current.Als_About_Hint,
                ),
              ),
              if (widget.settings.donatorTier > 0) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _badge,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: S.current.Als_Donator_Badge,
                  ),
                ),
              ],
            ],
          ),
          FutureBuilder<String>(
            future: _preview,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return _preview == null
                    ? const SizedBox.shrink()
                    : const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    S.current.Als_Preview_Failed,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                );
              }
              final html = snap.data ?? '';
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  html.isEmpty
                      ? Text(S.current.Als_About_Empty,
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
                      : HtmlWidget(html),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
