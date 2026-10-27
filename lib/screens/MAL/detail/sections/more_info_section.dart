import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/content/more_info_widget.dart';

/// Every other field (dates, source, rating, titles…). Same body as the
/// More Info modal of the header (`actions/more_info_modal.dart`).
DetailSection? moreInfoSection(DetailData data) {
  final content = data.content;
  if (content == null) return null;
  return DetailSection(
    TabType.More_Info,
    MoreInfoWidget(
      anime: content,
      additionalTitles: data.html?['additionalTitles'],
      horizPadding: detailHorizPadding,
      category: data.category,
    ),
  );
}
