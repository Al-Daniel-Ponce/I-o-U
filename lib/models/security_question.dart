/// Represents a pre-defined security question option.
///
/// OOP principle: Encapsulation — the full catalogue of questions lives here
/// as a typed constant list; no screen hard-codes question strings.
class SecurityQuestion {
  final String id;
  final String question;

  const SecurityQuestion({required this.id, required this.question});

  // ── Catalogue ──────────────────────────────────────────────────────────────

  static const List<SecurityQuestion> catalogue = [
    SecurityQuestion(id: 'pet',        question: "What is the name of your first pet?"),
    SecurityQuestion(id: 'dog',        question: "What is the name of your dog?"),
    SecurityQuestion(id: 'mother',     question: "What is your mother's maiden name?"),
    SecurityQuestion(id: 'school',     question: "What was the name of your first school?"),
    SecurityQuestion(id: 'city',       question: "In what city were you born?"),
    SecurityQuestion(id: 'bestfriend', question: "What is the name of your childhood best friend?"),
    SecurityQuestion(id: 'street',     question: "What street did you grow up on?"),
    SecurityQuestion(id: 'car',        question: "What was the make of your first car?"),
    SecurityQuestion(id: 'teacher',    question: "What was your favorite teacher's name?"),
    SecurityQuestion(id: 'sport',      question: "What sport did you play as a child?"),
  ];

  /// Looks up a question by its [id]. Returns null if not found.
  static SecurityQuestion? fromId(String id) {
    try {
      return catalogue.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Holds the user's chosen question + answer pair.
///
/// OOP principle: Single Responsibility — pure data container;
/// persistence is handled by [DatabaseHelper].
class SecurityAnswer {
  final String questionId;
  final String answer; // stored lower-cased and trimmed

  const SecurityAnswer({required this.questionId, required this.answer});

  /// Normalise before comparing: lowercase + trim.
  bool matches(String input) =>
      input.trim().toLowerCase() == answer;

  SecurityQuestion? get question => SecurityQuestion.fromId(questionId);
}