import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';

/// AniList's list statuses (`MediaListStatus`) in the order of AniList's own picker.
const List<String> anilistStatuses = [
  'CURRENT',
  'PLANNING',
  'COMPLETED',
  'REPEATING',
  'PAUSED',
  'DROPPED',
];

/// Translated label of an AniList status ("Rewatching" / "Rereading" for REPEATING).
String anilistStatusLabel(String? status, {required bool isAnime}) => switch (status) {
      'CURRENT' => isAnime ? S.current.Edit_Watching : S.current.Edit_Reading,
      'REPEATING' => isAnime ? S.current.Edit_Rewatching : S.current.Edit_Rereading,
      'COMPLETED' => S.current.Edit_Completed,
      'PAUSED' => S.current.Alf_Status_Paused,
      'DROPPED' => S.current.Edit_Dropped,
      'PLANNING' => isAnime ? S.current.Edit_Plan_To_Watch : S.current.Edit_Plan_To_Read,
      _ => S.current.Alf_Not_On_List,
    };

/// Colour of an AniList status (the theme's status tokens; Rewatching as Watching).
Color anilistStatusColor(BuildContext context, String? status) {
  final mal = switch (status) {
    'CURRENT' || 'REPEATING' => 'watching',
    'COMPLETED' => 'completed',
    'PAUSED' => 'on_hold',
    'DROPPED' => 'dropped',
    'PLANNING' => 'plan_to_watch',
    _ => null,
  };
  return AppColors.of(context).statusOf(mal)?.color ?? Theme.of(context).colorScheme.outline;
}

/// Tonal button showing an AniList status; opens the picker of [anilistStatuses].
class AnilistStatusButton extends StatelessWidget {
  final String? status;
  final bool isAnime;
  final bool busy;
  final ValueChanged<String> onChanged;

  const AnilistStatusButton({
    super.key,
    required this.status,
    required this.isAnime,
    required this.onChanged,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: busy ? null : () => _pick(context),
        child: Row(
          children: [
            _Dot(color: anilistStatusColor(context, status), size: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                anilistStatusLabel(status, isAnime: isAnime),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await pickAnilistStatus(context, current: status, isAnime: isAnime);
    if (picked != null && picked != status) onChanged(picked);
  }
}

/// Sheet listing [anilistStatuses]; answers the picked one, null when dismissed.
Future<String?> pickAnilistStatus(BuildContext context,
    {String? current, required bool isAnime}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(S.current.Status, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final value in anilistStatuses)
              ListTile(
                leading: _Dot(color: anilistStatusColor(ctx, value), size: 12),
                title: Text(anilistStatusLabel(value, isAnime: isAnime)),
                selected: value == current,
                trailing: value == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
