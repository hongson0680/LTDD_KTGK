import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class TeacherApi {
  TeacherApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String baseUrl = defaultApiBaseUrl;
  String? _accessToken;
  String? _username;
  String? _displayName;

  bool get isConnected => _accessToken != null;
  String? get username => _username;
  String? get displayName => _displayName;

  Future<void> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    this.baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final response = await _client.post(
      _uri('/api/TokenAuth/Authenticate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userNameOrEmailAddress': username,
        'password': password,
        'rememberClient': false,
      }),
    );
    final data = _decode(response);
    final result = _unwrap(data);
    final token = result['accessToken'] as String?;
    if (token == null || token.isEmpty)
      throw TeacherApiException('Backend không trả về access token.');
    _accessToken = token;
    _username = username;
    final user = result['user'];
    if (user is Map) {
      final name = (user['name'] as String?)?.trim();
      final surname = (user['surname'] as String?)?.trim();
      final full = [
        surname,
        name,
      ].where((s) => s != null && s.isNotEmpty).join(' ');
      _displayName = full.isNotEmpty ? full : username;
    } else {
      _displayName = username;
    }
  }

  Future<List<TeacherExam>> getExams() async {
    final data = _unwrap(
      await _get('/api/services/app/Exam/GetTeacherExamList'),
    );
    if (data is! List)
      throw TeacherApiException('Phản hồi danh sách đề không đúng định dạng.');
    return data
        .map(
          (item) =>
              TeacherExam.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<TeacherExamPreview> previewFile({
    required String name,
    required List<int> bytes,
  }) async {
    final data = _unwrap(
      await _post('/api/services/app/Exam/PreviewImport', {
        'fileName': name,
        'fileContentBase64': base64Encode(bytes),
      }),
    );
    return TeacherExamPreview.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<TeacherImportResult> importDraft({
    required String name,
    required List<int> bytes,
  }) async {
    final data = _unwrap(
      await _post('/api/services/app/Exam/ImportDraft', {
        'fileName': name,
        'fileContentBase64': base64Encode(bytes),
      }),
    );
    return TeacherImportResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<TeacherExamPreview> getPreview(int id) async {
    final data = _unwrap(
      await _get('/api/services/app/Exam/GetPreview?id=$id'),
    );
    return TeacherExamPreview.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> updateExam({
    required int id,
    required String title,
    required String description,
    required int durationMinutes,
    required List<Map<String, Object?>> groups,
  }) => _put('/api/services/app/Exam/Update', {
    'id': id,
    'title': title,
    'description': description,
    'durationMinutes': durationMinutes,
    'groups': groups,
  });

  Future<void> publish(int id) async =>
      _post('/api/services/app/Exam/Publish', {'id': id});

  Future<void> close(int id) async =>
      _post('/api/services/app/Exam/Close', {'id': id});

  Future<TeacherExamStatistics> getStatistics(int id) async {
    final data = _unwrap(
      await _get('/api/services/app/Exam/GetStatistics?id=$id'),
    );
    return TeacherExamStatistics.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  void logout() {
    _accessToken = null;
    _username = null;
    _displayName = null;
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _get(String path) =>
      _send(_client.get(_uri(path), headers: _headers));

  Future<dynamic> _post(String path, Map<String, Object?> body) => _send(
    _client.post(_uri(path), headers: _headers, body: jsonEncode(body)),
  );

  Future<dynamic> _put(String path, Map<String, Object?> body) => _send(
    _client.put(_uri(path), headers: _headers, body: jsonEncode(body)),
  );

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  Future<dynamic> _send(Future<http.Response> request) async =>
      _decode(await request);

  dynamic _decode(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw TeacherApiException(
        'Backend trả về phản hồi không đọc được (${response.statusCode}).',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data is Map ? data['error'] : null;
      final message = error is Map ? error['message'] : null;
      throw TeacherApiException(
        message?.toString() ?? 'Yêu cầu thất bại (${response.statusCode}).',
      );
    }
    return data;
  }

  dynamic _unwrap(dynamic data) =>
      data is Map && data.containsKey('result') ? data['result'] : data;
}

class TeacherApiException implements Exception {
  const TeacherApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TeacherExam {
  const TeacherExam({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.totalQuestions,
    required this.isPublished,
    required this.status,
    required this.creationTime,
    required this.attemptCount,
    this.description = '',
    this.sourceFileName = '',
  });
  final int id, durationMinutes, totalQuestions, attemptCount;
  final bool isPublished;
  final String title, status, creationTime, description, sourceFileName;
  bool get isDraft => status.toLowerCase() == 'draft';

  factory TeacherExam.fromJson(Map<String, dynamic> json) => TeacherExam(
    id: (json['id'] as num).toInt(),
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
    totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
    isPublished: json['isPublished'] == true,
    status: json['status']?.toString() ?? 'Draft',
    creationTime: json['creationTime']?.toString() ?? '',
    sourceFileName: json['sourceFileName']?.toString() ?? '',
    attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
  );
}

class TeacherExamPreview {
  const TeacherExamPreview({
    required this.title,
    required this.durationMinutes,
    required this.totalQuestions,
    required this.groups,
    this.groupCount = 0,
    this.sourceFileName = '',
    this.description = '',
    this.status = 'Draft',
    this.isPublished = false,
  });
  final String title, sourceFileName, description, status;
  final bool isPublished;
  final int durationMinutes, totalQuestions, groupCount;
  final List<TeacherQuestionGroup> groups;

  factory TeacherExamPreview.fromJson(Map<String, dynamic> json) =>
      TeacherExamPreview(
        title: json['title']?.toString() ?? '',
        sourceFileName: json['sourceFileName']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        status: json['status']?.toString() ?? 'Draft',
        isPublished: json['isPublished'] == true,
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
        groupCount: (json['groupCount'] as num?)?.toInt() ?? 0,
        groups: (json['groups'] as List? ?? [])
            .map(
              (g) => TeacherQuestionGroup.fromJson(
                Map<String, dynamic>.from(g as Map),
              ),
            )
            .toList(),
      );
}

class TeacherQuestionGroup {
  const TeacherQuestionGroup({
    required this.id,
    required this.partType,
    required this.order,
    required this.questions,
    this.instructionText = '',
    this.passageText = '',
    this.imageUrl = '',
  });
  final int id;
  final int partType, order;
  final String instructionText, passageText, imageUrl;
  final List<TeacherQuestion> questions;

  factory TeacherQuestionGroup.fromJson(Map<String, dynamic> json) =>
      TeacherQuestionGroup(
        id: (json['id'] as num?)?.toInt() ?? 0,
        partType: (json['partType'] as num?)?.toInt() ?? 5,
        order: (json['order'] as num?)?.toInt() ?? 0,
        instructionText: json['instructionText']?.toString() ?? '',
        passageText: json['passageText']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString() ?? '',
        questions: (json['questions'] as List? ?? [])
            .map(
              (q) =>
                  TeacherQuestion.fromJson(Map<String, dynamic>.from(q as Map)),
            )
            .toList(),
      );
}

class TeacherQuestion {
  const TeacherQuestion({
    required this.id,
    required this.questionNumber,
    required this.questionText,
    required this.correctAnswer,
    required this.hint,
    required this.options,
    this.shuffleQuestion = false,
    this.shuffleAnswers = false,
  });
  final int id;
  final int questionNumber;
  final String questionText, correctAnswer, hint;
  final bool shuffleQuestion, shuffleAnswers;
  final List<TeacherOption> options;

  factory TeacherQuestion.fromJson(Map<String, dynamic> json) =>
      TeacherQuestion(
        id: (json['id'] as num?)?.toInt() ?? 0,
        questionNumber: (json['questionNumber'] as num?)?.toInt() ?? 0,
        questionText: json['questionText']?.toString() ?? '',
        correctAnswer: json['correctAnswer']?.toString() ?? '',
        hint: json['hint']?.toString() ?? '',
        shuffleQuestion: json['shuffleQuestion'] == true,
        shuffleAnswers: json['shuffleAnswers'] == true,
        options: (json['answerOptions'] as List? ?? [])
            .map(
              (o) =>
                  TeacherOption.fromJson(Map<String, dynamic>.from(o as Map)),
            )
            .toList(),
      );
}

class TeacherOption {
  const TeacherOption({
    required this.id,
    required this.label,
    required this.content,
    required this.displayOrder,
  });
  final int id;
  final String label, content;
  final int displayOrder;
  factory TeacherOption.fromJson(Map<String, dynamic> json) => TeacherOption(
    id: (json['id'] as num?)?.toInt() ?? 0,
    label: json['label']?.toString() ?? '',
    content: json['content']?.toString() ?? '',
    displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
  );
}

class TeacherImportResult {
  const TeacherImportResult({
    required this.examId,
    required this.title,
    required this.durationMinutes,
    required this.totalQuestions,
    required this.groupCount,
    required this.status,
  });
  final int examId, durationMinutes, totalQuestions, groupCount;
  final String title, status;
  factory TeacherImportResult.fromJson(Map<String, dynamic> json) =>
      TeacherImportResult(
        examId: (json['examId'] as num).toInt(),
        title: json['title']?.toString() ?? '',
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
        groupCount: (json['groupCount'] as num?)?.toInt() ?? 0,
        status: json['status']?.toString() ?? 'Draft',
      );
}

class TeacherExamStatistics {
  const TeacherExamStatistics({
    required this.examId,
    required this.attemptCount,
    required this.averageScore,
    required this.onTimeAttemptCount,
    required this.onTimeRate,
    required this.partAccuracies,
    required this.mostIncorrectQuestions,
  });
  final int examId, attemptCount;
  final int onTimeAttemptCount;
  final double averageScore, onTimeRate;
  final List<TeacherPartAccuracy> partAccuracies;
  final List<TeacherIncorrectQuestion> mostIncorrectQuestions;
  factory TeacherExamStatistics.fromJson(Map<String, dynamic> json) =>
      TeacherExamStatistics(
        examId: (json['examId'] as num?)?.toInt() ?? 0,
        attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
        averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0,
        onTimeAttemptCount: (json['onTimeAttemptCount'] as num?)?.toInt() ?? 0,
        onTimeRate: (json['onTimeRate'] as num?)?.toDouble() ?? 0,
        partAccuracies: (json['partAccuracies'] as List? ?? [])
            .map((p) => TeacherPartAccuracy.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList(),
        mostIncorrectQuestions: (json['mostIncorrectQuestions'] as List? ?? [])
            .map(
              (q) => TeacherIncorrectQuestion.fromJson(
                Map<String, dynamic>.from(q as Map),
              ),
            )
            .toList(),
      );
}

class TeacherPartAccuracy {
  const TeacherPartAccuracy({
    required this.partType,
    required this.questionCount,
    required this.correctCount,
    required this.accuracyPercent,
  });
  final int partType, questionCount, correctCount;
  final double accuracyPercent;

  factory TeacherPartAccuracy.fromJson(Map<String, dynamic> json) =>
      TeacherPartAccuracy(
        partType: (json['partType'] as num?)?.toInt() ?? 0,
        questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
        correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
        accuracyPercent: (json['accuracyPercent'] as num?)?.toDouble() ?? 0,
      );
}

class TeacherIncorrectQuestion {
  const TeacherIncorrectQuestion({
    required this.questionNumber,
    required this.partType,
    required this.incorrectCount,
    required this.incorrectRate,
  });
  final int questionNumber, partType, incorrectCount;
  final double incorrectRate;
  factory TeacherIncorrectQuestion.fromJson(Map<String, dynamic> json) =>
      TeacherIncorrectQuestion(
        questionNumber: (json['questionNumber'] as num?)?.toInt() ?? 0,
        partType: (json['partType'] as num?)?.toInt() ?? 0,
        incorrectCount: (json['incorrectCount'] as num?)?.toInt() ?? 0,
        incorrectRate: (json['incorrectRate'] as num?)?.toDouble() ?? 0,
      );
}
