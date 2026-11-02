# Logic-only example

## Purpose

[flutter_app_copilot_example.dart](flutter_app_copilot_example.dart) shows the
whole package flow in one file, with short numbered comments and no UI. It also
shows navigation: `exampleRouter`, at the bottom of the file, is a small
`GoRouter` that the model can read and move through.

## Entry Points

`main()` configures the provider, sends a request, and prints the final reply.

## Flow

```text
"What is 12 plus 30?"
  → AIService.send(messages)
  → model requests add_numbers(firstNumber: 12, secondNumber: 30)
  → CalculatorActionHandler parses the arguments with AddNumbersInput.fromJson
  → AddNumbersAction returns 42
  → package sends 42 back to the model
  → final AI reply is printed and added to messages
```

Navigation works the same way. The handler passes `resetStackTo`, `pushScreen`,
`replaceTopScreen`, and `popScreen` calls to `GoRouterNavigationAction`, and
`GoRouterContextSource` tells the model the current stack and routes on every
request. In a real app, mount the router with `MaterialApp.router` first.

The example owns its conversation in memory; nothing is saved or cached.
Provider failures are printed and rethrown. Action failures use `Left` so the
package can report them back to the model.

`AddNumbersInput` is an immutable application input owned by this example. Its
`fromJson` method validates `response.functionArgs`, then maps `firstNumber` and
`secondNumber` into its numbers list. It returns `Left` for missing or invalid
values. The input exists only for the current call and is never persisted.

`AddNumbersAction` receives that typed input and sums its numbers using `fold`.
Direct callers can still pass any list length, including `AddNumbersInput([])`
for `0` and `AddNumbersInput([7])` for `7`. The example's model-facing tool
continues to require two named numbers.

The handler selects a registered `AddNumbersAction` by type before parsing
the arguments. Unknown functions and missing actions return explicit failures.

## Use in your app

Copy the action, handler, and request flow into your Flutter app and call the
flow from your application logic.

The sample reads `OPENAI_API_KEY` and optional `OPENAI_MODEL` from your app's
`--dart-define` options. Use a model available to your account; omitting the
model uses the package's default.

## Common Changes

- Change the user message to try different numbers.
- To add an action, implement `AiExecutableAction`, describe it in
  `functionDefinitions`, and dispatch it in the handler. Adding it to `actions`
  alone does not register its definition or dispatch.
- To use your own routes, replace `exampleRouter` with your app's `GoRouter`.
- To use Claude or Gemini, change the provider and pass that provider's API key
  and model ID.

## Testing

`flutter test` runs the offline package tests, including the example handler's
success, action selection, missing-action, invalid-argument, and unknown-function
cases, plus JSON parsing and the action's empty, single-value, and longer-list
cases. These tests live in
[`test/example_action_handler_test.dart`](../test/example_action_handler_test.dart).
