// Merges the base ARB files (lib/l10n/intl_<locale>.arb) with every unit fragment
// (lib/l10n/units/<unit-id>/intl_<locale>.arb), validates them, and regenerates the S class
// into lib/generated/ (l10n.dart + intl/). Run through tools/l10n/build.sh.
//
// Usage: dart run bin/build.dart <repo-root>
import 'dart:convert';
import 'dart:io';

import 'package:intl_utils/intl_utils.dart';
import 'package:path/path.dart' as p;

const mainLocale = 'en';

final _arbName = RegExp(r'^intl_([A-Za-z]{2,3}(?:_[A-Za-z0-9]+)*)\.arb$');
final _keyName = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');
const _reserved = {
  'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch', 'class', 'const',
  'continue', 'covariant', 'default', 'deferred', 'do', 'dynamic', 'else', 'enum', 'export',
  'extends', 'extension', 'external', 'factory', 'false', 'final', 'finally', 'for', 'Function',
  'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
  'mixin', 'new', 'null', 'on', 'operator', 'part', 'required', 'rethrow', 'return', 'set',
  'show', 'static', 'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'typedef', 'var',
  'void', 'while', 'with', 'yield', 'current', 'delegate', 'load', 'of', 'maybeOf',
};

final errors = <String>[];

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: dart run bin/build.dart <repo-root>');
    exit(64);
  }
  final root = p.normalize(p.absolute(args.first));
  final l10nDir = Directory(p.join(root, 'lib', 'l10n'));
  final stage = Directory(p.join(root, '.dart_tool', 'mwl_l10n'));

  // 1. Base files: one per supported locale, English mandatory.
  final base = <String, Map<String, dynamic>>{};
  for (final f in _arbFiles(l10nDir)) {
    final locale = _arbName.firstMatch(p.basename(f.path))!.group(1)!;
    final content = _readArb(f, locale);
    if (content != null) base[locale] = content;
  }
  if (!base.containsKey(mainLocale)) {
    errors.add('lib/l10n/intl_$mainLocale.arb is missing (the English base is mandatory).');
  }
  _failIfErrors();
  for (final e in base.entries) {
    for (final key in e.value.keys.where((k) => !k.startsWith('@'))) {
      if (!base[mainLocale]!.containsKey(key)) {
        errors.add('lib/l10n/intl_${e.key}.arb: "$key" has no English entry in the base.');
      }
    }
  }
  _failIfErrors();

  // 2. Unit fragments: lib/l10n/units/<unit-id>/intl_<locale>.arb.
  final owner = <String, String>{
    for (final k in base[mainLocale]!.keys.where((k) => !k.startsWith('@'))) k: 'base lib/l10n',
  };
  final merged = {for (final e in base.entries) e.key: Map<String, dynamic>.of(e.value)};
  final unitsDir = Directory(p.join(l10nDir.path, 'units'));
  final units = unitsDir.existsSync()
      ? (unitsDir.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <Directory>[];
  var fragmentCount = 0;
  for (final unit in units) {
    final unitId = p.basename(unit.path);
    if (unitId.startsWith('.')) continue;
    final rel = 'lib/l10n/units/$unitId';
    final files = <String, Map<String, dynamic>>{};
    for (final entity in unit.listSync()) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      final m = _arbName.firstMatch(name);
      if (entity is! File || m == null) {
        errors.add('$rel/$name: only intl_<locale>.arb files are allowed in a unit fragment.');
        continue;
      }
      final locale = m.group(1)!;
      if (!base.containsKey(locale)) {
        errors.add('$rel/$name: locale "$locale" has no base file '
            '(supported: ${base.keys.join(', ')}).');
        continue;
      }
      final content = _readArb(entity, locale);
      if (content != null) files[locale] = content;
    }
    if (files.isEmpty) continue;
    final en = files[mainLocale];
    if (en == null) {
      errors.add('$rel: intl_$mainLocale.arb is mandatory (English text of every key).');
      continue;
    }
    fragmentCount++;
    // English: new keys only, never a key that already exists elsewhere.
    for (final key in en.keys.where((k) => !k.startsWith('@'))) {
      final prev = owner[key];
      if (prev != null) {
        errors.add('$rel/intl_$mainLocale.arb: key "$key" already exists in $prev. '
            'Reuse it, or pick another name.');
      } else {
        owner[key] = rel;
      }
    }
    for (final entry in files.entries) {
      final locale = entry.key;
      for (final key in entry.value.keys) {
        final msgKey = key.startsWith('@') ? key.substring(1) : key;
        if (!en.containsKey(msgKey)) {
          errors.add('$rel/intl_$locale.arb: "$key" has no English entry in $rel/intl_$mainLocale.arb.');
          continue;
        }
        if (owner[msgKey] != rel) continue; // collision already reported
        merged[locale]![key] = entry.value[key];
      }
    }
  }
  _failIfErrors();

  // 3. Write the merged ARBs (build outputs) and run intl_utils on them.
  if (stage.existsSync()) stage.deleteSync(recursive: true);
  final arbOut = Directory(p.join(stage.path, 'arb'))..createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  for (final e in merged.entries) {
    final content = <String, dynamic>{'@@locale': e.key, ...e.value};
    File(p.join(arbOut.path, 'intl_${e.key}.arb')).writeAsStringSync('${encoder.convert(content)}\n');
  }
  File(p.join(stage.path, 'pubspec.yaml')).writeAsStringSync('''
name: mwl_l10n_stage
flutter_intl:
  enabled: true
  class_name: S
  main_locale: $mainLocale
  arb_dir: arb
  output_dir: out
''');
  final previous = Directory.current;
  Directory.current = stage;
  try {
    await Generator().generateAsync();
  } finally {
    Directory.current = previous;
  }

  // 4. Replace the generated S files (lib/generated/maps.dart is hand-written: left alone).
  final outDir = p.join(stage.path, 'out');
  final genDir = p.join(root, 'lib', 'generated');
  final intlDir = Directory(p.join(genDir, 'intl'));
  if (intlDir.existsSync()) intlDir.deleteSync(recursive: true);
  intlDir.createSync(recursive: true);
  for (final f in Directory(p.join(outDir, 'intl')).listSync().whereType<File>()) {
    f.copySync(p.join(intlDir.path, p.basename(f.path)));
  }
  File(p.join(outDir, 'l10n.dart')).copySync(p.join(genDir, 'l10n.dart'));

  final keys = merged[mainLocale]!.keys.where((k) => !k.startsWith('@')).length;
  stdout.writeln('[l10n] ${base.length} locales, $keys keys '
      '($fragmentCount unit fragment(s)) -> lib/generated/');
}

