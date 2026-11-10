import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/actions/more_info_modal.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/MAL/content/more_info_widget.dart';

import '../../helpers/no_network.dart';
import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  testWidgets('More Info dialog: one scroll view, owned by MoreInfoWidget (#134)', (tester) async {
    final data = DetailData(
      id: 1,
      category: 'anime',
      content: MalAnime(id: 1, title: 'Cowboy Bebop', mediaType: 'tv', status: 'finished_airing'),
      state: DetailLoadState.loaded,
    );
    await pumpInApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showMoreInfoModal(context, data),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final widget = tester.widget<MoreInfoWidget>(find.byType(MoreInfoWidget));
    expect(widget.isModal, isTrue);
    expect(
      find.descendant(of: dialog, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
  });
}
