import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/user/edit/edit_labels.dart';

void main() {
  test('French priority, rewatch value and score labels (#117)', () async {
    await S.load(const Locale('fr', 'FR'));
    expect([0, 1, 2].map(priorityLabel), ['Faible', 'Moyenne', 'Haute']);
    expect([1, 2, 3, 4, 5].map(repeatValueLabel), ['Très faible', 'Faible', 'Moyenne', 'Haute', 'Très haute']);
    expect(S.current.Esl_Score, 'Note');
    expect(scoreLabel(6), isNot(scoreLabel(7)));
  });

  test('English stays as before', () async {
    await S.load(const Locale('en'));
    expect([0, 1, 2].map(priorityLabel), ['Low', 'Medium', 'High']);
    expect(repeatValueLabel(1), 'Very low');
    expect(S.current.Esl_Score, 'Score');
    expect(scoreLabel(6), 'Fine');
  });
}
