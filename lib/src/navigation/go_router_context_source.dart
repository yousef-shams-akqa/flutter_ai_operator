import 'package:go_router/go_router.dart';

import '../interfaces/app_context_source.dart';
import 'go_router_state_context.dart';

/// Tells the model where the user is in the app, from a [GoRouter].
///
/// Keep passing the same router the app navigates with. The stack is read on
/// every request, so later navigation shows up in the next one.
class GoRouterContextSource implements AppContextSource {
  GoRouterContextSource(this._router);

  final GoRouter _router;

  @override
  String read() => _router.getRouterContext();
}
