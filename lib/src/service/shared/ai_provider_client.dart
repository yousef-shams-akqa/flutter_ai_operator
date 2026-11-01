import 'package:dio/dio.dart';

/// Sends JSON requests to one AI provider's HTTP API.
///
/// Owns HTTP configuration only. It throws Dio's own [DioException]; the
/// provider service decides how to report it.
class AIProviderClient {
  AIProviderClient({
    required String baseUrl,
    required Map<String, String> headers,
    Dio? dio,
  }) : _dio = (dio ?? Dio())
         ..options.baseUrl = baseUrl
         ..options.headers.addAll(headers)
         ..options.connectTimeout = const Duration(seconds: 15)
         ..options.sendTimeout = const Duration(seconds: 90)
         ..options.receiveTimeout = const Duration(seconds: 90);

  final Dio _dio;

  /// Returns the response body, or `null` when it is not a JSON object.
  ///
  /// Throws [DioException] on network errors and non-2xx statuses.
  Future<Map<String, dynamic>?> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post<Object?>(path, data: body);
    final data = response.data;
    return data is Map<String, dynamic> ? data : null;
  }

  /// The error text OpenAI and Claude both return as
  /// `{"error": {"message": ...}}`, falling back to Dio's own message.
  String? errorMessage(DioException error) {
    final body = error.response?.data;
    final detail = body is Map ? body['error'] : null;
    final message = detail is Map ? detail['message'] : null;
    return message is String ? message : error.message;
  }
}
