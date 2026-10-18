import 'dart:async';

import 'package:flutter/material.dart';

import 'config/api_config.dart';
import 'services/student_exam_api.dart';
import 'services/student_exam_models.dart';

const _studentBlue = Color(0xFF0059BB);
const _studentInk = Color(0xFF161C22);
const _studentMuted = Color(0xFF5B646B);
const _studentLine = Color(0xFFE3E9F0);
const _studentCanvas = Color(0xFFF7F9FF);
const _studentGreen = Color(0xFF16845B);

class StudentPortalShell extends StatefulWidget {
  const StudentPortalShell({required this.onTeacherMode, super.key});
  final VoidCallback onTeacherMode;

  @override
  State<StudentPortalShell> createState() => _StudentPortalShellState();
}

class _StudentPortalShellState extends State<StudentPortalShell> {
  int _tab = 0;
  bool _takingExam = false;
  bool _showResult = false;
  final StudentExamApi _api = StudentExamApi();
  StudentAttempt? _attempt;
  String? _loginError;
  bool _loggingIn = false;
  bool _submitting = false;
  final _baseUrl = TextEditingController(text: defaultApiBaseUrl);
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _baseUrl.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loggingIn = true;
      _loginError = null;
    });
    try {
      await _api.login(
        baseUrl: _baseUrl.text,
        username: _username.text,
        password: _password.text,
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _loginError = e.toString());
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  static const _tabs = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.assignment_outlined),
      selectedIcon: Icon(Icons.assignment),
      label: 'Bài thi',
    ),
    NavigationDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book),
      label: 'Luyện tập',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights),
      label: 'Kết quả',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_circle_outlined),
      selectedIcon: Icon(Icons.account_circle),
      label: 'Tài khoản',
    ),
  ];

  Future<void> _startExam(int examId, {bool practice = false}) async {
    try {
      final attempt = practice
          ? await _api.startPractice(examId)
          : await _api.start(examId);
      if (mounted)
        setState(() {
          _attempt = attempt;
          _takingExam = true;
          _showResult = false;
        });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _openResult(int attemptId) async {
    try {
      final result = await _api.getResult(attemptId);
      if (mounted)
        setState(() {
          _attempt = result;
          _takingExam = false;
          _showResult = true;
        });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _finishExam() async {
    if (_attempt == null || _submitting) return;
    _submitting = true;
    try {
      final result = await _api.submit(_attempt!.attemptId);
      if (mounted)
        setState(() {
          _attempt = result;
          _takingExam = false;
          _showResult = true;
          _tab = 2;
        });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      _submitting = false;
    }
  }

  Widget _currentScreen() {
    if (!_api.isConnected) return _loginScreen();
    if (_takingExam) {
      return StudentExamTakingScreen(
        api: _api,
        attempt: _attempt!,
        onFinish: _finishExam,
      );
    }
    if (_showResult) {
      return StudentResultScreen(
        result: _attempt!,
        onHome: () => setState(() {
          _showResult = false;
          _tab = 0;
        }),
      );
    }
    return switch (_tab) {
      0 => StudentExamListScreen(
        api: _api,
        onStart: _startExam,
        onHistory: () => setState(() => _tab = 2),
      ),
      1 => StudentPracticeScreen(
        api: _api,
        onStart: (id) => _startExam(id, practice: true),
      ),
      2 => StudentHistoryScreen(
        api: _api,
        onOpenResult: _openResult,
        onResume: (examId) => _startExam(examId),
      ),
      _ => StudentAccountScreen(
        api: _api,
        onLogout: _logout,
        onNotifications: _showNotifications,
      ),
    };
  }

  Future<void> _showNotifications() async {
    try {
      final exams = await _api.getPublishedExams();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            children: [
              const Text('Đề thi đang mở', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (exams.isEmpty)
                const ListTile(
                  leading: Icon(Icons.notifications_off_outlined),
                  title: Text('Hiện chưa có đề thi được mở'),
                ),
              for (final exam in exams)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
                  title: Text(exam.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${exam.totalQuestions} câu · ${exam.durationMinutes} phút'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() => _tab = 0);
                  },
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tải được thông báo đề thi: $error')),
        );
      }
    }
  }

  void _logout() {
    _api.logout();
    setState(() {
      _attempt = null;
      _takingExam = false;
      _showResult = false;
      _tab = 0;
      _loginError = null;
      _password.clear();
    });
  }

  Widget _loginScreen() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 38, color: _studentBlue),
              const SizedBox(height: 10),
              const Text(
                'Đăng nhập sinh viên',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: _baseUrl,
                decoration: const InputDecoration(labelText: 'Địa chỉ Backend'),
              ),
              TextField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Tài khoản'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
                onSubmitted: (_) => _login(),
              ),
              if (_loginError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _loginError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loggingIn ? null : _login,
                  child: Text(_loggingIn ? 'Đang đăng nhập...' : 'Đăng nhập'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _studentCanvas,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: _studentBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOEIC Portal',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _studentInk,
                ),
              ),
              Text(
                _takingExam
                    ? 'EXAM IN PROGRESS'
                    : _showResult
                    ? 'TEST RESULT'
                    : 'STUDENT',
                style: const TextStyle(
                  fontSize: 8,
                  letterSpacing: 1.15,
                  color: _studentMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (!_takingExam && !_showResult)
          IconButton(
            tooltip: 'Thông báo',
            onPressed: _showNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        if (MediaQuery.sizeOf(context).width < 420)
          IconButton(
            tooltip: 'Chuyển sang giao diện giảng viên',
            onPressed: widget.onTeacherMode,
            icon: const Icon(Icons.swap_horiz_rounded),
          )
        else
          TextButton.icon(
            onPressed: widget.onTeacherMode,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Giảng viên'),
          ),
        const SizedBox(width: 5),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _studentLine),
      ),
    ),
    body: SafeArea(top: false, child: _currentScreen()),
    bottomNavigationBar: _takingExam || _showResult
        ? null
        : NavigationBar(
            backgroundColor: Colors.white,
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: _tabs,
          ),
  );
}

