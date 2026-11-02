import 'package:flutter/material.dart';
import 'package:flutter_app_copilot/flutter_app_copilot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => Scaffold(body: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const Text('home')),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const Text('settings'),
              routes: [
                GoRoute(
                  path: 'profile',
                  builder: (_, _) => const Text('profile'),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/agent', builder: (_, _) => const Text('agent')),
    GoRoute(
      path: '/products/:productId',
      builder: (_, state) =>
          Text('product ${state.pathParameters['productId']}'),
    ),
    GoRoute(
      path: '/orders/:id/items/:idType',
      builder: (_, state) => Text(
        'order ${state.pathParameters['id']} ${state.pathParameters['idType']}',
      ),
    ),
  ],
);

Future<GoRouter> _pumpRouter(WidgetTester tester) async {
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

Future<Either<NavigationFailure, String>> _run(
  WidgetTester tester,
  GoRouterNavigationAction action,
  NavigationInput input,
) async {
  final result = await action.execute(input);
  await tester.pumpAndSettle();
  return result;
}

class _NavigationHandler extends AiActionHandler {
  _NavigationHandler(this.navigation) : super(actions: [navigation]);

  final GoRouterNavigationAction navigation;

  @override
  Future<Either<Error, String>> handle(FunctionCallResponse response) async {
    final method = NavigationMethod.fromFunctionName(response.functionName);
    if (method != null) {
      final input = NavigationInput.fromArgs(method, response.functionArgs);
      if (input.isLeft) return Left(input.left);
      return navigation.execute(input.right);
    }
    return Left(StateError('Unknown function: ${response.functionName}'));
  }
}

void main() {
  testWidgets('a handler can pass model calls straight to the action', (
    tester,
  ) async {
    final router = await _pumpRouter(tester);
    final handler = _NavigationHandler(
      GoRouterNavigationAction(router, pauseBetweenNavigations: Duration.zero),
    );

    final opened = await handler.handle(
      FunctionCallResponse('pushScreen', {
        'location': '/products/:productId',
        'pathParameters': {'productId': 7},
      }),
    );
    await tester.pumpAndSettle();
    final invalid = await handler.handle(
      FunctionCallResponse('resetStackTo', {'location': 3}),
    );

    expect(opened.right, 'Opened /products/7 on top of the current screen.');
    expect(find.text('product 7'), findsOneWidget);
    expect(invalid.left, isA<NavigationFailure>());
  });

  testWidgets('go, push, replace and pop move through the stack', (
    tester,
  ) async {
    final router = await _pumpRouter(tester);
    final action = GoRouterNavigationAction(
      router,
      pauseBetweenNavigations: Duration.zero,
    );

    expect(
      (await _run(tester, action, const NavigationInput.push('/agent'))).right,
      'Opened /agent on top of the current screen.',
    );
    expect(find.text('agent'), findsOneWidget);

    await _run(
      tester,
      action,
      const NavigationInput.replace(
        '/products/:productId',
        pathParameters: {'productId': '42'},
      ),
    );
    expect(find.text('product 42'), findsOneWidget);

    await _run(tester, action, const NavigationInput.pop());
    expect(router.state.matchedLocation, '/home');

    await _run(tester, action, const NavigationInput.resetStackTo('/agent'));
    expect(router.state.matchedLocation, '/agent');
    expect(router.canPop(), isFalse);
  });

  testWidgets('fills each placeholder by its whole name and adds the query', (
    tester,
  ) async {
    final router = await _pumpRouter(tester);
    final action = GoRouterNavigationAction(
      router,
      pauseBetweenNavigations: Duration.zero,
    );

    final result = await _run(
      tester,
      action,
      const NavigationInput.resetStackTo(
        '/orders/:id/items/:idType',
        pathParameters: {'id': 'a b', 'idType': 'gift'},
        queryParameters: {'tab': 'details'},
      ),
    );

    expect(
      result.right,
      'Opened /orders/a%20b/items/gift?tab=details as the main screen.',
    );
    expect(find.text('order a b gift'), findsOneWidget);
    expect(router.state.uri.queryParameters, {'tab': 'details'});
  });

  testWidgets(
    'shell locations open as the main screen instead of crashing on pushScreen',
    (tester) async {
      final router = await _pumpRouter(tester);
      final action = GoRouterNavigationAction(
        router,
        pauseBetweenNavigations: Duration.zero,
      );
      await _run(tester, action, const NavigationInput.push('/agent'));

      final result = await _run(
        tester,
        action,
        const NavigationInput.push('/settings/profile'),
      );

      expect(tester.takeException(), isNull);
      expect(
        result.right,
        'Opened /settings/profile as the main screen instead of pushScreen, '
        'because it is inside a tab shell.',
      );
      expect(find.text('profile'), findsOneWidget);
    },
  );

  testWidgets('reports bad requests to the model without navigating', (
    tester,
  ) async {
    final router = await _pumpRouter(tester);
    final action = GoRouterNavigationAction(router);

    final unknown = await _run(
      tester,
      action,
      const NavigationInput.push('/missing'),
    );
    final missingParameter = await _run(
      tester,
      action,
      const NavigationInput.resetStackTo('/products/:productId'),
    );
    final emptyPop = await _run(tester, action, const NavigationInput.pop());

    expect(unknown.left.reason, NavigationFailureReason.unknownRoute);
    expect(
      unknown.left.toString(),
      'NavigationFailure(unknownRoute): /missing is not a route in this app.',
    );
    expect(missingParameter.left.reason, NavigationFailureReason.invalidInput);
    expect(missingParameter.left.message, contains('productId'));
    expect(emptyPop.left.reason, NavigationFailureReason.nothingToPop);
    expect(router.state.matchedLocation, '/home');
  });

  testWidgets('waits the pause before the next navigation', (tester) async {
    final router = await _pumpRouter(tester);
    final action = GoRouterNavigationAction(router);

    await action.execute(const NavigationInput.resetStackTo('/agent'));
    await tester.pump();
    final second = action.execute(
      const NavigationInput.resetStackTo('/settings'),
    );

    await tester.pump(const Duration(seconds: 1));
    expect(router.state.matchedLocation, '/agent');

    await tester.pump(const Duration(seconds: 1));
    expect((await second).isRight, isTrue);
    expect(router.state.matchedLocation, '/settings');

    await tester.pump(const Duration(seconds: 2));
  });
}
