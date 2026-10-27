import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/select/select.dart';

import '../../helpers/pump_app.dart';

const _sorts = [
  SelectOption('score', 'Score'),
  SelectOption('title', 'Title'),
  SelectOption('date', 'Date'),
];

/// Holds the selected value like a screen would.
class _Host extends StatefulWidget {
  final SelectMode mode;
  const _Host(this.mode);

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? value;

  @override
  Widget build(BuildContext context) => SelectButton<String>(
        title: 'Sort',
        mode: widget.mode,
        options: _sorts,
        selected: value,
        onChanged: (v) => setState(() => value = v),
      );
}

void main() {
  setUpAll(() => S.load(const Locale('en')));

  for (final mode in SelectMode.values) {
    testWidgets('SelectButton ($mode) shows Select, then the picked label', (tester) async {
      await pumpInApp(tester, _Host(mode));
      expect(find.text('Select'), findsOneWidget);
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Title').last);
      await tester.pumpAndSettle();
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Select'), findsNothing);
    });
  }

  testWidgets('showSelectSheet switches to search for long lists', (tester) async {
    final many = [for (var i = 0; i < 40; i++) SelectOption(i, i == 33 ? 'Shōnen' : 'Genre $i')];
    int? picked;
    await pumpInApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await showSelectSheet(context, options: many),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchableSelect<int>), findsOneWidget);
    expect(find.text('40 options'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'shonen');
    await tester.pump();
    expect(find.text('1 option'), findsOneWidget);
    await tester.tap(find.text('Shōnen'));
    await tester.pumpAndSettle();
    expect(picked, 33);
  });

  testWidgets('SearchableSelect shows an empty state', (tester) async {
    await pumpInApp(
      tester,
      SizedBox(height: 400, child: SearchableSelect<String>(options: _sorts, onSelected: (_) {})),
    );
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No results found!'), findsOneWidget);
  });

  test('foldForSearch ignores case and accents', () {
    expect(foldForSearch('Pokémon Shōnen'), 'pokemon shonen');
  });

  testWidgets('ThreeStateSelectBar cycles and toggles', (tester) async {
    String? value;
    const cycle = CycleOption(
      label: 'List',
      exclude: SelectOption('not_in_list', 'Not in my list'),
      include: SelectOption('in_list', 'In my list'),
    );
    late StateSetter rebuild;
    await pumpInApp(
      tester,
      StatefulBuilder(builder: (context, setState) {
        rebuild = setState;
        return ThreeStateSelectBar<String>(
          options: _sorts,
          selected: value,
          cycle: cycle,
          onChanged: (v) => rebuild(() => value = v),
        );
      }),
    );
    await tester.tap(find.text('List'));
    await tester.pump();
    expect(value, 'not_in_list');
    await tester.tap(find.text('Not in my list'));
    await tester.pump();
    expect(value, 'in_list');
    await tester.tap(find.text('In my list'));
    await tester.pump();
    expect(value, isNull);

    await tester.tap(find.text('Date'));
    await tester.pump();
    expect(value, 'date');
    await tester.tap(find.text('Date'));
    await tester.pump();
    expect(value, isNull);
  });

  testWidgets('SelectDate picks and clears a date', (tester) async {
    DateTime? date = DateTime(2024, 4, 7);
    late StateSetter rebuild;
    await pumpInApp(
      tester,
      StatefulBuilder(builder: (context, setState) {
        rebuild = setState;
        return SelectDate(
          date: date,
          onChanged: (d) => rebuild(() => date = d),
          onClear: () => rebuild(() => date = null),
        );
      }),
    );
    expect(find.text('Apr 7, 2024'), findsOneWidget);
    await tester.tap(find.text('Apr 7, 2024'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(date, DateTime(2024, 4, 15));
    expect(formatApiDate(date!), '2024-04-15');

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('Pick a date'), findsOneWidget);
  });

  testWidgets('showTopSheet slides in and returns the chip value', (tester) async {
    String? picked;
    await pumpInApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              picked = await showTopSheet<String>(context: context, child: const TopSelectSheet(options: _sorts)),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();
    expect(picked, 'date');
  });
}
