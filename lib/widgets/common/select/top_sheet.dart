import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/common/select/select_option.dart';

/// Ease-out curve shared by the kit's motion (fast start, soft landing).
const Curve kKitEaseOut = Cubic(0.23, 1, 0.32, 1);

/// Shows [child] in a card that slides down from the top of the screen, over a
/// dimmed barrier; tapping outside dismisses it. Completes with the value the
/// child pops (`Navigator.pop(context, value)`), or null when dismissed.
///
/// ```dart
/// showTopSheet(context: context, child: TopSelectSheet(options: seasons, …));
/// ```
Future<T?> showTopSheet<T>({required BuildContext context, required Widget child}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) => SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.7,
            ),
            child: Material(
              color: Theme.of(dialogContext).colorScheme.surfaceContainerHigh,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(24),
              child: child,
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: kKitEaseOut, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.15), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Body for [showTopSheet]: an optional [title] and [options] as wrapped chips,
/// the [selected] one filled. Tapping a chip pops the sheet with its value.
class TopSelectSheet<T> extends StatelessWidget {
  final List<SelectOption<T>> options;
  final T? selected;
  final String? title;

  const TopSelectSheet({super.key, required this.options, this.selected, this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(title!, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  avatar: option.icon == null ? null : Icon(option.icon, size: 18),
                  label: Text(option.label),
                  selected: option.value == selected,
                  showCheckmark: false,
                  onSelected: (_) => Navigator.of(context).pop(option.value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
