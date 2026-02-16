import 'package:flutter/material.dart';

class NextPreviousRow extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const NextPreviousRow({super.key, this.onPrevious, this.onNext});

  @override
  Widget build(BuildContext context) {
    if (onPrevious == null && onNext == null) return const SizedBox();

    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (onPrevious != null)
          FilledButton.tonal(
            onPressed: onPrevious,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  left: const Radius.circular(20),
                  right: onNext != null
                      ? Radius.zero
                      : const Radius.circular(20),
                ),
              ),
            ),
            child: Text('Previous',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
        if (onNext != null)
          FilledButton.tonal(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  left: onPrevious != null
                      ? Radius.zero
                      : const Radius.circular(20),
                  right: const Radius.circular(20),
                ),
              ),
            ),
            child: Text('Next',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
      ],
    );
  }
}
