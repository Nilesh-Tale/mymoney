import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central HTTP client plus shared-password auth token management.
///
/// The token is kept in memory for request speed and persisted in
/// shared_preferences so the session survives page reloads. A Dio interceptor
/// attaches the token to every request and signals when the server rejects it
/// (401) so the UI can bounce back to the login screen.
class ApiClient {
  ApiClient._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String _tokenKey = 'auth_token';

  static String? _token;

  /// Called by the UI when the server rejects the token (expired/invalid).
  /// The app layer sets this to force a logout + show the login screen.
  static void Function()? onUnauthorized;

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // The login endpoint returning 401 is a wrong-password case, not an
          // expired session — don't trigger the global logout for it.
          final isLogin =
              error.requestOptions.path.contains('/api/auth/login');
          if (error.response?.statusCode == 401 && !isLogin) {
            clearToken();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );

  static bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  static String? get token => _token;

  /// Load any persisted token at app startup.
  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static String errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Cannot connect to the server at $baseUrl. '
            'It may be waking up — please wait a moment and retry.';
      }
      return error.message ?? 'A network error occurred.';
    }
    return error.toString();
  }
}
