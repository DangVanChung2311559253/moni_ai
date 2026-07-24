class ApiConfig {
  const ApiConfig._();

  static const String _primaryBaseUrl = String.fromEnvironment(
    'AI_API_BASE_URL',
    defaultValue: '',
  );
  static const String _legacyBaseUrl = String.fromEnvironment(
    'MONI_API_BASE_URL',
    defaultValue: '',
  );
  static const String _defaultBaseUrl = 'http://10.0.2.2:8000';

  /// `MONI_API_BASE_URL` remains supported so an older build command cannot
  /// silently send physical devices back to the Android-emulator address.
  static String get baseUrl => _primaryBaseUrl.isNotEmpty
      ? _primaryBaseUrl
      : (_legacyBaseUrl.isNotEmpty ? _legacyBaseUrl : _defaultBaseUrl);

  static Uri endpoint(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  static Map<String, String> headers({bool json = false}) => {
    if (json) 'Content-Type': 'application/json',
    // Free ngrok tunnels otherwise return an HTML warning page instead of
    // forwarding API calls, which looks like an endless loader in Flutter.
    'ngrok-skip-browser-warning': 'true',
  };
}
