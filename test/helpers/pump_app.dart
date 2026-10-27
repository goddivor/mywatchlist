import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside a minimal [MaterialApp] + [Scaffold], centred.
///
/// Use it for widget tests of small, self-contained MWL widgets that need a
/// Material ancestor (ink, theme, directionality) but no app state.
Future<void> pumpInApp(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}
