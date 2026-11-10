import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart' show AnilistFollowState;
import 'package:mywatchlist/services/api/Anilist/anilist_follow_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart'
    show AnilistSocialService;
import 'package:mywatchlist/widgets/Anilist/social/anilist_composer.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// A round user picture with the user's initial while it loads or when there is none.
class AnilistAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;

  const AnilistAvatar({super.key, required this.name, this.url, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: ColoredBox(
          color: cs.secondaryContainer,
          child: url == null || url!.isEmpty
              ? Center(
                  child: Text(initial,
                      style: TextStyle(
                          fontSize: size * 0.42,
                          fontWeight: FontWeight.w600,
                          color: cs.onSecondaryContainer)),
                )
              : AppImage(
                  url: url,
                  width: size,
                  height: size,
                  placeholderColor: cs.secondaryContainer,
                ),
        ),
      ),
    );
  }
}

/// Follow / Following for user [userId]. Taps are the viewer's own: one `ToggleFollow` per
/// tap, the button shows what AniList answered. Without an account it offers to sign in.
class AnilistFollowButton extends StatefulWidget {
  final int userId;
  final bool isFollowing;
  final ValueChanged<AnilistFollowState>? onChanged;
  final AnilistFollowService? service;

  /// A smaller button for list rows.
  final bool compact;

  const AnilistFollowButton({
    super.key,
    required this.userId,
    required this.isFollowing,
    this.onChanged,
    this.service,
    this.compact = false,
  });

  @override
  State<AnilistFollowButton> createState() => _AnilistFollowButtonState();
}

class _AnilistFollowButtonState extends State<AnilistFollowButton> {
  late bool _following = widget.isFollowing;
  bool _busy = false;

  AnilistFollowService get _service => widget.service ?? AnilistFollowService.instance;

  @override
  void didUpdateWidget(AnilistFollowButton old) {
    super.didUpdateWidget(old);
    if (old.isFollowing != widget.isFollowing || old.userId != widget.userId) {
      _following = widget.isFollowing;
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    final state = await runAnilistWrite<AnilistFollowState>(
      context,
      () => _service.toggleFollow(widget.userId),
      service: AnilistSocialService(signedIn: _service.signedIn),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (state != null) _following = state.isFollowing;
    });
    if (state != null) widget.onChanged?.call(state);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final style = widget.compact
        ? const ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
          )
        : null;
    final label = Text(_following ? s.Alpp_Following : s.Alpp_Follow);
    final onPressed = _busy ? null : _toggle;
    return _following
        ? OutlinedButton(onPressed: onPressed, style: style, child: label)
        : FilledButton(onPressed: onPressed, style: style, child: label);
  }
}

/// Opens the composer to write a message on [name]'s profile (`SaveMessageActivity`). The
/// message is sent only when the viewer taps send.
Future<bool> showAnilistMessage(
  BuildContext context, {
  required int recipientId,
  required String name,
  AnilistFollowService? service,
}) {
  final follow = service ?? AnilistFollowService.instance;
  return showAnilistComposer(
    context,
    title: S.of(context).Alpp_Message_To(name),
    service: AnilistSocialService(signedIn: follow.signedIn),
    submit: (text) async {
      await follow.sendMessage(recipientId, text);
      return true;
    },
  );
}
