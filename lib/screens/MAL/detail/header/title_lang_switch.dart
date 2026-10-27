import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show TitleLang;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';

/// Three-segment switch (romaji / English / Japanese) on the cover.
/// The page starts on `Preferences.general.preferredTitle`; a tap only
/// changes this page.
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
    return Semantics(
      label: s.Detail_Title_Language,
      child: SizedBox(
        height: 25,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _segment(TitleLang.ro, s.Detail_Title_Romaji,
                const BorderRadius.horizontal(left: Radius.circular(12))),
            _segment(TitleLang.en, s.Detail_Title_English,
                BorderRadius.circular(4.0)),
            _segment(TitleLang.ja, s.Detail_Title_Japanese,
                const BorderRadius.horizontal(right: Radius.circular(12))),
          ],
        ),
      ),
    );
  }

  Widget _segment(TitleLang lang, String label, BorderRadius radius) {
    final selected = value == lang;
    return SizedBox(
      width: 30,
      child: ShadowButton(
        padding: EdgeInsets.zero,
        backgroundColor: selected ? null : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        onPressed: () => onChanged(lang),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: selected ? null : Colors.white),
        ),
      ),
    );
  }
}