class StudentExamListScreen extends StatefulWidget {
  const StudentExamListScreen({
    required this.api,
    required this.onStart,
    required this.onHistory,
    super.key,
  });
  final StudentExamApi api;
  final ValueChanged<int> onStart;
  final VoidCallback onHistory;

  @override
  State<StudentExamListScreen> createState() => _StudentExamListScreenState();
}

class _StudentExamListScreenState extends State<StudentExamListScreen> {
  late Future<List<StudentExamListItem>> _exams;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _exams = widget.api.getPublishedExams();
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<StudentExamListItem>>(
    future: _exams,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 36,
                  color: _studentMuted,
                ),
                const SizedBox(height: 10),
                Text(snapshot.error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _exams = widget.api.getPublishedExams()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử tải lại'),
                ),
              ],
            ),
          ),
        );
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final exams = snapshot.data!;
      final filtered = exams.where((exam) {
        final text = '${exam.title} ${exam.description}'.toLowerCase();
        return text.contains(_query.trim().toLowerCase());
      }).toList();
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Đề thi đã xuất bản',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _studentInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Có ' + exams.length.toString() + ' đề thi đang mở.',
            style: const TextStyle(color: _studentMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Tìm đề thi...',
              suffixIcon: IconButton(
                tooltip: 'Làm mới danh sách',
                onPressed: () => setState(() => _exams = widget.api.getPublishedExams()),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            const _StudentNotice(
              icon: Icons.assignment_outlined,
              title: 'Chưa có đề thi',
              text: 'Giảng viên chưa xuất bản đề nào.',
            ),
          for (final exam in filtered)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title.isNotEmpty ? exam.title : 'Đề thi TOEIC',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      exam.description,
                      style: const TextStyle(color: _studentMuted),
                    ),
                    if (exam.hasInProgressAttempt || exam.hasCompletedAttempt) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          avatar: Icon(
                            exam.hasInProgressAttempt
                                ? Icons.play_circle_outline
                                : Icons.check_circle_outline,
                            size: 17,
                            color: exam.hasInProgressAttempt
                                ? _studentBlue
                                : _studentGreen,
                          ),
                          label: Text(
                            exam.hasInProgressAttempt
                                ? 'Đang làm dở'
                                : 'Đã hoàn thành',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${exam.totalQuestions} câu · ${exam.durationMinutes} phút',
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => widget.onStart(exam.id),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          exam.hasInProgressAttempt
                              ? 'Tiếp tục làm bài'
                              : 'Bắt đầu thi',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _StudentExamCard extends StatelessWidget {
  const _StudentExamCard({
    required this.title,
    required this.description,
    required this.type,
    required this.duration,
    required this.count,
    required this.buttonLabel,
    required this.onPressed,
  });
  final String title, description, type, duration, count, buttonLabel;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bookmark_border_rounded,
                color: _studentBlue,
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(
                type,
                style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: .7,
                  color: _studentBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Thao tác với đề luyện tập',
                icon: const Icon(Icons.more_horiz_rounded, color: _studentMuted),
                onSelected: (action) {
                  if (action == 'start') {
                    onPressed();
                  } else {
                    showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (context) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text(description, style: const TextStyle(color: _studentMuted)),
                              const Divider(height: 24),
                              Text('$count · $duration', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    onPressed();
                                  },
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Bắt đầu luyện tập'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'details', child: Text('Thông tin đề')),
                  PopupMenuItem(value: 'start', child: Text('Bắt đầu luyện tập')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: _studentInk,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: _studentMuted,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: _studentMuted,
              ),
              const SizedBox(width: 4),
              Text(
                duration,
                style: const TextStyle(fontSize: 10, color: _studentMuted),
              ),
              const SizedBox(width: 13),
              const Icon(Icons.quiz_outlined, size: 14, color: _studentMuted),
              const SizedBox(width: 4),
              Text(
                count,
                style: const TextStyle(fontSize: 10, color: _studentMuted),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: _studentLine),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    ),
  );
}

class StudentExamTakingScreen extends StatefulWidget {
  const StudentExamTakingScreen({
    required this.api,
    required this.attempt,
    required this.onFinish,
    super.key,
  });
  final StudentExamApi api;
  final StudentAttempt attempt;
  final Future<void> Function() onFinish;
  @override
  State<StudentExamTakingScreen> createState() =>
      _StudentExamTakingScreenState();
}

class _StudentExamTakingScreenState extends State<StudentExamTakingScreen> {
  late StudentAttempt data;
  late List<StudentQuestionGroup> groups;
  late List<_TakingQuestion> questions;
  int index = 0;
  bool busy = false;
  bool _nearEndWarningShown = false;
  bool _expirySubmitted = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    data = widget.attempt;
    flatten();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
        final timeLeft = remaining;
        if (!_nearEndWarningShown &&
            timeLeft > Duration.zero &&
            timeLeft <= const Duration(minutes: 5)) {
          _nearEndWarningShown = true;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Còn 5 phút hoặc ít hơn. Hãy kiểm tra và nộp bài đúng giờ.'),
                duration: Duration(seconds: 6),
              ),
            );
        }
        if (timeLeft == Duration.zero && !_expirySubmitted) {
          _expirySubmitted = true;
          widget.onFinish();
        }
      }
    });
  }

  void flatten() {
    groups = data.groups;
    questions = [];
    for (final g in groups) {
      for (final q in g.questions) {
        questions.add(
          _TakingQuestion(
            question: q,
            partType: g.partType,
            passageText: g.passageText,
            imageUrl: g.imageUrl,
            instructionText: g.instructionText,
          ),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant StudentExamTakingScreen old) {
    super.didUpdateWidget(old);
    if (old.attempt.attemptId != widget.attempt.attemptId) {
      data = widget.attempt;
      _nearEndWarningShown = false;
      _expirySubmitted = false;
      flatten();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Duration get remaining {
    final d = data.expireTime.toUtc();
    final x = d.difference(DateTime.now().toUtc());
    return x.isNegative ? Duration.zero : x;
  }

  int get answered =>
      questions.where((q) => q.question.selectedOptionId != null).length;

  Future<void> _openQuestionNavigator() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Danh sách câu hỏi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('$answered/${questions.length} câu đã trả lời', style: const TextStyle(color: _studentMuted)),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * .55),
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.35,
                  ),
                  itemCount: questions.length,
                  itemBuilder: (context, i) {
                    final item = questions[i];
                    final isCurrent = i == index;
                    final hasAnswer = item.question.selectedOptionId != null;
                    return OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: isCurrent
                            ? _studentBlue
                            : hasAnswer
                                ? const Color(0xFFE5F5EE)
                                : Colors.white,
                        foregroundColor: isCurrent ? Colors.white : _studentInk,
                        side: BorderSide(
                          color: isCurrent ? _studentBlue : hasAnswer ? _studentGreen : _studentLine,
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      onPressed: () {
                        setState(() => index = i);
                        Navigator.pop(sheetContext);
                      },
                      child: Text('${item.question.questionNumber}'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 16,
                children: [
                  _QuestionLegend(color: _studentBlue, label: 'Đang xem'),
                  _QuestionLegend(color: _studentGreen, label: 'Đã trả lời'),
                  _QuestionLegend(color: _studentLine, label: 'Chưa trả lời'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> select(_TakingQuestion q, StudentAnswerOption option) =>
      _saveSelection(q, option.id);

  Future<void> clearSelection(_TakingQuestion q) => _saveSelection(q, null);

  Future<void> _saveSelection(_TakingQuestion q, int? selectedOptionId) async {
    if (busy) return;
    final before = q.question.selectedOptionId;
    setState(() {
      q.question = StudentQuestion(
        id: q.question.id,
        questionNumber: q.question.questionNumber,
        questionText: q.question.questionText,
        selectedOptionId: selectedOptionId,
        correctAnswer: q.question.correctAnswer,
        hint: q.question.hint,
        options: q.question.options,
      );
      busy = true;
    });
    try {
      data = await widget.api.saveAnswer(
        attemptId: data.attemptId,
        questionId: q.question.id,
        selectedOptionId: selectedOptionId,
      );
      flatten();
    } catch (e) {
      if (mounted) {
        setState(() {
          q.question = StudentQuestion(
            id: q.question.id,
            questionNumber: q.question.questionNumber,
            questionText: q.question.questionText,
            selectedOptionId: before,
            correctAnswer: q.question.correctAnswer,
            hint: q.question.hint,
            options: q.question.options,
          );
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    final left = questions.length - answered;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nộp bài?'),
        content: Text('Còn ' + left.toString() + ' câu chưa trả lời.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Làm tiếp'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Nộp bài'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty)
      return const Center(child: Text('Đề thi chưa có câu hỏi.'));
    final q = questions[index];
    final opts = q.question.options;
    final secs = remaining.inSeconds;
    final time = remaining.inHours > 0
        ? remaining.toString().split('.').first
        : '${remaining.inMinutes.toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.examTitle.isNotEmpty
                            ? data.examTitle
                            : 'Bài thi TOEIC',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Đã trả lời ${answered}/${questions.length}'),
                    ],
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: secs < 300 ? Colors.red : _studentBlue,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: const Text('Nộp bài'),
                ),
              ],
            ),
          ),
        ),
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Câu ${q.question.questionNumber} / ${questions.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: questions.isEmpty ? 0 : answered / questions.length,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(5),
                        backgroundColor: const Color(0xFFE6EBF2),
                        color: _studentBlue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _openQuestionNavigator,
                  icon: const Icon(Icons.grid_view_rounded, size: 17),
                  label: const Text('Câu hỏi'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Text(
                'Part ${q.partType} · ${q.instructionText}',
                style: const TextStyle(
                  color: _studentBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (q.passageText.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: SelectableText(q.passageText),
                  ),
                ),
              for (final imagePath
                  in q.imageUrl.split('|').where((path) => path.isNotEmpty))
                Image.network(
                  '${widget.api.baseUrl}$imagePath',
                  errorBuilder: (_, _, _) =>
                      const Text('Không tải được hình trong đề.'),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${q.question.questionNumber}. ${q.question.questionText}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final o in opts)
                        Builder(
                          builder: (context) {
                            final isSelected =
                                q.question.selectedOptionId == o.id;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelected
                                    ? _studentBlue
                                    : null,
                                foregroundColor: isSelected
                                    ? Colors.white
                                    : null,
                                child: Text(o.label),
                              ),
                              title: Text(o.content),
                              selected: isSelected,
                              selectedTileColor: const Color(0xFFE8F1FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected
                                      ? _studentBlue
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              trailing: isSelected
                                  ? IconButton(
                                      tooltip: 'Bỏ chọn đáp án',
                                      onPressed: busy ? null : () => clearSelection(q),
                                      icon: const Icon(
                                        Icons.cancel_outlined,
                                        color: _studentBlue,
                                      ),
                                    )
                                  : null,
                              onTap: busy ? null : () => select(q, o),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: index > 0 ? () => setState(() => index--) : null,
                child: const Text('Câu trước'),
              ),
              Text((index + 1).toString() + '/' + questions.length.toString()),
              FilledButton(
                onPressed: index + 1 < questions.length
                    ? () => setState(() => index++)
                    : submit,
                child: Text(
                  index + 1 < questions.length ? 'Câu tiếp' : 'Nộp bài',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TakingQuestion {
  _TakingQuestion({
    required this.question,
    required this.partType,
    required this.passageText,
    required this.imageUrl,
    required this.instructionText,
  });
  StudentQuestion question;
  final int partType;
  final String passageText, imageUrl, instructionText;
}

class _QuestionLegend extends StatelessWidget {
  const _QuestionLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: _studentMuted)),
    ],
  );
}

class StudentResultScreen extends StatelessWidget {
  const StudentResultScreen({
    required this.result,
    required this.onHome,
    super.key,
  });
  final StudentAttempt result;
  final VoidCallback onHome;
  @override
  Widget build(BuildContext context) {
    final correct = result.totalCorrect ?? 0;
    final wrong = result.totalWrong ?? 0;
    final skipped = result.totalSkipped ?? 0;
    final score = result.score ?? correct;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Kết quả bài thi',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: onHome,
              icon: const Icon(Icons.home_outlined),
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  result.examTitle.isNotEmpty
                      ? result.examTitle
                      : 'TOEIC Reading',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Text(
                  '$score / 100',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: _studentBlue,
                  ),
                ),
                const Text('Điểm Reading dựa trên số câu trả lời đúng.'),
                const SizedBox(height: 12),
                Text('Đúng: $correct   Sai: $wrong   Bỏ: $skipped'),
                Text(
                  'Trạng thái: ${result.status.isNotEmpty ? result.status : 'Submitted'}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _StudentNotice(
          icon: Icons.check_circle_outline,
          title: 'Đã nộp bài',
          text: 'Bài làm và điểm đã được lưu trên hệ thống.',
        ),
        const SizedBox(height: 12),
        ...[
          const Text('Xem lại đáp án', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Chọn từng câu để xem đáp án của bạn và đáp án đúng.', style: TextStyle(color: _studentMuted, fontSize: 12)),
          const SizedBox(height: 8),
          for (final group in result.groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Text('Part ${group.partType}', style: const TextStyle(color: _studentBlue, fontWeight: FontWeight.w800)),
            ),
            for (final question in group.questions)
              Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  leading: CircleAvatar(
                    radius: 15,
                    backgroundColor: question.selectedOptionId == null
                        ? const Color(0xFFE6EBF2)
                        : question.options
                                  .where((o) => o.id == question.selectedOptionId)
                                  .firstOrNull
                                  ?.label ==
                              question.correctAnswer
                            ? const Color(0xFFEAF7F1)
                            : const Color(0xFFFFF0EF),
                    child: Icon(
                      question.selectedOptionId == null
                          ? Icons.remove
                          : question.options
                                    .where((o) => o.id == question.selectedOptionId)
                                    .firstOrNull
                                    ?.label ==
                                question.correctAnswer
                              ? Icons.check
                              : Icons.close,
                      size: 17,
                      color: question.selectedOptionId == null
                          ? _studentMuted
                          : question.options
                                    .where((o) => o.id == question.selectedOptionId)
                                    .firstOrNull
                                    ?.label ==
                                question.correctAnswer
                              ? _studentGreen
                              : const Color(0xFFB42318),
                    ),
                  ),
                  title: Text('Câu ${question.questionNumber}: ${question.questionText}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    [
                      question.selectedOptionId == null
                          ? 'B\u1ea1n b\u1ecf qua \u00b7 \u0110\u00e1p \u00e1n ${question.correctAnswer ?? "\u2014"}'
                          : 'B\u1ea1n ch\u1ecdn ${question.options.where((o) => o.id == question.selectedOptionId).firstOrNull?.label ?? "\u2014"} \u00b7 \u0110\u00e1p \u00e1n ${question.correctAnswer ?? "\u2014"}',
                      'Gi\u1ea3i th\u00edch: ${(question.hint ?? "").trim().isNotEmpty ? question.hint!.trim() : "Gi\u1ea3ng vi\u00ean ch\u01b0a nh\u1eadp gi\u1ea3i th\u00edch cho c\u00e2u n\u00e0y."}',
                    ].join('\n'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, height: 1.3),
                  ),
                  trailing: Text(
                    question.selectedOptionId == null
                        ? 'Bỏ trống'
                        : question.options
                                  .where((o) => o.id == question.selectedOptionId)
                                  .firstOrNull
                                  ?.label ==
                              question.correctAnswer
                            ? 'Đúng'
                            : 'Sai',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: question.selectedOptionId == null
                          ? _studentMuted
                          : question.options
                                    .where((o) => o.id == question.selectedOptionId)
                                    .firstOrNull
                                    ?.label ==
                                question.correctAnswer
                              ? _studentGreen
                              : const Color(0xFFB42318),
                    ),
                  ),
                  children: [
                    for (final option in question.options)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          option.label == question.correctAnswer
                              ? Icons.check_circle
                              : option.id == question.selectedOptionId
                                  ? Icons.cancel
                                  : Icons.circle_outlined,
                          color: option.label == question.correctAnswer
                              ? _studentGreen
                              : option.id == question.selectedOptionId
                                  ? const Color(0xFFB42318)
                                  : _studentMuted,
                        ),
                        title: Text('${option.label}. ${option.content}', style: const TextStyle(fontSize: 12)),
                        tileColor: option.label == question.correctAnswer
                            ? const Color(0xFFEAF7F1)
                            : option.id == question.selectedOptionId
                                ? const Color(0xFFFFF0EF)
                                : null,
                      ),
                    if ((question.hint ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Giải thích: ${question.hint}', style: const TextStyle(fontSize: 12, color: _studentMuted)),
                        ),
                      ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: onHome,
          icon: const Icon(Icons.home),
          label: const Text('Về danh sách đề'),
        ),
      ],
    );
  }
}

class StudentPracticeScreen extends StatelessWidget {
  const StudentPracticeScreen({
    required this.api,
    required this.onStart,
    super.key,
  });
  final StudentExamApi api;
  final ValueChanged<int> onStart;

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<StudentExamListItem>>(
    future: api.getPublishedExams(),
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Center(child: Text(snapshot.error.toString()));
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final exams = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Luyện tập TOEIC',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _studentInk,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Chọn một đề đã xuất bản để luyện tập không giới hạn số lần.',
            style: TextStyle(fontSize: 11, color: _studentMuted),
          ),
          const SizedBox(height: 15),
          if (exams.isEmpty)
            const _StudentNotice(
              icon: Icons.menu_book_outlined,
              title: 'Chưa có đề luyện tập',
              text: 'Các đề sẽ xuất hiện tại đây sau khi giảng viên xuất bản.',
            ),
          for (final exam in exams) ...[
            _StudentExamCard(
              title: exam.title.isNotEmpty ? exam.title : 'Đề TOEIC',
              description: exam.description.isNotEmpty
                  ? exam.description
                  : 'Luyện tập với đề TOEIC Reading.',
              type: 'TOEIC READING · PRACTICE',
              duration: '${exam.durationMinutes} phút',
              count: '${exam.totalQuestions} câu',
              buttonLabel: 'Bắt đầu luyện',
              onPressed: () => onStart(exam.id),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    },
  );
}

class StudentHistoryScreen extends StatelessWidget {
  const StudentHistoryScreen({
    required this.api,
    required this.onOpenResult,
    required this.onResume,
    super.key,
  });
  final StudentExamApi api;
  final ValueChanged<int> onOpenResult;
  final ValueChanged<int> onResume;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<StudentAttemptHistory>>(
        future: api.getMyAttempts(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text(snapshot.error.toString()));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final attempts = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Lịch sử làm bài',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _studentInk,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Các lượt thi và luyện tập của bạn.',
                style: TextStyle(fontSize: 11, color: _studentMuted),
              ),
              const SizedBox(height: 15),
              if (attempts.isEmpty)
                const _StudentNotice(
                  icon: Icons.history,
                  title: 'Chưa có lượt làm bài',
                  text: 'Lịch sử sẽ hiển thị sau khi bạn bắt đầu một đề.',
                ),
              for (final attempt in attempts) ...[
                _HistoryCard(
                  title: attempt.examTitle.isNotEmpty
                      ? attempt.examTitle
                      : 'Đề TOEIC',
                  date: _historyDate(attempt),
                  score: attempt.status == 'InProgress'
                      ? 'Tiếp tục'
                      : '${attempt.totalCorrect} đúng',
                  onTap: () => attempt.status == 'InProgress'
                      ? onResume(attempt.examId)
                      : onOpenResult(attempt.attemptId),
                  isInProgress: attempt.status == 'InProgress',
                ),
                const SizedBox(height: 9),
              ],
            ],
          );
        },
      );

  String _historyDate(StudentAttemptHistory attempt) {
    final start = attempt.startTime.toLocal();
    final type = attempt.isPractice ? 'Luyện tập' : 'Bài thi';
    final end = attempt.endTime?.toLocal();
    final duration = end == null
        ? ''
        : ' · ${end.difference(start).inMinutes} phút';
    return '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year} · $type$duration';
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.title,
    required this.date,
    required this.score,
    required this.onTap,
    this.isInProgress = false,
  });
  final String title, date, score;
  final VoidCallback? onTap;
  final bool isInProgress;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 39,
        height: 39,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF2FF),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.history_edu_outlined, color: _studentBlue),
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _studentInk,
        ),
      ),
      subtitle: Text(
        date,
        style: const TextStyle(fontSize: 10, color: _studentMuted),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _studentBlue,
            ),
          ),
          Text(
            isInProgress ? 'Ti\u1ebfp t\u1ee5c' : 'Xem l\u1ea1i',
            style: const TextStyle(fontSize: 9, color: _studentMuted),
          ),
        ],
      ),
    ),
  );
}

