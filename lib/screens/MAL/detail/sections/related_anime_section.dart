import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';

/// EXTENSION POINT: "Related Anime" of a manga page (DAL shows the anime
/// adaptations of a manga here). MWL already lists them in the Related
/// section, so this stays empty until a detail unit gives it its own body.
DetailSection? relatedAnimeSection(DetailData data) => null;
