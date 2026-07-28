import 'package:flutter_test/flutter_test.dart';
import 'package:setu_thayi/data/chat_service.dart';

void main() {
  const service = MockChatService(
    delay: Duration.zero,
    reply: 'Walking a little every day is good for you.',
  );

  group('medicines are refused in the client', () {
    // This must not depend on the server, the model, or a connection. A woman
    // asking how much of something to take never gets a number from software.
    const questions = [
      'how many paracetamol tablets can I take',
      'what dose of iron should I take',
      'can I take ibuprofen for back pain',
      'is this syrup safe',
      'doctor gave an injection, should I take another',
      'ಈ ಮಾತ್ರೆ ತೆಗೆದುಕೊಳ್ಳಬಹುದೇ',
      'ಯಾವ ಔಷಧಿ ಒಳ್ಳೆಯದು',
      'ಎಷ್ಟು ಗುಳಿಗೆ ತೆಗೆದುಕೊಳ್ಳಬೇಕು',
    ];

    for (final q in questions) {
      test(q, () async {
        final reply = await service.ask(q);
        expect(reply.canAnswer, isFalse);
        expect(reply.failure, ChatFailure.medicine);
      });
    }
  });

  test('ordinary questions still get through', () async {
    for (final q in [
      'what should I eat',
      'can I keep working',
      'ಚಹಾ ಕುಡಿಯಬಹುದೇ',
    ]) {
      final reply = await service.ask(q);
      expect(reply.canAnswer, isTrue, reason: q);
      expect(reply.text, isNotEmpty);
    }
  });

  test('with nothing to answer from, it says so instead of guessing', () async {
    const offline = MockChatService(delay: Duration.zero);
    final reply = await offline.ask('what should I eat');
    expect(reply.canAnswer, isFalse);
    expect(reply.failure, ChatFailure.offline);
  });

  test('history serialises to the roles the assistant expects', () {
    const turns = [
      ChatTurn(fromMother: true, text: 'what should I eat'),
      ChatTurn(fromMother: false, text: 'Eat a little more than usual.'),
    ];
    expect(turns.map((t) => t.toJson()['role']).toList(), ['user', 'model']);
  });
}
