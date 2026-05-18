/// Central place for all API-related constants.
/// Add new endpoint strings here — never hardcode URLs in datasources.
class ApiConstants {
  ApiConstants._();

  // ── Base ────────────────────────────────────────────────────
  static const String baseUrl = 'http://103.235.105.96:8002/api';

  // ── Timeouts ────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout    = Duration(seconds: 30);

  // ── Auth ────────────────────────────────────────────────────
  static const String login = '/Auth/login';
  static const String logout = '/Auth/logout';
  static const String refreshToken = '/Auth/refresh';

// ── Add future endpoints below ───────────────────────────────
// static const String profile  = '/User/profile';
// static const String routes   = '/Route/list';
}