import 'package:flutter_app_copilot/flutter_app_copilot.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('context contains evaluated paths and updates after navigation', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home/settings/profile',
      overridePlatformDefaultLocation: true,
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const SizedBox(),
          routes: [
            GoRoute(
              path: 'settings',
              builder: (_, _) => const SizedBox(),
              routes: [
                GoRoute(path: 'profile', builder: (_, _) => const SizedBox()),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WidgetsApp.router(routerConfig: router, color: const Color(0xFFFFFFFF)),
    );
    await tester.pumpAndSettle();
    expect(
      router.getRouterContext(),
      '\n Current stack: /home → /home/settings → /home/settings/profile '
      '\n Route tree: /home { settings { profile } } \n',
    );

    router.go('/home');
    await tester.pumpAndSettle();
    expect(router.currentStack(), '/home');
    expect(
      router.getRouterContext(),
      '\n Current stack: /home \n Route tree: /home { settings { profile } } \n',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('route tree includes siblings and shell children', (_) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (_, _, child) => child,
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
            GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
          ],
        ),
        GoRoute(path: '/about', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);

    expect(
      router.routeTree(),
      'ShellRoute { /home, /settings }, /about',
    );
  });

  testWidgets('route tree includes every stateful shell branch', (_) async {
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
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (_, _) => const SizedBox(),
                  routes: [
                    GoRoute(
                      path: 'profile',
                      builder: (_, _) => const SizedBox(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    expect(
      router.routeTree(),
      'StatefulShellRoute { /feed, /settings { profile } }',
    );
  });
}
