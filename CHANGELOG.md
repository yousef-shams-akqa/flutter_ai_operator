# Changelog

## 0.2.1

- **Breaking:** `AIServiceFactory.create()` now requires a non-empty `apiKey` parameter.
- Update README.md to include a demo

## 0.2.0

- **Breaking:** Gemini now uses the [Generative Language REST API](https://ai.google.dev/api/generate-content)
- Dropped `firebase_core` and `firebase_ai` package dependencies.

- This package should now support Windows, MacOS and Linux.

## 0.1.3

- Renamed package to `flutter_app_copilot` (formerly `flutter_ai_operator`).
- Improved navigation guidelines in the system prompt.
- Upgrade go_router dependency to 18.1.2

## 0.1.2

- Updated and improved example.

## 0.1.1

- Added a commented usage example.
- Improved the README.

## 0.1.0

Initial release.

- Added a shared `AIService` API and static `AIServiceFactory.create()` entry point
  for Gemini, OpenAI, and Claude.
- Added caller-supplied configuration, model selection, and complete conversation
  lists through `send(messages, appContext: ...)`, including the latest user message.
- Added request snapshots that preserve caller messages and attach app context
  only to the outgoing final user message.
- Added `AIProviderInvalidInputFailure` for empty conversations, non-user final
  messages, and blank final user text, before contacting a provider.
- Added function definitions and action-handler contracts for app tool calling.
- Exported `Either`, `Left`, and `Right` through the public package API.
- Added provider tool-call loops with a limit of 12 rounds.
- Added typed failures for request errors, malformed calls, and unusable responses.
- Added optional GoRouter navigation stack and route-tree context.
- Added tests for provider flows, HTTP behavior, schema mapping, and router context.
- Documented installation, usage, Gemini setup, and error handling.
- Released under the MIT License.
