enum AppEnvironment {
  dev,
  staging,
  prod;

  static AppEnvironment parse(String value) {
    return switch (value.trim()) {
      'dev' => AppEnvironment.dev,
      'staging' => AppEnvironment.staging,
      'prod' => AppEnvironment.prod,
      _ => throw AppConfigException(
        'APP_ENV must be one of: dev, staging, prod.',
      ),
    };
  }
}

final class AppConfig {
  const AppConfig._({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  factory AppConfig.fromCompileTime() {
    return AppConfig.fromValues(
      appEnvironment: const String.fromEnvironment('APP_ENV'),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
    );
  }

  factory AppConfig.fromValues({
    required String appEnvironment,
    required String supabaseUrl,
    required String supabasePublishableKey,
  }) {
    final environment = AppEnvironment.parse(
      _requiredValue('APP_ENV', appEnvironment),
    );
    final urlValue = _requiredValue('SUPABASE_URL', supabaseUrl);
    final parsedUrl = Uri.tryParse(urlValue);

    if (parsedUrl == null ||
        !parsedUrl.hasScheme ||
        parsedUrl.host.isEmpty ||
        (parsedUrl.scheme != 'http' && parsedUrl.scheme != 'https')) {
      throw const AppConfigException(
        'SUPABASE_URL must be an absolute HTTP or HTTPS URL.',
      );
    }

    if (parsedUrl.host == 'replace-with-project-url.invalid') {
      throw const AppConfigException(
        'SUPABASE_URL still contains the .env.example placeholder.',
      );
    }

    if (environment != AppEnvironment.dev && parsedUrl.scheme != 'https') {
      throw const AppConfigException(
        'SUPABASE_URL must use HTTPS outside the dev environment.',
      );
    }

    final publishableKey = _requiredValue(
      'SUPABASE_PUBLISHABLE_KEY',
      supabasePublishableKey,
    );
    if (publishableKey == 'replace_with_public_publishable_or_anon_key') {
      throw const AppConfigException(
        'SUPABASE_PUBLISHABLE_KEY still contains the .env.example placeholder.',
      );
    }

    return AppConfig._(
      environment: environment,
      supabaseUrl: parsedUrl,
      supabasePublishableKey: publishableKey,
    );
  }

  final AppEnvironment environment;
  final Uri supabaseUrl;
  final String supabasePublishableKey;

  static String _requiredValue(String key, String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw AppConfigException('$key is required.');
    }
    return normalized;
  }

  @override
  String toString() {
    return 'AppConfig('
        'environment: ${environment.name}, '
        'supabaseUrl: $supabaseUrl, '
        'supabasePublishableKey: <redacted>)';
  }
}

final class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}
