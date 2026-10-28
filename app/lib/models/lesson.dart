// Dart model of schema/lesson.schema.json - keep the two in sync.

class LessonFormatException implements Exception {
  LessonFormatException(this.message);
  final String message;
  @override
  String toString() => 'Invalid lesson: $message';
}

T _req<T>(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is T) return v;
  throw LessonFormatException('"$key" is missing or has the wrong type');
}

List<Map<String, dynamic>> _objList(Map<String, dynamic> j, String key,
    {bool optional = false}) {
  final v = j[key];
  if (v == null && optional) return const [];
  if (v is! List) throw LessonFormatException('"$key" must be a list');
  return v.map((e) {
    if (e is Map<String, dynamic>) return e;
    throw LessonFormatException('"$key" must contain objects');
  }).toList();
}

List<String> _strList(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v == null) return const [];
  if (v is! List) throw LessonFormatException('"$key" must be a list');
  return v.map((e) => e.toString()).toList();
}

class Translated {
  const Translated(this.text, this.translation);
  final String text;
  final String translation;

  factory Translated.fromJson(Map<String, dynamic> j) =>
      Translated(_req<String>(j, 'text'), _req<String>(j, 'translation'));

  Map<String, dynamic> toJson() => {'text': text, 'translation': translation};
}

class Homonym {
  const Homonym(this.word, this.meaning, this.translation);
  final String word;
  final String meaning;
  final String translation;

  factory Homonym.fromJson(Map<String, dynamic> j) => Homonym(
      _req<String>(j, 'word'),
      _req<String>(j, 'meaning'),
      _req<String>(j, 'translation'));

  Map<String, dynamic> toJson() =>
      {'word': word, 'meaning': meaning, 'translation': translation};
}

class Sense {
  const Sense({
    required this.partOfSpeech,
    required this.translation,
    required this.definition,
    required this.synonyms,
    required this.antonyms,
    required this.homonyms,
    required this.examples,
  });

  final String partOfSpeech;
  final String translation;
  final String definition;
  final List<String> synonyms;
  final List<String> antonyms;
  final List<Homonym> homonyms;
  final List<Translated> examples;

  factory Sense.fromJson(Map<String, dynamic> j) => Sense(
        partOfSpeech: _req<String>(j, 'partOfSpeech'),
        translation: _req<String>(j, 'translation'),
        definition: _req<String>(j, 'definition'),
        synonyms: _strList(j, 'synonyms'),
        antonyms: _strList(j, 'antonyms'),
        homonyms: _objList(j, 'homonyms', optional: true)
            .map(Homonym.fromJson)
            .toList(),
        examples: _objList(j, 'examples').map(Translated.fromJson).toList(),
      );

  Map<String, dynamic> toJson() => {
        'partOfSpeech': partOfSpeech,
        'translation': translation,
        'definition': definition,
        'synonyms': synonyms,
        'antonyms': antonyms,
        'homonyms': homonyms.map((e) => e.toJson()).toList(),
        'examples': examples.map((e) => e.toJson()).toList(),
      };
}

class Word {
  const Word({required this.word, required this.ipa, required this.senses});
  final String word;
  final String ipa;
  final List<Sense> senses;

  factory Word.fromJson(Map<String, dynamic> j) {
    final senses = _objList(j, 'senses').map(Sense.fromJson).toList();
    if (senses.isEmpty) throw LessonFormatException('a word needs at least one sense');
    return Word(
        word: _req<String>(j, 'word'), ipa: _req<String>(j, 'ipa'), senses: senses);
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        'ipa': ipa,
        'senses': senses.map((e) => e.toJson()).toList(),
      };
}

class GlossaryEntry {
  const GlossaryEntry({
    required this.term,
    required this.lemma,
    required this.partOfSpeech,
    required this.meaning,
    required this.translation,
  });

  final String term;
  final String lemma;
  final String partOfSpeech;
  final String meaning;
  final String translation;

  bool get isPhrase => term.trim().contains(RegExp(r'\s'));

  factory GlossaryEntry.fromJson(Map<String, dynamic> j) => GlossaryEntry(
        term: _req<String>(j, 'term'),
        lemma: _req<String>(j, 'lemma'),
        partOfSpeech: _req<String>(j, 'partOfSpeech'),
        meaning: _req<String>(j, 'meaning'),
        translation: _req<String>(j, 'translation'),
      );

  Map<String, dynamic> toJson() => {
        'term': term,
        'lemma': lemma,
        'partOfSpeech': partOfSpeech,
        'meaning': meaning,
        'translation': translation,
      };
}

class StoryParagraph {
  const StoryParagraph(this.sentences);
  final List<Translated> sentences;

  factory StoryParagraph.fromJson(Map<String, dynamic> j) =>
      StoryParagraph(_objList(j, 'sentences').map(Translated.fromJson).toList());

  Map<String, dynamic> toJson() =>
      {'sentences': sentences.map((e) => e.toJson()).toList()};
}

class Story {
  const Story({
    required this.title,
    required this.titleTranslation,
    required this.paragraphs,
    required this.glossary,
  });

  final String title;
  final String titleTranslation;
  final List<StoryParagraph> paragraphs;
  final List<GlossaryEntry> glossary;

  factory Story.fromJson(Map<String, dynamic> j) => Story(
        title: _req<String>(j, 'title'),
        titleTranslation: _req<String>(j, 'titleTranslation'),
        paragraphs:
            _objList(j, 'paragraphs').map(StoryParagraph.fromJson).toList(),
        glossary: _objList(j, 'glossary').map(GlossaryEntry.fromJson).toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'titleTranslation': titleTranslation,
        'paragraphs': paragraphs.map((e) => e.toJson()).toList(),
        'glossary': glossary.map((e) => e.toJson()).toList(),
      };
}

