import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/content/animepictures.dart';

/// Official pictures.
DetailSection? picturesSection(DetailData data) {
  final content = data.content;
  if (content == null) return null;
  return DetailSection(
    TabType.Pictures,
    AnimePictures(pictures: content.pictures ?? const []),
  );
}
