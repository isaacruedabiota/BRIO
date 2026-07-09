import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../error/failures.dart';

const _baseUrl    = AppConfig.apiBaseUrl;
const _keyAccess  = 'brio_access_token';
const _keyRefresh = 'brio_refresh_token';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiClient({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    _dio = Dio(BaseOptions(
      baseUrl:        _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(_JwtInterceptor(_dio, _storage));
  }

  // HTTP helpers.

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async =>
      _request(() => _dio.get(path, queryParameters: params));

  Future<dynamic> post(String path, {Object? data}) async =>
      _request(() => _dio.post(path, data: data));

  /// POST multipart/form-data (image upload). Dio sets the Content-Type with
  /// the correct boundary automatically when given a [FormData].
  Future<dynamic> postMultipart(String path, FormData data) async =>
      _request(() => _dio.post(path, data: data));

  Future<dynamic> put(String path, {Object? data}) async =>
      _request(() => _dio.put(path, data: data));

  Future<dynamic> patch(String path, {Object? data}) async =>
      _request(() => _dio.patch(path, data: data));

  Future<dynamic> delete(String path) async =>
      _request(() => _dio.delete(path));

  // Token storage.

  Future<void> saveTokens({required String access, required String refresh}) async {
    await Future.wait([
      _storage.write(key: _keyAccess,  value: access),
      _storage.write(key: _keyRefresh, value: refresh),
    ]);
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _keyAccess),
      _storage.delete(key: _keyRefresh),
    ]);
  }

  Future<bool> hasValidToken() async {
    final token = await _storage.read(key: _keyAccess);
    return token != null && token.isNotEmpty;
  }

  // Error mapping.

  Future<dynamic> _request(Future<Response> Function() call) async {
    try {
      final response = await call();
      return response.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Failure _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkFailure('Sin conexión. Comprueba que el servidor esté activo.');
    }
    final status = e.response?.statusCode ?? 0;
    final message = _extractMessage(e.response?.data);

    return switch (status) {
      400 => ValidationFailure(message ?? 'Datos no válidos.'),
      401 => const UnauthorizedFailure('Email o contraseña incorrectos.'),
      403 => UnauthorizedFailure(message ?? 'No tienes permiso.'),
      404 => NotFoundFailure(message ?? 'No encontrado.'),
      409 => ValidationFailure(message ?? 'Ese registro ya existe.'),
      _   => ServerFailure(message ?? 'Error del servidor ($status).'),
    };
  }

  /// Extracts a readable message from any DRF error shape:
  ///   {"detail": "..."}                      → the detail
  ///   {"non_field_errors": ["..."]}          → first error
  ///   {"email": ["This field is required"]}  → "email: This field..."
  String? _extractMessage(dynamic data) {
    if (data is! Map) return null;

    if (data['detail'] is String) return data['detail'] as String;

    // DRF per-field validation errors.
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        final first = value.first.toString();
        return entry.key == 'non_field_errors' ? first : '${entry.key}: $first';
      }
      if (value is String) return value;
    }
    return null;
  }
}

// JWT interceptor.

class _JwtInterceptor extends Interceptor {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  _JwtInterceptor(this._dio, this._storage);

  /// Public endpoints that must NOT carry the token: sending an expired one
  /// makes DRF respond 401 before processing the login (auth runs before
  /// AllowAny), which would look like "wrong credentials" with valid ones.
  static const _noAuthPaths = ['/auth/login', '/auth/register', '/auth/token/refresh'];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final isPublic = _noAuthPaths.any((p) => options.path.contains(p));
    if (!isPublic) {
      final token = await _storage.read(key: _keyAccess);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        // Retry the original request with the new token.
        final newToken = await _storage.read(key: _keyAccess);
        final opts = err.requestOptions..headers['Authorization'] = 'Bearer $newToken';
        try {
          final response = await _dio.fetch(opts);
          return handler.resolve(response);
        } catch (_) {}
      }
    }
    handler.next(err);
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _storage.read(key: _keyRefresh);
    if (refresh == null) return false;
    try {
      final resp = await Dio().post(
        '$_baseUrl/auth/token/refresh/',
        data: {'refresh': refresh},
      );
      await _storage.write(key: _keyAccess, value: resp.data['access']);
      return true;
    } catch (_) {
      return false;
    }
  }
}
