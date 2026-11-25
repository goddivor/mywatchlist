import 'package:flutter/material.dart';
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
    // DailyAL's switch: three small buttons side by side, no frame; the chosen one is a raised
    // dark button with the text in the main colour, rounded on its outer side.
    return Semantics(
      label: s.Dh_Title_Language,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(scheme, TitleLang.ro, s.Dh_Lang_Romaji, s.Dh_Lang_Romaji_Long,
              const BorderRadius.horizontal(left: Radius.circular(12))),
          _segment(scheme, TitleLang.en, s.Dh_Lang_English, s.Dh_Lang_English_Long,
              const BorderRadius.all(Radius.circular(4))),
          _segment(scheme, TitleLang.ja, s.Dh_Lang_Japanese, s.Dh_Lang_Japanese_Long,
              const BorderRadius.horizontal(right: Radius.circular(12))),
        ],
      ),
    );
  }

  static const double segmentWidth = 30;
  static const double segmentHeight = 25;

  Widget _segment(ColorScheme scheme, TitleLang lang, String label, String semantics, BorderRadius radius) {
    final selected = value == lang;
    return Semantics(
      button: true,
      selected: selected,
      label: semantics,
      excludeSemantics: true,
      child: SizedBox(
        width: segmentWidth,
        height: segmentHeight,
        child: Material(
          // DailyAL's ElevatedButton colours: a dark surface with the text in the main colour.
          color: selected ? scheme.surfaceContainerLow : Colors.transparent,
          elevation: selected ? 2 : 0,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: selected ? null : () => onChanged(lang),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? scheme.primary : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
