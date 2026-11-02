import 'package:either_dart/either.dart';

import 'navigation_failure.dart';
import 'navigation_method.dart';

/// One navigation request from the model, run by `GoRouterNavigationAction`.
///
/// Built for a single tool call by [fromArgs] and never stored.
class NavigationInput {
  const NavigationInput.resetStackTo(
    String location, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) : this._(
         NavigationMethod.resetStackTo,
         location,
         pathParameters,
         queryParameters,
       );

  const NavigationInput.push(
    String location, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) : this._(NavigationMethod.push, location, pathParameters, queryParameters);

  const NavigationInput.replace(
    String location, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) : this._(
         NavigationMethod.replace,
         location,
         pathParameters,
         queryParameters,
       );

  const NavigationInput.pop()
    : this._(NavigationMethod.pop, null, const {}, const {});

  const NavigationInput._(
    this.method,
    this.location,
    this.pathParameters,
    this.queryParameters,
  );

  static const locationKey = 'location';
  static const pathParametersKey = 'pathParameters';
  static const queryParametersKey = 'queryParameters';

  final NavigationMethod method;

  /// Route path, either with `:placeholders` (`/products/:productId`) or
  /// already filled in (`/products/42`). Null only for [NavigationInput.pop].
  final String? location;

  /// Values for the `:placeholders` in [location], keyed by placeholder name.
  final Map<String, String> pathParameters;

  final Map<String, String> queryParameters;

  /// Reads the model's arguments for [method].
  ///
  /// Numbers and booleans in the parameter maps are accepted as text, since
  /// models often send `42` for a string placeholder.
  static Either<NavigationFailure, NavigationInput> fromArgs(
    NavigationMethod method,
    Map<String, dynamic> args,
  ) {
    if (method == NavigationMethod.pop) {
      return const Right(NavigationInput.pop());
    }

    final location = args[locationKey];
    if (location is! String || location.trim().isEmpty) {
      return Left(
        NavigationFailure(
          NavigationFailureReason.invalidInput,
          '"$locationKey" must be a route path, such as "/home".',
        ),
      );
    }

    final pathParameters = _stringMap(args, pathParametersKey);
    if (pathParameters.isLeft) return Left(pathParameters.left);

    final queryParameters = _stringMap(args, queryParametersKey);
    if (queryParameters.isLeft) return Left(queryParameters.left);

    return Right(
      NavigationInput._(
        method,
        location.trim(),
        pathParameters.right,
        queryParameters.right,
      ),
    );
  }

  static Either<NavigationFailure, Map<String, String>> _stringMap(
    Map<String, dynamic> args,
    String key,
  ) {
    final value = args[key];
    if (value == null) return const Right({});

    final invalid = Left<NavigationFailure, Map<String, String>>(
      NavigationFailure(
        NavigationFailureReason.invalidInput,
        '"$key" must be an object of text values, such as {"id": "42"}.',
      ),
    );
    if (value is! Map) return invalid;

    final strings = <String, String>{};
    for (final entry in value.entries) {
      final text = entry.value;
      if (text is! String && text is! num && text is! bool) return invalid;
      strings[entry.key.toString()] = text.toString();
    }
    return Right(strings);
  }
}
