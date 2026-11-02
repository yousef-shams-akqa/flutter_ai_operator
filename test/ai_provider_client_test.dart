import 'package:flutter_app_copilot/src/service/shared/ai_provider_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns an object response body', () async {
    final client = _createClient({'text': 'Ready'});
    expect(await client.postJson('responses', {}), {'text': 'Ready'});
  });

  test(
    'rejects a non-object response instead of returning an empty map',
    () async {
      final client = _createClient(['unexpected', 'list']);
      expect(await client.postJson('responses', {}), isNull);
    },
  );

  test('extracts the provider error detail', () {
    final client = _createClient(null);
    final options = RequestOptions(path: 'responses');
    final error = DioException(
      requestOptions: options,
      message: 'Request failed',
      response: Response(
        requestOptions: options,
        data: {
          'error': {'message': 'Invalid key'},
        },
      ),
    );
    expect(client.errorMessage(error), 'Invalid key');
  });

  test('falls back when the provider error detail has the wrong type', () {
    final client = _createClient(null);
    final options = RequestOptions(path: 'responses');
    final error = DioException(
      requestOptions: options,
      message: 'Request failed',
      response: Response(
        requestOptions: options,
        data: {
          'error': {'message': 42},
        },
      ),
    );
    expect(client.errorMessage(error), 'Request failed');
  });
}

AIProviderClient _createClient(Object? responseBody) {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) => handler.resolve(
          Response<Object?>(requestOptions: request, data: responseBody),
        ),
      ),
    );
  addTearDown(() => dio.close(force: true));
  return AIProviderClient(
    baseUrl: 'https://provider.invalid/v1/',
    headers: const {},
    dio: dio,
  );
}
