/// Central BRIO configuration.
///
/// The backend URL is defined in a single place so environments are easy to
/// swap. Override it at build time with:
///   flutter run --dart-define=BRIO_API_URL=http://my-host:8000/api
///
/// Typical environments (pass with --dart-define per device):
///   - Android emulator (DEFAULT):        http://10.0.2.2:8000/api
///   - Physical phone (USB, adb reverse): http://localhost:8000/api
///   - Physical phone (same WiFi):        http://192.168.1.29:8000/api
///   - Production (cloud):                https://api.brio.app/api
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'BRIO_API_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  /// Origin for serving media (videos/images): the base URL without the /api
  /// suffix. A relative path like "/media/x.mp4" resolves by prefixing this.
  static String get mediaBaseUrl => apiBaseUrl.replaceAll('/api', '');

  /// Turns a media path (relative or absolute) into an absolute URL.
  static String resolveMedia(String path) =>
      path.startsWith('http') ? path : '$mediaBaseUrl$path';
}
