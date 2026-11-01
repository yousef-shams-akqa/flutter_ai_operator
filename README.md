# Flutter AI Operator

This package lets your app's users prompt AI so it can **execute actions and
operations inside your app**, such as:

- Changing app settings (*"Turn on dark mode"*)
- Updating the user's profile (*"Change my name to Maya"*)
- Navigating to a screen (*"Take me to my orders"*)
- Adding a product to the cart (*"Add two of these to my cart"*)

You define the actions your app exposes and implement them with your existing
logic. The package connects to **Gemini, OpenAI, or Claude** through one common
API. When the AI decides an action is needed, it asks your app to run it, and
the package passes that request to your handler. It then sends the result back
to the AI and returns the AI's final reply to the user.

Your app stays in control: the AI can only trigger the actions you define, and
your data, business rules, and UI remain yours.

## Contents

- [Features](#features)
- [How it works](#how-it-works)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Guides](#guides)
  - [Choose a provider](#choose-a-provider)
  - [Set up Gemini (Firebase)](#set-up-gemini-firebase)
  - [Let the AI call app actions](#let-the-ai-call-app-actions)
  - [Add navigation context](#add-navigation-context)
  - [Handle failures](#handle-failures)
- [Responsibilities and scope](#responsibilities-and-scope)
- [License](#license)

## Features

| Feature | Description |
| --- | --- |
| **Three providers, one interface** | Create an `AIService` with `AIServiceFactory.create()` for Gemini, OpenAI, or Claude. |
| **Function calling** | Describe app capabilities and handle model-requested actions. |
| **App context** | Pass text describing the current screen or application state. |
| **GoRouter integration** | Derive the navigation stack and route tree as context for the AI. |
| **Typed failures** | Tell request errors, malformed calls, and empty replies apart. |

## How it works

1. Your app calls `send()` with the conversation.
2. The AI replies with an action request: the name of one of your functions
   plus its arguments, for example `set_profile_name` with `{"name": "Maya"}`.
3. The package passes it to your `AiActionHandler`. The handler validates the arguments,
   runs the matching use case, and returns `Right(result)` or `Left(error)`.
4. The package sends that result back to the AI.
5. Steps 2-4 repeat as needed (up to 12 rounds) until the AI returns its final
   text reply, which `send()` returns to your app.

## Installation

**Requirements:** a Flutter SDK that includes **Dart 3.13.7 or newer, below
Dart 4.0.0**. Dependencies may impose additional platform requirements.

After the first release is published, run this in your Flutter app:

```bash
flutter pub add flutter_ai_operator
```

Until then, use a local path dependency.

Then import the public API:

```dart
import 'package:flutter_ai_operator/flutter_ai_operator.dart';
```


## Quick start

This example connects the model to one app action (`set_profile_name`), sends a
user request, and appends the reply to the conversation.

You write three pieces:

| Piece | Role |
| --- | --- |
| `SaveProfileNameUsecase` | Validates the name and calls your `ProfileRepository`. |
| `AppActionHandler` | Bridges model-requested functions to your use cases. |
| `AIServiceFactory.create(...)` | Builds the service with your function definitions and handler. |

`ProfileRepository` is also yours; implement it using your own storage.

### 1. Implement the action

```dart
abstract interface class ProfileRepository {
  /// Returns the saved name, or an explicit failure.
  Future<Either<Error, String>> saveProfileName(String name);
}

class SaveProfileNameUsecase
    implements AiExecutableAction<String, String, Error> {
  SaveProfileNameUsecase(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Either<Error, String>> execute(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return Left(ArgumentError('The profile name must not be empty.'));
    }

    return _repository.saveProfileName(trimmedName);
  }
}
```

### 2. Route model requests to the action

The handler checks the function name, parses the model's arguments, and calls
the use case's `execute()`.

```dart
class AppActionHandler extends AiActionHandler {
  AppActionHandler({required this.saveProfileNameUsecase})
    : super(actions: [saveProfileNameUsecase]);

  final SaveProfileNameUsecase saveProfileNameUsecase;

  @override
  Future<Either<Error, String>> handle(FunctionCallResponse response) async {
    if (response.functionName != 'set_profile_name') {
      return Left(StateError('Unknown action: ${response.functionName}'));
    }

    final name = response.functionArgs['name'];
    if (name is! String) {
      return Left(ArgumentError('name must be a string.'));
    }

    return saveProfileNameUsecase.execute(name);
  }
}
```

### 3. Create the service and send a message

```dart
Future<String> runAppAIExample({
  required String modelName,
  required SaveProfileNameUsecase saveProfileNameUsecase,
  AIProvider provider = AIProvider.openAI,
  String? apiKey,
}) async {
  final ai = AIServiceFactory.create(
    provider: provider,
    apiKey: apiKey,
    modelName: modelName,
    configuration: const AIConfiguration(
      systemPrompt:
          'Help the user operate the app through its available tools. ',
      functionDefinitions: [
        FunctionDefinition(
          name: 'set_profile_name',
          description: 'Changes the current user profile name.',
          parameters: [
            FunctionParameter(
              key: 'name',
              value: FunctionParameterValue(
                type: FunctionParameterType.string,
                description: 'The new profile name requested by the user.',
              ),
            ),
          ],
        ),
      ],
    ),
    actionHandler: AppActionHandler(
      saveProfileNameUsecase: saveProfileNameUsecase,
    ),
  );

  final messages = [ChatMessage.user('Change my name to Maya.')];
  final reply = await ai.send(messages);
  messages.add(ChatMessage.model(reply));

  return reply;
}
```

> **Before you run it:** for OpenAI or Claude, pass a runtime `apiKey` and a
> model ID available to that account. For Gemini, complete the
> [Firebase setup](#set-up-gemini-firebase) first.

### How `send()` behaves

- It takes the **complete conversation, oldest message first**, ending with a
  non-blank user message.
- It returns the final text reply and **leaves your message list unchanged**.
  Append the reply yourself after success, as shown above.
- For an ongoing conversation, keep the service and messages in your app or
  feature state, add each new user message before calling `send()` again, and
  serialize sends that share that state.
- Call the service from your application's logic layer and publish loading,
  success, and failure states to your UI.

## Guides

### Choose a provider

| Provider | Factory value | Authentication | Setup before creating the service |
| --- | --- | --- | --- |
| Gemini | `AIProvider.gemini` | Firebase AI Logic | Initialize Firebase and configure App Check |
| OpenAI | `AIProvider.openAI` | Caller-supplied API key | Supply a non-empty `apiKey` |
| Claude | `AIProvider.claude` | Caller-supplied API key | Supply a non-empty `apiKey` |

- Use the same factory call for every provider. To switch to Claude, set
  `provider` to `AIProvider.claude` and supply that provider's key and model ID.
- For Gemini, omit `apiKey`. The factory ignores it.
- `modelName` is optional. Omitting it or passing a blank value selects the
  packaged default, exposed by `AIProvider.defaultModelName`. Pass an explicit
  model ID when you need control over availability and behavior.
- All three adapters ship in this package, so Firebase stays a dependency even
  if your app only uses OpenAI or Claude.
- The package does not acquire or store API keys. Your app owns credential
  handling.

### Set up Gemini (Firebase)

1. [Set up Firebase in your Flutter app](https://firebase.google.com/docs/flutter/setup)
2. [Set up Gemini through Firebase AI Logic](https://firebase.google.com/docs/ai-logic/get-started?platform=flutter)
3. [Set up Firebase App Check](https://firebase.google.com/docs/app-check/flutter/default-providers)
4. [Set up App Check for local development](https://firebase.google.com/docs/app-check/flutter/debug-provider)

### Let the AI call app actions

Describe each tool with `FunctionDefinition`, and route its requests through
your `AiActionHandler` to the matching use case. The package sends the result
back to the model.

- Match tool names and validate arguments.
- Return `Right` on success or `Left` for expected failures.
- Register definitions and dispatch explicitly. Adding a use case to `actions`
  alone does neither.

### Add navigation context

If your app uses GoRouter, add `go_router` as a direct app dependency and import
it alongside this package. The exported `GoRouterStateContext` extension adds
`currentStack()`, `routeTree()`, and `getRouterContext()` to `GoRouter`.

```dart
import 'package:flutter_ai_operator/flutter_ai_operator.dart';
import 'package:go_router/go_router.dart';

Future<String> sendWithNavigation(
  AIService ai,
  GoRouter router,
  List<ChatMessage> messages,
) {
  return ai.send(messages, appContext: router.getRouterContext());
}
```

- This supplies navigation information **as text**. Your app still implements
  any navigation action it exposes to the model.
- You can pass your own context string without GoRouter.
- `appContext` is appended only to the outgoing copy of the final user message.
  Your stored conversation stays unchanged.

### Handle failures

Catch provider failures at your app's use case or application boundary, then
map them into presentation state and localized UI messages.

```dart
Future<Either<AIProviderFailure, String>> sendSafely(
  AIService ai,
  List<ChatMessage> messages,
) async {
  try {
    return Right(await ai.send(messages));
  } on AIProviderFailure catch (failure) {
    return Left(failure);
  }
}
```

| Failure type | Meaning |
| --- | --- |
| `AIProviderInvalidInputFailure` | The message list is empty, ends with an assistant message, or ends with blank user text. |
| `AIProviderRequestFailure` | Network or provider request failure. `code` is the HTTP status when available, otherwise `0`. |
| `AIProviderTooManyCallsFailure` | The request reached the repeated tool-round limit. |
| `AIProviderMalformedToolCallFailure` | The provider returned missing or unreadable tool-call fields. |
| `AIProviderEmptyResponseFailure` | The provider returned no usable text reply. |
| `AIProviderInvalidResponseFailure` | The response shape or SDK response was unusable. |

Failures expose `code`, a stable `reason`, and an optional diagnostic `message`.
Branch on the type or stable fields, not on human-readable text.

> **Not covered by `sendSafely`:** it converts only `AIProviderFailure` values.
> Also handle these at the app boundary:
>
> - A missing or empty OpenAI/Claude key throws `StateError` before any request.
>   Validate configuration during setup.
> - Firebase setup errors.
> - Errors thrown by your action handler.

## Responsibilities and scope

| The package owns | Your app owns |
| --- | --- |
| Provider request formats and response parsing | Provider selection, credentials, and model choice |
| Tool-call continuation and shared failure types | Function definitions, action validation, and business use cases |
| Chat models and optional router context formatting | Conversation state, storage, Firebase setup, and UI |

**Current limits:** the API returns complete text replies. Streaming, request
cancellation, conversation persistence, offline responses, and cache fallback
are not part of the public API. Requests need network access, and failures are
surfaced rather than replaced with cached or placeholder replies.

Import supported types from `flutter_ai_operator.dart`. Files under `lib/src/`
are implementation details.

## License

Released under the [MIT License](LICENSE). Copyright © 2026 Yousef Shams.
