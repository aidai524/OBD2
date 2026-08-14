import 'package:flutter_test/flutter_test.dart';
import 'package:obd2app/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    for (final environment in AppEnvironment.values) {
      test('loads the ${environment.name} environment', () {
        final config = AppConfig.fromValues(
          appEnvironment: environment.name,
          supabaseUrl: environment == AppEnvironment.dev
              ? 'http://127.0.0.1:54321'
              : 'https://${environment.name}.example.invalid',
          supabasePublishableKey: 'public-key-${environment.name}',
        );

        expect(config.environment, environment);
        expect(config.supabaseUrl.isAbsolute, isTrue);
      });
    }

    test('rejects a missing environment', () {
      expect(
        () => AppConfig.fromValues(
          appEnvironment: '',
          supabaseUrl: 'https://example.invalid',
          supabasePublishableKey: 'public-key',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects an unsupported environment', () {
      expect(
        () => AppConfig.fromValues(
          appEnvironment: 'production',
          supabaseUrl: 'https://example.invalid',
          supabasePublishableKey: 'public-key',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects an invalid Supabase URL', () {
      expect(
        () => AppConfig.fromValues(
          appEnvironment: 'dev',
          supabaseUrl: 'not-a-url',
          supabasePublishableKey: 'public-key',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('requires HTTPS outside dev', () {
      expect(
        () => AppConfig.fromValues(
          appEnvironment: 'prod',
          supabaseUrl: 'http://prod.example.invalid',
          supabasePublishableKey: 'public-key',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects a missing publishable key', () {
      expect(
        () => AppConfig.fromValues(
          appEnvironment: 'dev',
          supabaseUrl: 'http://127.0.0.1:54321',
          supabasePublishableKey: ' ',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects the example URL placeholder', () {
      expect(
        () => AppConfig.fromValues(
          appEnvironment: 'dev',
          supabaseUrl: 'https://replace-with-project-url.invalid',
          supabasePublishableKey: 'public-key',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects the example key placeholder', () {
      expect(
        () => AppConfig.fromValues(
          appEnvironment: 'dev',
          supabaseUrl: 'http://127.0.0.1:54321',
          supabasePublishableKey: 'replace_with_public_publishable_or_anon_key',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('redacts the publishable key from diagnostics', () {
      final config = AppConfig.fromValues(
        appEnvironment: 'dev',
        supabaseUrl: 'http://127.0.0.1:54321',
        supabasePublishableKey: 'public-key-that-must-not-be-logged',
      );

      expect(config.toString(), contains('<redacted>'));
      expect(config.toString(), isNot(contains(config.supabasePublishableKey)));
    });

    const compileTimeEnvironment = String.fromEnvironment('APP_ENV');
    if (compileTimeEnvironment.isNotEmpty) {
      test('loads the selected compile-time profile', () {
        final config = AppConfig.fromCompileTime();

        expect(config.environment.name, compileTimeEnvironment);
      });
    }
  });
}
