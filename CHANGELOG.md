# Changelog

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
