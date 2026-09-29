/// Runtime configuration.
///
/// The target architecture in CLAUDE.md calls for `envied` + `.env`, but that
/// needs `build_runner`, which this project deliberately does not use. The
/// no-codegen equivalent is `String.fromEnvironment`, which is resolved at
/// compile time and works identically on web:
///
/// ```bash
/// flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
/// ```
abstract class AppConfig {
  /// Base URL of the marketplace backend.
  ///
  /// The Flutter dev server sits on a different port, so every call is
  /// cross-origin and depends on the backend answering preflight `OPTIONS`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  /// The access token lives 15 minutes (`expires_in: 900`), so a session that
  /// is open for an afternoon refreshes dozens of times. Refresh has to be
  /// automatic and serialised, never something a screen thinks about.
  static const Duration accessTokenLifetime = Duration(minutes: 15);

  /// Wire-level request/response logging. Off by default because tokens and
  /// KYC document URLs travel through these logs.
  static const bool logHttp = bool.fromEnvironment(
    'LOG_HTTP',
    defaultValue: true,
  );

  /// Draws the screens whose API does not exist yet with sample data, each
  /// marked "Data contoh". Off by default so a release build never shows
  /// invented figures; the same screens then say the feature is waiting on
  /// the API.
  ///
  /// ```bash
  /// flutter run -d macos --dart-define=DEMO_DATA=true
  /// ```
  static const bool demoData = bool.fromEnvironment(
    'DEMO_DATA',
    defaultValue: false,
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}
