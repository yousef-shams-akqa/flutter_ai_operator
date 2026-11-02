import 'dart:async' show unawaited;

import 'package:either_dart/either.dart';
import 'package:go_router/go_router.dart';

import '../interfaces/ai_executable_action.dart';
import 'navigation_failure.dart';
import 'navigation_input.dart';
import 'navigation_method.dart';

/// Runs the model's navigation tool calls on a [GoRouter].
///
/// Describe the tools with `navigationFunctionDefinitions` and parse
/// each call with [NavigationInput.fromArgs].
///
/// Locations inside a [StatefulShellRoute] always open with `go`: pushing or
/// replacing one while a page outside the shell is on top builds the shell
/// twice and crashes the Navigator with a duplicate page key.
class GoRouterNavigationAction
    implements AiExecutableAction<NavigationInput, String, NavigationFailure> {
  GoRouterNavigationAction(
    this._router, {
    this.pauseBetweenNavigations = const Duration(seconds: 2),
  });

  final GoRouter _router;

  /// Minimum time between two navigations, so the user sees each screen when
  /// the model opens several in one request. Failed calls add no pause.
  final Duration pauseBetweenNavigations;

  Future<void> _ready = Future.value();

  @override
  Future<Either<NavigationFailure, String>> execute(NavigationInput input) {
    final result = _ready.then((_) => _navigate(input));
    _ready = result.then((navigation) async {
      if (navigation.isRight && pauseBetweenNavigations > Duration.zero) {
        await Future<void>.delayed(pauseBetweenNavigations);
      }
    });
    return result;
  }

  Either<NavigationFailure, String> _navigate(NavigationInput input) {
    try {
      return switch (input.location) {
        null => _pop(),
        final path => _open(input, path),
      };
    } catch (error, stackTrace) {
      return Left(
        NavigationFailure(
          NavigationFailureReason.routerError,
          'The router failed: $error',
          cause: error,
          causeStackTrace: stackTrace,
        ),
      );
    }
  }

  Either<NavigationFailure, String> _pop() {
    if (!_router.canPop()) {
      return Left(
        NavigationFailure(
          NavigationFailureReason.nothingToPop,
          'There is no previous screen to go back to.',
        ),
      );
    }
    _router.pop();
    return const Right('Closed the current screen.');
  }

  Either<NavigationFailure, String> _open(NavigationInput input, String path) {
    final missing = <String>[];
    final filledPath = path.replaceAllMapped(_placeholder, (match) {
      final name = match.group(1)!;
      final value = input.pathParameters[name];
      if (value == null) {
        missing.add(name);
        return match.group(0)!;
      }
      return Uri.encodeComponent(value);
    });
    if (missing.isNotEmpty) {
      return Left(
        NavigationFailure(
          NavigationFailureReason.invalidInput,
          'Missing ${NavigationInput.pathParametersKey} for $path: '
          '${missing.join(', ')}.',
        ),
      );
    }

    final location = input.queryParameters.isEmpty
        ? filledPath
        : Uri(
            path: filledPath,
            queryParameters: input.queryParameters,
          ).toString();
    final uri = Uri.tryParse(location);
    final match = uri == null ? null : _router.configuration.findMatch(uri);
    if (match == null || match.isError) {
      return Left(
        NavigationFailure(
          NavigationFailureReason.unknownRoute,
          '$location is not a route in this app.',
        ),
      );
    }

    final method = input.method;
    final inShell =
        method != NavigationMethod.resetStackTo &&
        _isInStatefulShell(match.matches);
    if (method == NavigationMethod.push && !inShell) {
      unawaited(_router.push<Object?>(location));
    } else if (method == NavigationMethod.replace && !inShell) {
      unawaited(_router.replace<Object?>(location));
    } else {
      _router.go(location);
    }
    return Right(
      inShell
          ? 'Opened $location as the main screen instead of '
                '${method.functionName}, because it is inside a tab shell.'
          : switch (method) {
              NavigationMethod.resetStackTo =>
                'Opened $location as the main screen.',
              NavigationMethod.push =>
                'Opened $location on top of the current screen.',
              NavigationMethod.replace =>
                'Replaced the current screen with $location.',
              NavigationMethod.pop => 'Closed the current screen.',
            },
    );
  }

  bool _isInStatefulShell(List<RouteMatchBase> matches) {
    return matches.any(
      (match) =>
          match is ShellRouteMatch &&
          (match.route is StatefulShellRoute ||
              _isInStatefulShell(match.matches)),
    );
  }

  /// Same placeholder syntax go_router parses, including an optional
  /// `(regex)` suffix such as `:id(\d+)`.
  static final _placeholder = RegExp(r':(\w+)(\((?:\\.|[^\\()])+\))?');
}
