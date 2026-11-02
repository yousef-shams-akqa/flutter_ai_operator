import 'package:flutter_app_copilot/flutter_app_copilot.dart';
import 'package:flutter_app_copilot/src/helpers/json_schema_function_definition_mapper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('function names map back to their navigation method', () {
    for (final method in NavigationMethod.values) {
      expect(NavigationMethod.fromFunctionName(method.functionName), method);
    }
    expect(NavigationMethod.fromFunctionName('setDarkMode'), isNull);
  });

  test('reads location and parameter maps from model arguments', () {
    final input = NavigationInput.fromArgs(NavigationMethod.push, {
      'location': ' /products/:productId ',
      'pathParameters': {'productId': 42},
      'queryParameters': {'preview': true},
    }).right;

    expect(input.method, NavigationMethod.push);
    expect(input.location, '/products/:productId');
    expect(input.pathParameters, {'productId': '42'});
    expect(input.queryParameters, {'preview': 'true'});
  });

  test('pop ignores arguments', () {
    final input = NavigationInput.fromArgs(NavigationMethod.pop, {
      'location': '/home',
    }).right;

    expect(input.method, NavigationMethod.pop);
    expect(input.location, isNull);
  });

  test('rejects a missing location and non-text parameter values', () {
    final missingLocation = NavigationInput.fromArgs(
      NavigationMethod.resetStackTo,
      {},
    ).left;
    final nestedValue = NavigationInput.fromArgs(
      NavigationMethod.resetStackTo,
      {
        'location': '/products/:productId',
        'pathParameters': {
          'productId': {'id': '42'},
        },
      },
    ).left;
    final listParameters = NavigationInput.fromArgs(
      NavigationMethod.resetStackTo,
      {
        'location': '/home',
        'queryParameters': ['tab'],
      },
    ).left;

    expect(missingLocation.reason, NavigationFailureReason.invalidInput);
    expect(missingLocation.message, contains('location'));
    expect(nestedValue.message, contains('pathParameters'));
    expect(listParameters.message, contains('queryParameters'));
  });

  test('function definitions describe what fromArgs reads', () {
    final definitions = navigationFunctionDefinitions(
      locations: ['/home', '/products/:productId'],
    );
    final tools = const JsonSchemaFunctionDefinitionMapper()
        .toolsFromDefinitions(definitions);

    expect(
      tools.map((tool) => tool['name']),
      NavigationMethod.values.map((method) => method.functionName),
    );
    final push = tools[NavigationMethod.push.index]['parameters'];
    expect(push['required'], ['location']);
    expect(push['properties']['location']['enum'], [
      '/home',
      '/products/:productId',
    ]);
    expect(
      push['properties']['pathParameters']['additionalProperties']['type'],
      'string',
    );
    expect(tools[NavigationMethod.pop.index]['parameters']['properties'], {});
  });

  testWidgets('routePaths lists every GoRoute path including shells', (
    _,
  ) async {
    final router = GoRouter(
      initialLocation: '/feed',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => shell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/feed', builder: (_, _) => const SizedBox()),
              ],
            ),
          ],
        ),
        ShellRoute(
          builder: (_, _, child) => child,
          routes: [
            GoRoute(
              path: '/products/:productId',
              builder: (_, _) => const SizedBox(),
              routes: [
                GoRoute(path: 'reviews', builder: (_, _) => const SizedBox()),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    expect(router.routePaths(), [
      '/feed',
      '/products/:productId',
      '/products/:productId/reviews',
    ]);
  });
}
