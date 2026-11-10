import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// The title row of a home section. With [onTap] the whole row opens the full list ("View all").
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 22,
                color: theme.colorScheme.onSurfaceVariant,
                semanticLabel: S.current.Hw_View_All,
                textDirection: Directionality.of(context),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
