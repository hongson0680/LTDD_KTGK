/// Typed models for Student Exam API, matching Backend DTOs.
DateTime _parseApiDateTime(String value) {
  // SQL Server drops DateTimeKind when it reads a UTC value back. The API can
  // therefore return a UTC timestamp without a trailing Z or offset. Preserve
  // that value as UTC instead of interpreting it in the device's local zone.
  final hasTimezone = RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$', caseSensitive: false)
      .hasMatch(value);
  return DateTime.parse(hasTimezone ? value : '${value}Z').toUtc();
}

class StudentExamListItem {
  const StudentExamListItem({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.totalQuestions,
    required this.hasInProgressAttempt,
    required this.hasCompletedAttempt,
  });

  final int id;
  final String title;
  final String description;
  final int durationMinutes;
  final int totalQuestions;
  final bool hasInProgressAttempt;
  final bool hasCompletedAttempt;

  factory StudentExamListItem.fromJson(Map<String, dynamic> json) =>
      StudentExamListItem(
        id: (json['id'] as num).toInt(),
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
        hasInProgressAttempt: json['hasInProgressAttempt'] == true,
        hasCompletedAttempt: json['hasCompletedAttempt'] == true,
      );
}

class StudentAttemptHistory {
  const StudentAttemptHistory({
    required this.attemptId,
    required this.examId,
    required this.examTitle,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.isPractice,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalSkipped,
    required this.score,
  });

  final int attemptId;
  final int examId;
  final String examTitle;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final bool isPractice;
  final int totalCorrect;
  final int totalWrong;
  final int totalSkipped;
  final int score;

  factory StudentAttemptHistory.fromJson(Map<String, dynamic> json) =>
      StudentAttemptHistory(
        attemptId: (json['attemptId'] as num).toInt(),
        examId: (json['examId'] as num).toInt(),
        examTitle: json['examTitle']?.toString() ?? '',
        startTime: _parseApiDateTime(json['startTime'] as String),
        endTime: json['endTime'] != null
            ? _parseApiDateTime(json['endTime'] as String)
            : null,
        status: json['status']?.toString() ?? '',
        isPractice: json['isPractice'] == true,
        totalCorrect: (json['totalCorrect'] as num?)?.toInt() ?? 0,
        totalWrong: (json['totalWrong'] as num?)?.toInt() ?? 0,
        totalSkipped: (json['totalSkipped'] as num?)?.toInt() ?? 0,
        score: (json['score'] as num?)?.toInt() ?? 0,
      );
}

class StudentAttempt {
  const StudentAttempt({
    required this.attemptId,
    required this.examId,
    required this.examTitle,
    required this.durationMinutes,
    required this.startTime,
    required this.expireTime,
    this.endTime,
    required this.status,
    required this.isResult,
    this.totalCorrect,
    this.totalWrong,
    this.totalSkipped,
    this.score,
    required this.groups,
  });

  final int attemptId;
  final int examId;
  final String examTitle;
  final int durationMinutes;
  final DateTime startTime;
  final DateTime expireTime;
  final DateTime? endTime;
  final String status;
  final bool isResult;
  final int? totalCorrect;
  final int? totalWrong;
  final int? totalSkipped;
  final int? score;
  final List<StudentQuestionGroup> groups;

  factory StudentAttempt.fromJson(Map<String, dynamic> json) => StudentAttempt(
        attemptId: (json['attemptId'] as num).toInt(),
        examId: (json['examId'] as num).toInt(),
        examTitle: json['examTitle']?.toString() ?? '',
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        startTime: _parseApiDateTime(json['startTime'] as String),
        expireTime: _parseApiDateTime(json['expireTime'] as String),
        endTime: json['endTime'] != null
            ? _parseApiDateTime(json['endTime'] as String)
            : null,
        status: json['status']?.toString() ?? '',
        isResult: json['isResult'] == true,
        totalCorrect: (json['totalCorrect'] as num?)?.toInt(),
        totalWrong: (json['totalWrong'] as num?)?.toInt(),
        totalSkipped: (json['totalSkipped'] as num?)?.toInt(),
        score: (json['score'] as num?)?.toInt(),
        groups: (json['groups'] as List? ?? [])
            .map((g) => StudentQuestionGroup.fromJson(
                Map<String, dynamic>.from(g as Map)))
            .toList(),
      );
}

class StudentQuestionGroup {
  const StudentQuestionGroup({
    required this.partType,
    required this.instructionText,
    required this.passageText,
    required this.imageUrl,
    required this.questions,
  });

  final int partType;
  final String instructionText;
  final String passageText;
  final String imageUrl;
  final List<StudentQuestion> questions;

  factory StudentQuestionGroup.fromJson(Map<String, dynamic> json) =>
      StudentQuestionGroup(
        partType: (json['partType'] as num?)?.toInt() ?? 5,
        instructionText: json['instructionText']?.toString() ?? '',
        passageText: json['passageText']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString() ?? '',
        questions: (json['questions'] as List? ?? [])
            .map((q) => StudentQuestion.fromJson(
                Map<String, dynamic>.from(q as Map)))
            .toList(),
      );
}

class StudentQuestion {
  const StudentQuestion({
    required this.id,
    required this.questionNumber,
    required this.questionText,
    this.selectedOptionId,
    this.correctAnswer,
    this.hint,
    required this.options,
  });

  final int id;
  final int questionNumber;
  final String questionText;
  final int? selectedOptionId;
  final String? correctAnswer;
  final String? hint;
  final List<StudentAnswerOption> options;

  factory StudentQuestion.fromJson(Map<String, dynamic> json) => StudentQuestion(
        id: (json['id'] as num).toInt(),
        questionNumber: (json['questionNumber'] as num).toInt(),
        questionText: json['questionText']?.toString() ?? '',
        selectedOptionId: (json['selectedOptionId'] as num?)?.toInt(),
        correctAnswer: json['correctAnswer']?.toString(),
        hint: json['hint']?.toString(),
        options: (json['options'] as List? ?? [])
            .map((o) => StudentAnswerOption.fromJson(
                Map<String, dynamic>.from(o as Map)))
            .toList(),
      );
}

class StudentAnswerOption {
  const StudentAnswerOption({
    required this.id,
    required this.label,
    required this.content,
  });

  final int id;
  final String label;
  final String content;

  factory StudentAnswerOption.fromJson(Map<String, dynamic> json) =>
      StudentAnswerOption(
        id: (json['id'] as num).toInt(),
        label: json['label']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
      );
}
