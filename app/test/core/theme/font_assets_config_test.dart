import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _findPackageRoot() {
  var current = Directory.current.absolute;

  while (true) {
    final pubspec = File('${current.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('name: trendpulse')) {
        return current;
      }
    }

    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError('Unable to locate TrendPulse package root.');
    }
    current = parent;
  }
}

void main() {
  test('pubspec bundles editorial font assets without google_fonts', () {
    final packageRoot = _findPackageRoot();
    final pubspec = File.fromUri(packageRoot.uri.resolve('pubspec.yaml'))
        .readAsStringSync();
    final pubspecLock = File.fromUri(packageRoot.uri.resolve('pubspec.lock'))
        .readAsStringSync();
    final interFont = File.fromUri(
      packageRoot.uri.resolve('assets/fonts/Inter-Variable.ttf'),
    );
    final playfairFont = File.fromUri(
      packageRoot.uri.resolve('assets/fonts/PlayfairDisplay-Variable.ttf'),
    );

    expect(
      pubspec,
      isNot(contains(RegExp(r'^\s*google_fonts\s*:', multiLine: true))),
    );
    expect(
      pubspecLock,
      isNot(contains(RegExp(r'^\s+google_fonts:', multiLine: true))),
    );
    expect(pubspec, contains('family: EditorialSans'));
    expect(pubspec, contains('family: EditorialSerif'));
    expect(pubspec, contains('asset: assets/fonts/Inter-Variable.ttf'));
    expect(pubspec, contains('asset: assets/fonts/PlayfairDisplay-Variable.ttf'));
    expect(interFont.existsSync(), isTrue);
    expect(playfairFont.existsSync(), isTrue);
  });
}
