import 'package:flutter_app_copilot/flutter_app_copilot.dart';
// Tests intentionally live under lib; flutter_test remains a dev dependency.
// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app_copilot/src/constants/ai_constants.dart';

import 'helpers/ai_service_fixture.dart';

void main() {
  for (final provider in AIProvider.values) {
    group('${provider.name} AIService contract', () {
      late AIServiceFixture fixture;

      setUp(() => fixture = AIServiceFixture(provider));

      final invalidConversations = <String, List<ChatMessage>>{
        'an empty conversation': [],
        'a final assistant message': [
          ChatMessage.user('Hello'),
          ChatMessage.model('Hi'),
        ],
        'an empty final user message': [ChatMessage.user('')],
        'a whitespace-only final user message': [ChatMessage.user(' \n\t ')],
      };

      for (final entry in invalidConversations.entries) {
        test('rejects ${entry.key} before contacting the provider', () async {
          await expectLater(
            fixture.service.send(entry.value, appContext: '\nScreen: home'),
            throwsA(
              isA<AIProviderInvalidInputFailure>()
                  .having((failure) => failure.code, 'code', 1005)
                  .having(
                    (failure) => failure.reason,
                    'reason',
                    'INVALID_INPUT',
                  ),
            ),
          );

          expect(fixture.requests, isEmpty);
          expect(fixture.actionHandler.calls, isEmpty);
        });
      }

      test(
        'sends ordered messages once and adds context only to the final copy',
        () async {
          final messages = List<ChatMessage>.unmodifiable([
            ChatMessage.user('Hello'),
            ChatMessage.model('How can I help?'),
            ChatMessage.user('Save dark mode'),
          ]);
          final originalMessages = List<ChatMessage>.of(messages);
          fixture.responses.add(fixture.textReply('Saved'));

          expect(
            await fixture.service.send(
              messages,
              appContext: '\nScreen: settings',
            ),
            'Saved',
          );

          expect(fixture.sentMessages, [
            {'role': 'user', 'content': 'Hello'},
            {'role': 'assistant', 'content': 'How can I help?'},
            {'role': 'user', 'content': 'Save dark mode\nScreen: settings'},
          ]);
          expect(messages, orderedEquals(originalMessages));
          expect(messages.last.message, 'Save dark mode');
        },
      );

      test(
        'keeps the submitted conversation when the caller changes its list',
        () async {
          final messages = [ChatMessage.user('Save dark mode')];
          fixture.responses.addAll([
            fixture.toolReply(),
            fixture.textReply('Saved'),
          ]);

          final reply = fixture.service.send(messages);
          messages
            ..clear()
            ..add(ChatMessage.user('Another request'));

          expect(await reply, 'Saved');
          expect(fixture.sentMessages, [
            {'role': 'user', 'content': 'Save dark mode'},
          ]);
          expect(messages.single.message, 'Another request');
        },
      );

      test('executes the requested tool and returns the final reply', () async {
        fixture.responses.addAll([
          fixture.toolReply(),
          fixture.textReply('Saved'),
        ]);

        expect(
          await fixture.service.send([ChatMessage.user('Save dark mode')]),
          'Saved',
        );

        final call = fixture.actionHandler.calls.single;
        expect(call.functionName, 'save_value');
        expect(call.functionArgs, {'value': 'dark'});
        expect(fixture.toolResult, {'result': 'saved'});
        expect(fixture.requests, hasLength(2));
      });

      test('returns an action failure to the model and continues', () async {
        final failure = StateError('Permission denied');
        fixture.actionHandler.result = Left(failure);
        fixture.responses.addAll([
          fixture.toolReply(),
          fixture.textReply('Could not save'),
        ]);

        expect(
          await fixture.service.send([ChatMessage.user('Save dark mode')]),
          'Could not save',
        );

        expect(fixture.actionHandler.calls, hasLength(1));
        expect(fixture.toolResult, {'error': failure.toString()});
        expect(fixture.requests, hasLength(2));
      });

      test(
        'surfaces a reply without text as an empty-response failure',
        () async {
          fixture.responses.add(fixture.emptyReply());

          await expectLater(
            fixture.service.send([ChatMessage.user('Hello')]),
            throwsA(isA<AIProviderEmptyResponseFailure>()),
          );

          expect(fixture.actionHandler.calls, isEmpty);
        },
      );

      test('terminates repeated tool calls at the configured limit', () async {
        fixture.responses.addAll(
          List.generate(
            AIConstants.maxToolRounds + 1,
            (_) => fixture.toolReply(),
          ),
        );

        await expectLater(
          fixture.service.send([ChatMessage.user('Save dark mode')]),
          throwsA(isA<AIProviderTooManyCallsFailure>()),
        );

        expect(
          fixture.actionHandler.calls,
          hasLength(AIConstants.maxToolRounds),
        );
        // Gemini reads one follow-up response to detect another tool request.
        expect(
          fixture.requests.length,
          lessThanOrEqualTo(AIConstants.maxToolRounds + 1),
        );
      });
    });
  }
}
