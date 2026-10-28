import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/widgets/forum/forum_topic_widget.dart';

import 'package:mywatchlist/generated/l10n.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('topic row has a regular-weight title and one meta line', (tester) async {
    final topic = ForumTopicsData(id: 1, title: 'Hello topic', numberOfPosts: 3);
    await S.load(const Locale('en'));
    await pumpInApp(tester, ForumTopicWidget(topic: topic));
    final title = tester.widget<Text>(find.text('Hello topic'));
    expect(title.style?.fontWeight, FontWeight.w400);
    expect(find.text('3 posts'), findsOneWidget);
  });
}