class StudentAccountScreen extends StatelessWidget {
  const StudentAccountScreen({
    required this.api,
    required this.onLogout,
    required this.onNotifications,
    super.key,
  });
  final StudentExamApi api;
  final VoidCallback onLogout;
  final VoidCallback onNotifications;

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = api.displayName ?? api.username ?? 'Sinh viên';
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Tài khoản',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _studentInk,
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: const Color(0xFFD8E2FF),
                  child: Text(
                    _initials(displayName),
                    style: const TextStyle(
                      fontSize: 20,
                      color: _studentBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _studentInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (api.username != null)
                        Text(
                          'Tài khoản: ${api.username}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _studentMuted,
                          ),
                        ),
                      const Text(
                        'Khoa CNTT & Ngoại ngữ',
                        style: TextStyle(fontSize: 10, color: _studentMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.verified_user_outlined, color: _studentGreen),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _StudentNotice(
          icon: Icons.flag_outlined,
          title: 'Mục tiêu TOEIC',
          text: '750+ điểm · B2 Working Proficiency',
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                onTap: onNotifications,
                leading: Icon(Icons.notifications_outlined),
                title: Text('Thông báo'),
                trailing: Icon(Icons.chevron_right_rounded),
              ),
              Divider(height: 1),
              ListTile(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Trợ giúp & quy chế thi'),
                    content: const SingleChildScrollView(
                      child: Text(
                        '• Bài thi có thời gian giới hạn; đồng hồ bắt đầu khi vào làm bài.\n'
                        '• Câu trả lời được lưu khi bạn chọn đáp án.\n'
                        '• Dùng bảng câu hỏi để chuyển nhanh và kiểm tra câu còn trống.\n'
                        '• Khi hết giờ, bài được nộp tự động. Sau khi nộp, mở từng câu để xem đáp án và giải thích.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Đã hiểu'),
                      ),
                    ],
                  ),
                ),
                leading: Icon(Icons.help_outline_rounded),
                title: Text('Trợ giúp & quy chế thi'),
                trailing: Icon(Icons.chevron_right_rounded),
              ),
              Divider(height: 1),
              ListTile(
                onTap: onLogout,
                leading: Icon(Icons.logout_rounded, color: Color(0xFFBA1A1A)),
                title: Text(
                  'Đăng xuất',
                  style: TextStyle(color: Color(0xFFBA1A1A)),
                ),
                trailing: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentNotice extends StatelessWidget {
  const _StudentNotice({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title, text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF2FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: _studentBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _studentInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.45,
                  color: _studentMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
