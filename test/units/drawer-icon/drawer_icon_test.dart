import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tracker app bars do not show the automatic endDrawer button',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        endDrawer: const Drawer(),
        body: CustomScrollView(slivers: [
          // Same pattern as the Anilist/Kitsu/Simkl home and explore pages.
          SliverAppBar(
            automaticallyImplyLeading: false,
            actions: const [SizedBox.shrink()],
            floating: true,
            title: const Text('Explore'),
          ),
        ]),
      ),
    ));
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('control: without the placeholder the button appears',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        endDrawer: const Drawer(),
        body: CustomScrollView(slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            floating: true,
            title: const Text('Explore'),
          ),
        ]),
      ),
    ));
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });
}
