import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show showToast;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/frames/avatar_frames.dart';

/// Lets the signed-in MAL user pick the frame of their avatar among the frames granted to
/// them, or none.
Future<void> showAvatarFrameSheet(BuildContext context, {required String username, AvatarFrames? frames}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => AvatarFrameSheet(username: username, frames: frames ?? AvatarFrames.instance),
  );
}

class AvatarFrameSheet extends StatefulWidget {
  final String username;
  final AvatarFrames frames;

  const AvatarFrameSheet({super.key, required this.username, required this.frames});

  @override
  State<AvatarFrameSheet> createState() => _AvatarFrameSheetState();
}

class _AvatarFrameSheetState extends State<AvatarFrameSheet> {
  MyFrames? _mine;
  bool _loading = true;
  bool _failed = false;
  String? _saving;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mine = await widget.frames.mine();
    if (!mounted) return;
    setState(() {
      _mine = mine;
      _failed = mine == null;
      _loading = false;
    });
  }

  Future<void> _wear(String? frameId) async {
    if (_saving != null || frameId == _mine?.equipped) return;
    setState(() => _saving = frameId ?? '');
    final result = await widget.frames.equip(frameId, username: widget.username);
    if (!mounted) return;
    setState(() {
      _saving = null;
      if (result != null) _mine = result;
    });
    showToast(result != null ? S.current.Afr_Saved : S.current.Afr_Error);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final mine = _mine;
    final Widget body;
    if (_loading) {
      body = const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
    } else if (_failed || mine == null) {
      body = _Message(s.Afr_Error);
    } else if (mine.available.isEmpty) {
      body = _Message(s.Afr_Empty);
    } else {
      final date = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Choice(
            selected: mine.equipped == null,
            busy: _saving == '',
            leading: Icon(Icons.block_rounded, color: theme.colorScheme.onSurfaceVariant),
            title: s.Afr_None,
            onTap: () => _wear(null),
          ),
          for (final owned in mine.available)
            _Choice(
              selected: mine.equipped == owned.frame.id,
              busy: _saving == owned.frame.id,
              leading: Image(
                image: CachedNetworkImageProvider(owned.frame.imageUrl),
                width: 48,
                height: 48,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48),
              ),
              title: owned.name,
              subtitle: owned.expiresAt == null ? null : s.Afr_Until(date.format(owned.expiresAt!.toLocal())),
              onTap: () => _wear(owned.frame.id),
            ),
        ],
      );
    }
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(s.Afr_Title, style: theme.textTheme.titleLarge),
          ),
          body,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final bool selected;
  final bool busy;
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _Choice({
    required this.selected,
    required this.busy,
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: SizedBox(width: 48, height: 48, child: Center(child: leading)),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      selected: selected,
      trailing: busy
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : selected
              ? Icon(Icons.check_circle_rounded, color: scheme.primary)
              : null,
      onTap: onTap,
    );
  }
}

class _Message extends StatelessWidget {
  final String text;

  const _Message(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      );
}
