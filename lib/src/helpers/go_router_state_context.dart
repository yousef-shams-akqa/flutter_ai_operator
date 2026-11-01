import 'package:go_router/go_router.dart';

/// Navigation context for the AI layer, derived from [GoRouter].
///
/// The result of [getRouterContext] is passed as `appContext` and appended to
/// the user's request, so the model can pick correct navigation targets.
extension GoRouterStateContext on GoRouter {
  /// Current active navigation stack.
  /// Example: '/home → /home/settings → /home/settings/profile'
  String currentStack() {
    return routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .join(' → ');
  }

  /// Complete configured route tree.
  /// Example: '/home { /home/settings { /home/settings/profile } }'
  String routeTree() {
    String build(List<RouteBase> routes) {
      return routes.map((route) {
        final path = route is GoRoute ? route.path : route.runtimeType.toString();

        final children = route is StatefulShellRoute
            ? route.branches.expand((b) => b.routes).toList()
            : route.routes;

        return children.isEmpty ? path : '$path { ${build(children)} }';
      }).join(', ');
    }

    return build(configuration.routes);
  }

  /// Returns the current navigation stack and route tree.
  String getRouterContext() {
    return '\n Current stack: ${currentStack()} \n Route tree: ${routeTree()} \n';
  }
}
