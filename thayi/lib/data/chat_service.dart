/// Stub for the assistant. A real API call will be swapped in behind
/// [ChatService] later. Answers are returned as ids so the reply is rendered
/// in whichever language she is using.
library;

enum ChatAnswer {
  food1,
  food2,
  food3,
  rest1,
  rest2,
  rest3,
  after1,
  after2,
  after3,
  medicineRefusal,
  fallback,
}

class ChatReply {
  const ChatReply({required this.answer});

  final ChatAnswer answer;

  /// When the assistant could not answer, the UI offers to pass the question
  /// to her ASHA worker instead.
  bool get canAnswer => answer != ChatAnswer.fallback;
}

abstract class ChatService {
  /// [preferredAnswer] is set when she tapped a suggestion chip, so the mock
  /// does not have to guess which canned answer she meant.
  Future<ChatReply> ask(String question, {ChatAnswer? preferredAnswer});
}

enum ChatTopic { food, rest, afterDelivery }

class SuggestedQuestion {
  const SuggestedQuestion({
    required this.topic,
    required this.id,
    required this.answer,
  });

  final ChatTopic topic;

  /// Matches the `qFood1`-style key in the ARB files.
  final String id;
  final ChatAnswer answer;
}

const kSuggestedQuestions = <SuggestedQuestion>[
  SuggestedQuestion(
      topic: ChatTopic.food, id: 'qFood1', answer: ChatAnswer.food1),
  SuggestedQuestion(
      topic: ChatTopic.food, id: 'qFood2', answer: ChatAnswer.food2),
  SuggestedQuestion(
      topic: ChatTopic.food, id: 'qFood3', answer: ChatAnswer.food3),
  SuggestedQuestion(
      topic: ChatTopic.rest, id: 'qRest1', answer: ChatAnswer.rest1),
  SuggestedQuestion(
      topic: ChatTopic.rest, id: 'qRest2', answer: ChatAnswer.rest2),
  SuggestedQuestion(
      topic: ChatTopic.rest, id: 'qRest3', answer: ChatAnswer.rest3),
  SuggestedQuestion(
      topic: ChatTopic.afterDelivery, id: 'qAfter1', answer: ChatAnswer.after1),
  SuggestedQuestion(
      topic: ChatTopic.afterDelivery, id: 'qAfter2', answer: ChatAnswer.after2),
  SuggestedQuestion(
      topic: ChatTopic.afterDelivery, id: 'qAfter3', answer: ChatAnswer.after3),
];

class MockChatService implements ChatService {
  const MockChatService({this.delay = const Duration(milliseconds: 900)});

  final Duration delay;

  /// Anything about medicines or doses is refused outright, in the client.
  static const _medicineTerms = [
    'ಮಾತ್ರೆ',
    'ಔಷಧ',
    'ಔಷಧಿ',
    'ಡೋಸ್',
    'ಇಂಜೆಕ್ಷನ್',
    'ಗುಳಿಗೆ',
    'medicine',
    'tablet',
    'dose',
    'dosage',
    'syrup',
    'injection',
    'antibiotic',
    'painkiller',
  ];

  static const _topicTerms = <ChatAnswer, List<String>>{
    ChatAnswer.food1: [
      'ಏನು ತಿನ್ನ',
      'ಆಹಾರ',
      'ಊಟ',
      'what to eat',
      'what should i eat',
      'diet',
      'food'
    ],
    ChatAnswer.food2: ['ಚಹಾ', 'ಕಾಫಿ', 'ಟೀ', 'tea', 'coffee'],
    ChatAnswer.food3: [
      'ವಾಕರಿಕೆ',
      'ವಾಂತಿ',
      'ಹೊಟ್ಟೆ ತೊಳಸ',
      'vomit',
      'nausea',
      'morning sickness'
    ],
    ChatAnswer.rest1: [
      'ವಿಶ್ರಾಂತಿ',
      'ನಿದ್ದೆ',
      'ಮಲಗ',
      'rest',
      'sleep',
      'lie down'
    ],
    ChatAnswer.rest2: [
      'ಕೆಲಸ',
      'ಮನೆ ಕೆಲಸ',
      'ಭಾರ',
      'work',
      'housework',
      'lifting'
    ],
    ChatAnswer.rest3: [
      'ಪ್ರಯಾಣ',
      'ತವರು',
      'ಬಸ್',
      'travel',
      'journey',
      'bus',
      'train'
    ],
    ChatAnswer.after1: [
      'ಹಾಲುಣಿಸ',
      'ಎದೆ ಹಾಲು',
      'ಹಾಲು',
      'breastfeed',
      'feeding',
      'milk'
    ],
    ChatAnswer.after2: [
      'ಹೆರಿಗೆ ನಂತರ',
      'ಹೆರಿಗೆಯ ನಂತರ',
      'after delivery',
      'after birth',
      'recovery'
    ],
    ChatAnswer.after3: [
      'ಲಸಿಕೆ',
      'ಚುಚ್ಚುಮದ್ದು',
      'vaccine',
      'vaccination',
      'immunisation',
      'immunization'
    ],
  };

  @override
  Future<ChatReply> ask(String question, {ChatAnswer? preferredAnswer}) async {
    await Future.delayed(delay);
    if (preferredAnswer != null) return ChatReply(answer: preferredAnswer);

    final text = question.toLowerCase();

    for (final term in _medicineTerms) {
      if (text.contains(term)) {
        return const ChatReply(answer: ChatAnswer.medicineRefusal);
      }
    }

    for (final entry in _topicTerms.entries) {
      for (final term in entry.value) {
        if (text.contains(term)) return ChatReply(answer: entry.key);
      }
    }

    return const ChatReply(answer: ChatAnswer.fallback);
  }
}
