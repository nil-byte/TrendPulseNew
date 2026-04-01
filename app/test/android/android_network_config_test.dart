import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android main manifest declares release network baseline', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('<uses-permission android:name="android.permission.INTERNET"/>'),
    );
    expect(
      manifest,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
    expect(
      manifest,
      isNot(contains('android:usesCleartextTraffic="true"')),
    );
  });

  test(
    'Android debug network config allows cleartext for dev LAN backends',
    () {
      final configFile = File(
        'android/app/src/debug/res/xml/network_security_config.xml',
      );

      expect(configFile.existsSync(), isTrue);

      final config = configFile.readAsStringSync();
      expect(
        config,
        contains('<base-config cleartextTrafficPermitted="true">'),
      );
    },
  );

  test(
    'Android network security config only opts in local cleartext hosts',
    () {
      final configFile = File(
        'android/app/src/main/res/xml/network_security_config.xml',
      );

      expect(configFile.existsSync(), isTrue);

      final config = configFile.readAsStringSync();
      expect(
        config,
        contains('<base-config cleartextTrafficPermitted="false">'),
      );
      expect(
        config,
        isNot(contains('<base-config cleartextTrafficPermitted="true">')),
      );
      expect(
        config,
        contains('<domain-config cleartextTrafficPermitted="true">'),
      );

      final cleartextDomains = RegExp(
        r'<domain[^>]*>([^<]+)</domain>',
      ).allMatches(config).map((match) => match.group(1)).whereType<String>();

      expect(
        cleartextDomains,
        unorderedEquals(['localhost', '127.0.0.1', '10.0.2.2']),
      );
    },
  );

  test(
    'Android release debug signing is gated (CI / explicit env only)',
    () {
      final gradleFile = File('android/app/build.gradle.kts');

      expect(gradleFile.existsSync(), isTrue);

      final gradleConfig = gradleFile.readAsStringSync();
      expect(
        gradleConfig,
        contains('useDebugReleaseSigning'),
        reason:
            'Release must not sign with debug keys unless behind useDebugReleaseSigning',
      );
      expect(
        gradleConfig,
        contains('System.getenv("CI")'),
      );
      expect(
        gradleConfig,
        contains('signingConfigs.getByName("debug")'),
      );
      expect(
        gradleConfig,
        contains('if (useDebugReleaseSigning)'),
      );
    },
  );
}
