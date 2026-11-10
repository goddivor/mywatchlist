import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/MAL/content/more_info_widget.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() => S.load(const Locale('en')));

  final anime = MalAnime(
    id: 1,
    title: 'Cowboy Bebop',
    mediaType: 'tv',
    status: 'finished_airing',
    genres: [Genre(id: 1, name: 'Action'), Genre(id: 2, name: 'Adventure')],
    studios: [Studio(id: 14, name: 'Sunrise')],
  );

  testWidgets('studios, genres and media type are tappable chips', (tester) async {
    await pumpInApp(tester, MoreInfoWidget(anime: anime, horizPadding: 8));
    expect(find.widgetWithText(ActionChip, 'Sunrise'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Action'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'TV'), findsOneWidget);
    expect(find.text('Finished airing'), findsOneWidget);
  });

  testWidgets('modal mode owns its scroll view', (tester) async {
    await pumpInApp(tester, MoreInfoWidget(anime: anime, horizPadding: 8, isModal: true));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await pumpInApp(tester, MoreInfoWidget(anime: anime, horizPadding: 8));
    expect(find.byType(SingleChildScrollView), findsNothing);
  });
}