List<File> _arbFiles(Directory dir) {
  if (!dir.existsSync()) return [];
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => _arbName.hasMatch(p.basename(f.path)))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// Reads and validates one ARB file; returns its entries without `@@` keys.
Map<String, dynamic>? _readArb(File f, String locale) {
  final rel = f.path.substring(f.path.indexOf('lib${p.separator}l10n'));
  final Object? decoded;
  try {
    decoded = json.decode(f.readAsStringSync());
  } on FormatException catch (e) {
    errors.add('$rel: invalid JSON (${e.message}).');
    return null;
  }
  if (decoded is! Map<String, dynamic>) {
    errors.add('$rel: the top level must be a JSON object.');
    return null;
  }
  final out = <String, dynamic>{};
  for (final e in decoded.entries) {
    final key = e.key;
    if (key == '@@locale') {
      if (e.value != locale) errors.add('$rel: "@@locale" is "${e.value}", expected "$locale".');
      continue;
    }
    if (key.startsWith('@@')) continue;
    if (key.startsWith('@')) {
      if (e.value is! Map) errors.add('$rel: metadata "$key" must be an object.');
      if (!decoded.containsKey(key.substring(1))) {
        errors.add('$rel: metadata "$key" has no message "${key.substring(1)}".');
      }
    } else {
      if (!_keyName.hasMatch(key) || _reserved.contains(key)) {
        errors.add('$rel: "$key" is not a valid key (letters, digits, underscores; '
            'starts with a letter; not a Dart keyword).');
      }
      if (e.value is! String) errors.add('$rel: "$key" must be a string.');
    }
    out[key] = e.value;
  }
  return out;
}

void _failIfErrors() {
  if (errors.isEmpty) return;
  stderr.writeln('[l10n] ${errors.length} error(s):');
  for (final e in errors) {
    stderr.writeln('  - $e');
  }
  exit(1);
}
