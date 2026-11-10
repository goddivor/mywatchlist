import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_profile.dart';

/// Follow or unfollow a Kitsu user. Reads the follow state once when built (a failed read hides
/// the button: the profile never reports a tracker error) and writes only when the viewer taps.
class KitsuFollowButton extends StatefulWidget {
  /// Kitsu id of the profile's user.
  final String userId;

  /// Replaced by tests with a fake-backed client.
  final KitsuProfiles? profiles;

  const KitsuFollowButton({super.key, required this.userId, this.profiles});

  @override
  State<KitsuFollowButton> createState() => _KitsuFollowButtonState();
}

class _KitsuFollowButtonState extends State<KitsuFollowButton> {
  KitsuProfiles get _api => widget.profiles ?? KitsuProfiles.instance;

  /// Whether the state is known; the button stays hidden until then.
  bool _known = false;
  String? _followId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    try {
      final id = await _api.followId(widget.userId);
      if (!mounted) return;
      setState(() {
        _followId = id;
        _known = true;
      });
    } catch (_) {
      // Unknown state: no button.
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final current = _followId;
      final next = current == null ? await _api.follow(widget.userId) : null;
      if (current != null) await _api.unfollow(current);
      if (!mounted) return;
      setState(() {
        _followId = next;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(S.current.Kf_Follow_Failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_known) return const SizedBox.shrink();
    final s = S.of(context);
    final following = _followId != null;
    final onPressed = _busy ? null : _toggle;
    return following
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(s.Kf_Following_Button),
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text(s.Kf_Follow),
          );
  }
}
