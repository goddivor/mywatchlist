import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// Previous / Next buttons around an optional "Page x of y" label.
class NextPreviousRow extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final int? page;
  final int? total;

  const NextPreviousRow({
    super.key,
    this.onPrevious,
    this.onNext,
    this.page,
    this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (onPrevious == null && onNext == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          label: Text(S.current.Fc_Previous),
        ),
        if (page != null && total != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              S.current.Fc_Page_Of(page!, total!),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onNext,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right),
          label: Text(S.current.Fc_Next),
        ),
      ],
    );
  }
}
