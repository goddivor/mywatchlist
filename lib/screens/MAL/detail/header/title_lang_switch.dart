import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/constants/constants.dart' show TitleLang;
import 'package:mywatchlist/generated/l10n.dart';

/// Three-segment switch (romaji / English / Japanese) on the cover.
/// The page starts on `Preferences.general.preferredTitle` (and follows it
/// when it changes); a tap only changes this page.
class TitleLangSwitch extends StatelessWidget {
  final TitleLang value;
  final ValueChanged<TitleLang> onChanged;

  const TitleLangSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final scheme = Theme.of(context).colorScheme;
    final tokens = AppColors.of(context);
    return Semantics(
      label: s.Dh_Title_Language,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.imageScrim,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _segment(scheme, tokens, TitleLang.ro, s.Dh_Lang_Romaji, s.Dh_Lang_Romaji_Long),
              _segment(scheme, tokens, TitleLang.en, s.Dh_Lang_English, s.Dh_Lang_English_Long),
              _segment(scheme, tokens, TitleLang.ja, s.Dh_Lang_Japanese, s.Dh_Lang_Japanese_Long),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segment(ColorScheme scheme, AppColors tokens, TitleLang lang, String label, String semantics) {
    final selected = value == lang;
    return Semantics(
      button: true,
      selected: selected,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected ? null : () => onChanged(lang),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 34, minHeight: 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? scheme.primary : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? scheme.onPrimary : tokens.onImageScrim,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