enum QuestionType { choice, text }

class Question {
  const Question({
    required this.type,
    required this.prompt,
    this.promptTranslation,
    this.options = const [],
    required this.answer,
    this.acceptedAnswers = const [],
    this.explanation,
    this.explanationTranslation,
  });

  final QuestionType type;
  final String prompt;
  final String? promptTranslation;
  final List<String> options;
  final String answer;
  final List<String> acceptedAnswers;
  final String? explanation;
  final String? explanationTranslation;

  factory Question.fromJson(Map<String, dynamic> j) {
    final typeName = _req<String>(j, 'type');
    final type = switch (typeName) {
      'choice' => QuestionType.choice,
      'text' => QuestionType.text,
      _ => throw LessonFormatException('unknown question type "$typeName"'),
    };
    return Question(
      type: type,
      prompt: _req<String>(j, 'prompt'),
      promptTranslation: j['promptTranslation'] as String?,
      options: _strList(j, 'options'),
      answer: _req<String>(j, 'answer'),
      acceptedAnswers: _strList(j, 'acceptedAnswers'),
      explanation: j['explanation'] as String?,
      explanationTranslation: j['explanationTranslation'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'prompt': prompt,
        if (promptTranslation != null) 'promptTranslation': promptTranslation,
        if (options.isNotEmpty) 'options': options,
        'answer': answer,
        if (acceptedAnswers.isNotEmpty) 'acceptedAnswers': acceptedAnswers,
        if (explanation != null) 'explanation': explanation,
        if (explanationTranslation != null)
          'explanationTranslation': explanationTranslation,
      };

  static String normalize(String s) => s
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r"[^\w\s']"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// True when [given] matches the answer (case, extra spaces and
  /// punctuation are ignored).
  bool isCorrect(String given) {
    final g = normalize(given);
    if (g.isEmpty) return false;
    return [answer, ...acceptedAnswers].any((a) => normalize(a) == g);
  }
}

class Exercise {
  const Exercise({
    required this.instructions,
    required this.instructionsTranslation,
    required this.questions,
  });

  final String instructions;
  final String instructionsTranslation;
  final List<Question> questions;

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        instructions: _req<String>(j, 'instructions'),
        instructionsTranslation: _req<String>(j, 'instructionsTranslation'),
        questions: _objList(j, 'questions').map(Question.fromJson).toList(),
      );

  Map<String, dynamic> toJson() => {
        'instructions': instructions,
        'instructionsTranslation': instructionsTranslation,
        'questions': questions.map((e) => e.toJson()).toList(),
      };
}

class Grammar {
  const Grammar({
    required this.topic,
    required this.topicTranslation,
    required this.explanation,
    required this.explanationTranslation,
    required this.rules,
    required this.examples,
    required this.exercise,
  });

  final String topic;
  final String topicTranslation;
  final String explanation;
  final String explanationTranslation;
  final List<Translated> rules;
  final List<Translated> examples;
  final Exercise exercise;

  factory Grammar.fromJson(Map<String, dynamic> j) => Grammar(
        topic: _req<String>(j, 'topic'),
        topicTranslation: _req<String>(j, 'topicTranslation'),
        explanation: _req<String>(j, 'explanation'),
        explanationTranslation: _req<String>(j, 'explanationTranslation'),
        rules: _objList(j, 'rules').map(Translated.fromJson).toList(),
        examples: _objList(j, 'examples').map(Translated.fromJson).toList(),
        exercise:
            Exercise.fromJson(_req<Map<String, dynamic>>(j, 'exercise')),
      );

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'topicTranslation': topicTranslation,
        'explanation': explanation,
        'explanationTranslation': explanationTranslation,
        'rules': rules.map((e) => e.toJson()).toList(),
        'examples': examples.map((e) => e.toJson()).toList(),
        'exercise': exercise.toJson(),
      };
}

class Lesson {
  const Lesson({
    required this.schemaVersion,
    required this.date,
    required this.level,
    required this.translationLanguage,
    required this.words,
    this.story,
    required this.grammar,
  });

  final int schemaVersion;
  final String date;
  final String level;
  final String translationLanguage;
  final List<Word> words;
  final Story? story;
  final Grammar grammar;

  factory Lesson.fromJson(Map<String, dynamic> j) {
    final version = j['schemaVersion'] ?? 1;
    if (version is! int || version > 1) {
      throw LessonFormatException(
          'schemaVersion $version is newer than this app understands - update the app');
    }
    final date = _req<String>(j, 'date');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      throw LessonFormatException('bad date "$date"');
    }
    final storyJson = j['story'];
    return Lesson(
      schemaVersion: version,
      date: date,
      level: _req<String>(j, 'level'),
      translationLanguage: _req<String>(j, 'translationLanguage'),
      words: _objList(j, 'words').map(Word.fromJson).toList(),
      story: storyJson is Map<String, dynamic> ? Story.fromJson(storyJson) : null,
      grammar: Grammar.fromJson(_req<Map<String, dynamic>>(j, 'grammar')),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'date': date,
        'level': level,
        'translationLanguage': translationLanguage,
        'words': words.map((e) => e.toJson()).toList(),
        if (story != null) 'story': story!.toJson(),
        'grammar': grammar.toJson(),
      };
}
