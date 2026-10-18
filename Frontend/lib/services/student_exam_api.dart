import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'student_exam_models.dart';

class StudentExamApi {
  StudentExamApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  String baseUrl = defaultApiBaseUrl;
  String? _token;
  String? _username;
  String? _displayName;
  bool get isConnected => _token != null;
  String? get username => _username;
  String? get displayName => _displayName;

  void logout() {
    _token = null;
    _username = null;
    _displayName = null;
  }

  Future<void> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    this.baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final data = _unwrap(
      await _send(
        'POST',
        '/api/TokenAuth/Authenticate',
        body: {
          'userNameOrEmailAddress': username,
          'password': password,
          'rememberClient': false,
        },
      ),
    );
    final token = data['accessToken']?.toString();
    if (token == null || token.isEmpty)
      throw StudentApiException('Backend không trả về access token.');
    _token = token;
    _username = username;
    final user = data['user'];
    if (user is Map) {
      final name = (user['name'] as String?)?.trim();
      final surname = (user['surname'] as String?)?.trim();
      final full = [surname, name].where((s) => s != null && s.isNotEmpty).join(' ');
      _displayName = full.isNotEmpty ? full : username;
    } else {
      _displayName = username;
    }
  }

  Future<List<StudentExamListItem>> getPublishedExams() async {
    final data = _unwrap(
      await _send('GET', '/api/services/app/StudentExam/GetPublishedExams'),
    );
    if (data is! List) {
      throw const StudentApiException(
        'Phản hồi danh sách đề thi không đúng định dạng.',
      );
    }
    return data
        .map((e) =>
            StudentExamListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<StudentAttempt> start(int examId) async {
    final data = _unwrap(
      await _send('POST', '/api/services/app/StudentExam/Start',
          body: {'id': examId}),
    );
    return StudentAttempt.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<StudentAttempt> startPractice(int examId) async {
    final data = _unwrap(
      await _send('POST', '/api/services/app/StudentExam/StartPractice',
          body: {'id': examId}),
    );
    return StudentAttempt.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<StudentAttemptHistory>> getMyAttempts() async {
    final data = _unwrap(
      await _send('GET', '/api/services/app/StudentExam/GetMyAttempts'),
    );
    if (data is! List) {
      throw const StudentApiException(
        'Phản hồi lịch sử không đúng định dạng.',
      );
    }
    return data
        .map((e) => StudentAttemptHistory.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<StudentAttempt> getAttempt(int attemptId) async {
    final data = _unwrap(
      await _send(
          'GET', '/api/services/app/StudentExam/GetAttempt?id=$attemptId'),
    );
    return StudentAttempt.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<StudentAttempt> saveAnswer({
    required int attemptId,
    required int questionId,
    int? selectedOptionId,
    int? timeSpentSeconds,
  }) async {
    final data = _unwrap(
      await _send(
        'POST',
        '/api/services/app/StudentExam/SaveAnswer',
        body: {
          'attemptId': attemptId,
          'questionId': questionId,
          'selectedOptionId': selectedOptionId,
          'timeSpentSeconds': timeSpentSeconds,
        },
      ),
    );
    return StudentAttempt.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<StudentAttempt> submit(int attemptId) async {
    final data = _unwrap(
      await _send('POST', '/api/services/app/StudentExam/Submit',
          body: {'id': attemptId}),
    );
    return StudentAttempt.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<StudentAttempt> getResult(int attemptId) async {
    final data = _unwrap(
      await _send('GET', '/api/services/app/StudentExam/GetResult?id=$attemptId'),
    );
    return StudentAttempt.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    final response = method == 'GET'
        ? await _client.get(uri, headers: headers)
        : await _client.post(uri, headers: headers, body: jsonEncode(body));
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw StudentApiException(
        'Phản hồi Backend không đọc được (${response.statusCode}).',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data is Map ? data['error'] : null;
      throw StudentApiException(
        error is Map
            ? (error['message']?.toString() ?? 'Yêu cầu thất bại.')
            : 'Yêu cầu thất bại (${response.statusCode}).',
      );
    }
    return data;
  }

  dynamic _unwrap(dynamic value) =>
      value is Map && value.containsKey('result') ? value['result'] : value;
}

class StudentApiException implements Exception {
  const StudentApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
