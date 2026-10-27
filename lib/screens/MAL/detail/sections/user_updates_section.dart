import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/content/userupdate_widget.dart';

/// Recent list updates of other users.
DetailSection? userUpdatesSection(DetailData data) {
  if (!data.hasContent) return null;
  return DetailSection(
    TabType.User_Updates,
    UserUpdatesPage(
      horizPadding: detailHorizPadding,
      category: data.category,
      id: data.id,
    ),
  );
}
