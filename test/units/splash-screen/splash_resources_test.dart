import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

String _read(String path) => File('$_res/$path').readAsStringSync();

void main() {
  test('splash colour is dark navy', () {
    expect(_read('values/colors.xml'),
        contains('<color name="splash_background">#00091F</color>'));
  });

  for (final dir in ['values-v31', 'values-night-v31']) {
    test('$dir LaunchTheme sets the system splash', () {
      final xml = _read('$dir/styles.xml');
      expect(xml, contains('name="LaunchTheme"'));
      expect(
          xml,
          contains(
              '<item name="android:windowSplashScreenBackground">@color/splash_background</item>'));
      expect(
          xml,
          contains(
              '<item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher_foreground</item>'));
    });
  }

  for (final dir in ['values', 'values-night', 'values-v31', 'values-night-v31']) {
    test('$dir NormalTheme matches the splash colour', () {
      expect(
          _read('$dir/styles.xml'),
          contains(
              '<item name="android:windowBackground">@color/splash_background</item>'));
    });
  }

  test('launch_background is navy with a centred logo', () {
    final xml = _read('drawable/launch_background.xml');
    expect(xml, contains('@color/splash_background'));
    expect(xml, contains('@mipmap/ic_launcher_foreground'));
    expect(xml, contains('android:gravity="center"'));
    expect(xml, isNot(contains('android:color/white')));
  });

  test('referenced mipmap exists and no drawable-v21 override remains', () {
    expect(File('$_res/mipmap-xxxhdpi/ic_launcher_foreground.png').existsSync(),
        isTrue);
    expect(File('$_res/drawable-v21/launch_background.xml').existsSync(),
        isFalse);
  });
}
