import 'package:flutter/material.dart';

/// AniList's named profile colours (`options.profileColor`), as anilist.co draws them. They
/// are the user's own choice of accent, data and not theme tokens.
const Map<String, Color> _named = {
  'blue': Color(0xFF3DB4F2),
  'purple': Color(0xFFC063FF),
  'pink': Color(0xFFFC9DD6),
  'orange': Color(0xFFEF881A),
  'red': Color(0xFFE13333),
  'green': Color(0xFF4CCA51),
  'gray': Color(0xFF677B94),
};

/// The colour of a profile: a named AniList colour or a `#rrggbb` hex; null for none.
Color? anilistProfileColor(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == null || text.isEmpty) return null;
  final named = _named[text];
  if (named != null) return named;
  final hex = RegExp(r'^#?([0-9a-f]{6})$').firstMatch(text);
  if (hex == null) return null;
  return Color(0xFF000000 | int.parse(hex.group(1)!, radix: 16));
}

/// [accent] made legible on the page: when it is too close to the surface in lightness it is
/// blended towards the text colour until it reads (a pink accent on white, a gray on black).
Color anilistReadableAccent(Color accent, ColorScheme scheme) {
  var color = accent;
  for (var i = 0; i < 6; i++) {
    final a = color.computeLuminance();
    final b = scheme.surface.computeLuminance();
    final ratio = (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
    if (ratio >= 3) break;
    color = Color.lerp(color, scheme.onSurface, 0.2)!;
  }
  return color;
}

/// Text colour for content drawn on [background]: the page surface or the page text colour,
/// whichever contrasts more.
Color anilistOn(Color background, ColorScheme scheme) {
  double ratio(Color c) {
    final a = background.computeLuminance(), b = c.computeLuminance();
    return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
  }

  return ratio(scheme.onSurface) >= ratio(scheme.surface) ? scheme.onSurface : scheme.surface;
}
