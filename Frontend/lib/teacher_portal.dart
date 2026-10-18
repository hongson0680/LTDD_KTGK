import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'config/api_config.dart';
import 'services/teacher_api.dart';
import 'student_portal.dart';

const _ink = Color(0xFF161C22);
const _muted = Color(0xFF5B646B);
const _line = Color(0xFFE3E9F0);
const _blue = Color(0xFF0059BB);
const _teal = Color(0xFF006574);

class TeacherPortalShell extends StatefulWidget {
  const TeacherPortalShell({super.key});

  @override
  State<TeacherPortalShell> createState() => _TeacherPortalShellState();
}

class _TeacherPortalShellState extends State<TeacherPortalShell> {
  int _page = 0;
  bool _isStudent = false;
  final TeacherApi _api = TeacherApi();
  int? _selectedExamId;
  int _apiRevision = 0;

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static const _destinations = <_Destination>[
    _Destination('Quản lý đề thi', Icons.folder_open_outlined, Icons.folder),
    _Destination(
      'Import & kiểm duyệt .docx',
      Icons.upload_file_outlined,
      Icons.upload_file,
    ),
    _Destination('Xem & sửa đề thi', Icons.edit_note_outlined, Icons.edit_note),
    _Destination(
      'Thống kê & báo cáo',
      Icons.bar_chart_outlined,
      Icons.bar_chart,
    ),
  ];

  Widget _screen() => switch (_page) {
    0 => ExamListScreen(
      key: ValueKey(_apiRevision),
      api: _api,
      onNavigate: _go,
      onConnect: _connect,
      onEdit: (id) => _openExam(id, 2),
      onStats: (id) => _openExam(id, 3),
    ),
    1 => ImportScreen(
      key: ValueKey('import-$_apiRevision'),
      api: _api,
      onConnect: _connect,
      onImported: (id) => _openExam(id, 2),
    ),
    2 => ExamEditorScreen(
      key: ValueKey('editor-$_apiRevision-$_selectedExamId'),
      api: _api,
      examId: _selectedExamId,
      onConnect: _connect,
      onNavigate: _go,
    ),
    _ => AnalyticsScreen(
      key: ValueKey('analytics-$_apiRevision-$_selectedExamId'),
      api: _api,
      examId: _selectedExamId,
      onConnect: _connect,
    ),
  };
  void _go(int index) => setState(() => _page = index);

  void _openExam(int id, int page) => setState(() {
    _selectedExamId = id;
    _page = page;
  });

  Future<void> _connect() async {
    final connected = await showDialog<bool>(
      context: context,
      builder: (_) => _TeacherConnectionDialog(api: _api),
    );
    if (connected == true && mounted) setState(() => _apiRevision++);
  }

  @override
  Widget build(BuildContext context) {
    if (_isStudent) {
      return StudentPortalShell(
        onTeacherMode: () => setState(() => _isStudent = false),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 850;
        final current = _destinations[_page];
        return Scaffold(
          backgroundColor: const Color(0xFFF0F4FB),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            titleSpacing: desktop ? 24 : 16,
            title: Row(
              children: [
                const Text(
                  'Khảo thí',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.chevron_right, size: 18, color: _muted),
                ),
                Flexible(
                  child: Text(
                    current.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: _api.isConnected
                    ? 'Backend đã kết nối'
                    : 'Kết nối Backend',
                onPressed: _connect,
                icon: Icon(
                  _api.isConnected
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  color: _api.isConnected ? _teal : _muted,
                ),
              ),
              if (desktop)
                TextButton.icon(
                  onPressed: () => setState(() => _isStudent = true),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Sinh viên'),
                ),
              PopupMenuButton<String>(
                tooltip: _api.displayName ?? _api.username ?? 'Tài khoản',
                onSelected: (value) {
                  if (value == 'logout') {
                    _api.logout();
                    setState(() => _apiRevision++);
                  } else if (value == 'student') {
                    setState(() => _isStudent = true);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'account',
                    enabled: false,
                    child: Text(
                      _api.displayName ?? _api.username ?? 'Giảng viên',
                    ),
                  ),
                  if (_api.isConnected)
                    const PopupMenuItem(
                      value: 'logout',
                      child: Text('Đăng xuất'),
                    ),
                  if (!desktop)
                    const PopupMenuItem(
                      value: 'student',
                      child: Text('Giao diện sinh viên'),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFD8E2FF),
                        child: Text(
                          _initials(_api.displayName ?? _api.username),
                          style: const TextStyle(
                            color: _blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (constraints.maxWidth > 1050) ...[
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _api.displayName ?? _api.username ?? 'Giảng viên',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            const Text(
                              'Bộ môn Tiếng Anh',
                              style: TextStyle(fontSize: 9, color: _muted),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: _muted,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _line),
            ),
          ),
          body: Row(
            children: [
              if (desktop)
                Container(
                  width: 222,
                  color: const Color(0xFF29323C),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(15, 16, 12, 15),
                        child: Row(
                          children: [
                            Container(
                              width: 31,
                              height: 31,
                              decoration: BoxDecoration(
                                color: _blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 9),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TOEIC Portal',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'AdminLTE v3 + ASP.NET',
                                  style: TextStyle(
                                    color: Color(0xFFB8C3CE),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFF46515C)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 10, 13),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFD8E2FF),
                              child: Text(
                                _initials(_api.displayName ?? _api.username),
                                style: const TextStyle(
                                  color: _blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _api.displayName ??
                                        _api.username ??
                                        'Giảng viên',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Text(
                                    'Giảng viên ra đề & khảo thí',
                                    style: TextStyle(
                                      color: Color(0xFFB8C3CE),
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 8, 8, 8),
                        child: Text(
                          'PHÂN HỆ ĐỀ THI & KHẢO THÍ',
                          style: TextStyle(
                            color: Color(0xFFABB5BF),
                            fontSize: 9,
                            letterSpacing: .8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (var i = 0; i < _destinations.length; i++)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(7, 2, 7, 2),
                          child: _SidebarItem(
                            destination: _destinations[i],
                            selected: _page == i,
                            onTap: () => _go(i),
                          ),
                        ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(9),
                        child: _SidebarItem(
                          destination: _Destination(
                            _api.isConnected
                                ? 'Đăng xuất hệ thống'
                                : 'Kết nối Backend',
                            _api.isConnected ? Icons.logout : Icons.link,
                            _api.isConnected ? Icons.logout : Icons.link,
                          ),
                          selected: false,
                          onTap: () {
                            if (_api.isConnected) {
                              _api.logout();
                              setState(() => _apiRevision++);
                            } else {
                              _connect();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _screen()),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: _page,
                  onDestinationSelected: _go,
                  backgroundColor: Colors.white,
                  destinations: _destinations
                      .map(
                        (d) => NavigationDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: d.label,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? _blue : Colors.transparent,
    borderRadius: BorderRadius.circular(5),
    child: InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        child: Row(
          children: [
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: 17,
              color: selected ? Colors.white : const Color(0xFFD3D9DF),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFE0E5EA),
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _TeacherConnectionDialog extends StatefulWidget {
  const _TeacherConnectionDialog({required this.api});
  final TeacherApi api;
  @override
  State<_TeacherConnectionDialog> createState() =>
      _TeacherConnectionDialogState();
}

class _TeacherConnectionDialogState extends State<_TeacherConnectionDialog> {
  final _url = TextEditingController(text: defaultApiBaseUrl);
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.login(
        baseUrl: _url.text,
        username: _user.text,
        password: _password.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Kết nối Backend'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _url,
            decoration: const InputDecoration(labelText: 'Địa chỉ API'),
          ),
          TextField(
            controller: _user,
            decoration: const InputDecoration(labelText: 'Tài khoản'),
          ),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu'),
            onSubmitted: (_) => _login(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _busy ? null : _login,
        child: Text(_busy ? 'Đang kết nối…' : 'Đăng nhập'),
      ),
    ],
  );
}

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({
    required this.api,
    required this.onNavigate,
    required this.onConnect,
    required this.onEdit,
    required this.onStats,
    super.key,
  });
  final TeacherApi api;
  final ValueChanged<int> onNavigate;
  final VoidCallback onConnect;
  final ValueChanged<int> onEdit, onStats;

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  late Future<List<TeacherExam>> _examsFuture;
  String _query = '';
  int _page = 0;
  int _pageSize = 5;
  String _status = 'Tất cả trạng thái';

  @override
  void initState() {
    super.initState();
    _examsFuture = widget.api.getExams();
  }

  void _reload() {
    final examsFuture = widget.api.getExams();
    setState(() {
      _examsFuture = examsFuture;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.api.isConnected) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42, color: _blue),
                const SizedBox(height: 12),
                const Text(
                  'Kết nối Backend để quản lý đề thi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Danh sách và thống kê sẽ lấy trực tiếp từ cơ sở dữ liệu của dự án.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: widget.onConnect,
                  icon: const Icon(Icons.link),
                  label: const Text('Kết nối Backend'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return FutureBuilder<List<TeacherExam>>(
      future: _examsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(snapshot.error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử tải lại'),
                ),
              ],
            ),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!;
        final publishedCount = all.where((e) => e.isPublished).length;
        final draftCount = all.where((e) => !e.isPublished).length;
        final attemptCount = all.fold<int>(0, (sum, e) => sum + e.attemptCount);
        final filtered = all.where((e) {
          final matchesQuery = '${e.title} ${e.sourceFileName} ${e.id}'
              .toLowerCase()
              .contains(_query.toLowerCase());
          final status = e.status.toLowerCase();
          final matchesStatus =
              _status == 'Tất cả trạng thái' ||
              (_status == 'Bản nháp' && status == 'draft') ||
              (_status == 'Đang mở thi' && e.isPublished) ||
              (_status == 'Đã đóng' && status == 'closed');
          return matchesQuery && matchesStatus;
        }).toList();
        final pageCount = (filtered.length / _pageSize).ceil();
        if (pageCount == 0) {
          _page = 0;
        } else if (_page >= pageCount) {
          _page = pageCount - 1;
        }
        final visible = filtered.skip(_page * _pageSize).take(_pageSize).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: _ScreenHeading(
                    eyebrow: 'KHẢO THÍ',
                    title: 'Quản lý Đề thi TOEIC',
                    subtitle: 'Hệ thống khảo thí điện tử · Ngân hàng đề Reading đã nhập vào dự án',
                  ),
                ),
                IconButton(
                  tooltip: 'Tải lại dữ liệu',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  label: 'Tổng số đề thi',
                  value: all.length.toString(),
                  caption: 'Đang lưu trong hệ thống',
                  icon: Icons.menu_book_outlined,
                  tone: _blue,
                ),
                _MetricCard(
                  label: 'Đang mở thi',
                  value: publishedCount.toString(),
                  caption: 'Sinh viên có thể truy cập',
                  icon: Icons.publish_outlined,
                  tone: _teal,
                ),
                _MetricCard(
                  label: 'Chưa mở thi',
                  value: draftCount.toString(),
                  caption: 'Bản nháp hoặc đã đóng',
                  icon: Icons.edit_note_outlined,
                  tone: const Color(0xFF936000),
                ),
                _MetricCard(
                  label: 'Lượt dự thi',
                  value: attemptCount.toString(),
                  caption: 'Tổng lượt đã nộp của các đề',
                  icon: Icons.groups_2_outlined,
                  tone: const Color(0xFF6750A4),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () => widget.onNavigate(1),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Import đề thi (.docx)'),
                        ),
                        const SizedBox(width: 9),
                        OutlinedButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Làm mới'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            onChanged: (v) => setState(() {
                              _query = v;
                              _page = 0;
                            }),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Tìm mã đề, tên đề thi hoặc file Word',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.filter_list),
                              labelText: 'Trạng thái',
                            ),
                            items:
                                const [
                                      'Tất cả trạng thái',
                                      'Bản nháp',
                                      'Đang mở thi',
                                      'Đã đóng',
                                    ]
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setState(
                              () => _status = v ?? 'Tất cả trạng thái',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${filtered.length} / ${all.length} đề',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(36),
                      child: _EmptyState(
                        icon: Icons.search_off,
                        title: 'Không có đề phù hợp',
                        message: 'Thử đổi từ khóa hoặc trạng thái lọc.',
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 950),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFEFF3FA),
                          ),
                          columns: const [
                            DataColumn(label: Text('MÃ ĐỀ')),
                            DataColumn(label: Text('TÊN ĐỀ THI TOEIC')),
                            DataColumn(label: Text('THỜI LƯỢNG')),
                            DataColumn(label: Text('CÂU HỎI')),
                            DataColumn(label: Text('LƯỢT THI')),
                            DataColumn(label: Text('TRẠNG THÁI')),
                            DataColumn(label: Text('THAO TÁC')),
                          ],
                          rows: visible
                              .map(
                                (exam) => DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        'TOEIC-${exam.id}',
                                        style: const TextStyle(
                                          color: _blue,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 300,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              exam.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: _blue,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              exam.sourceFileName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: _muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text('${exam.durationMinutes} phút'),
                                    ),
                                    DataCell(Text('${exam.totalQuestions}')),
                                    DataCell(_Tag('${exam.attemptCount} lượt')),
                                    DataCell(_StatusPill(label: exam.status)),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: exam.isPublished
                                                ? 'Xem đề'
                                                : 'Xem và sửa',
                                            onPressed: () =>
                                                widget.onEdit(exam.id),
                                            icon: Icon(
                                              exam.isPublished
                                                  ? Icons.visibility_outlined
                                                  : Icons.edit_outlined,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Thống kê',
                                            onPressed: () =>
                                                widget.onStats(exam.id),
                                            icon: const Icon(
                                              Icons.bar_chart_outlined,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: exam.isPublished
                                                ? 'Đóng đề'
                                                : exam.status.toLowerCase() ==
                                                      'closed'
                                                ? 'Đề đã đóng'
                                                : 'Xuất bản',
                                            onPressed:
                                                exam.status.toLowerCase() ==
                                                    'closed'
                                                ? null
                                                : () async {
                                                    try {
                                                      if (exam.isPublished) {
                                                        await widget.api.close(
                                                          exam.id,
                                                        );
                                                      } else {
                                                        await widget.api
                                                            .publish(exam.id);
                                                      }
                                                      if (mounted) _reload();
                                                    } catch (e) {
                                                       if (context.mounted)
                                                        _showMessage(
                                                          context,
                                                          e.toString(),
                                                        );
                                                    }
                                                  },
                                            icon: Icon(
                                              exam.status.toLowerCase() ==
                                                      'closed'
                                                  ? Icons.lock_outline
                                                  : exam.isPublished
                                                  ? Icons.stop_circle_outlined
                                                  : Icons.publish,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
            ),
            if (filtered.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Hiển thị ${_page * _pageSize + 1}–${_page * _pageSize + visible.length} trong ${filtered.length} đề thi',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      const Spacer(),
                      const Text('Số dòng:', style: TextStyle(color: _muted, fontSize: 12)),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _pageSize,
                        items: const [5, 10, 20, 50]
                            .map(
                              (count) => DropdownMenuItem(
                                value: count,
                                child: Text('$count'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          _pageSize = value ?? 5;
                          _page = 0;
                        }),
                      ),
                      IconButton(
                        tooltip: 'Trang trước',
                        onPressed: _page > 0 ? () => setState(() => _page--) : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('${_page + 1} / $pageCount'),
                      IconButton(
                        tooltip: 'Trang sau',
                        onPressed: _page + 1 < pageCount ? () => setState(() => _page++) : null,
                        icon: const Icon(Icons.chevron_right),
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
}

class ExamEditorScreen extends StatefulWidget {
  const ExamEditorScreen({
    required this.api,
    required this.examId,
    required this.onConnect,
    required this.onNavigate,
    super.key,
  });
  final TeacherApi api;
  final int? examId;
  final VoidCallback onConnect;
  final ValueChanged<int> onNavigate;

  @override
  State<ExamEditorScreen> createState() => _ExamEditorScreenState();
}

class _ExamEditorScreenState extends State<ExamEditorScreen> {
  late Future<TeacherExamPreview> _loadFuture;
  TeacherExamPreview? _exam;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _duration = TextEditingController();
  final _instructionControllers = <int, TextEditingController>{};
  final _passageControllers = <int, TextEditingController>{};
  final _questionControllers = <int, TextEditingController>{};
  final _hintControllers = <int, TextEditingController>{};
  final _optionControllers = <String, TextEditingController>{};
  final _correctAnswers = <int, String>{};
  final _shuffleQuestions = <int, bool>{};
  final _shuffleAnswers = <int, bool>{};
  int? _selectedQuestion;
  bool _saving = false;
  String? _controllerExamKey;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<TeacherExamPreview> _load() async {
    if (!widget.api.isConnected) {
      throw const TeacherApiException('Hãy kết nối Backend để mở đề thi.');
    }
    if (widget.examId == null) {
      throw const TeacherApiException('Chưa chọn đề thi để xem và sửa.');
    }
    return widget.api.getPreview(widget.examId!);
  }

  void _refresh() {
    _clearControllers();
    setState(() {
      _controllerExamKey = null;
      _loadFuture = _load();
    });
  }

  void _clearControllers() {
    for (final controller in [
      ..._instructionControllers.values,
      ..._passageControllers.values,
      ..._questionControllers.values,
      ..._hintControllers.values,
      ..._optionControllers.values,
    ]) {
      controller.dispose();
    }
    _instructionControllers.clear();
    _passageControllers.clear();
    _questionControllers.clear();
    _hintControllers.clear();
    _optionControllers.clear();
    _correctAnswers.clear();
    _shuffleQuestions.clear();
    _shuffleAnswers.clear();
    _selectedQuestion = null;
  }

  void _initControllers(TeacherExamPreview exam) {
    final key = '${widget.examId}:${exam.title}:${exam.groups.length}';
    if (_controllerExamKey == key) return;
    _controllerExamKey = key;
    _title.text = exam.title;
    _description.text = exam.description;
    _duration.text = exam.durationMinutes.toString();
    for (final group in exam.groups) {
      _instructionControllers[group.id] = TextEditingController(
        text: group.instructionText,
      );
      _passageControllers[group.id] = TextEditingController(
        text: group.passageText,
      );
      for (final question in group.questions) {
        _questionControllers[question.id] = TextEditingController(
          text: question.questionText,
        );
        _hintControllers[question.id] = TextEditingController(
          text: question.hint,
        );
        _correctAnswers[question.id] = question.correctAnswer;
        _shuffleQuestions[question.id] = question.shuffleQuestion;
        _shuffleAnswers[question.id] = question.shuffleAnswers;
        for (final option in question.options) {
          _optionControllers['${question.id}:${option.label}'] =
              TextEditingController(text: option.content);
        }
      }
    }
    if (_selectedQuestion == null &&
        exam.groups.isNotEmpty &&
        exam.groups.first.questions.isNotEmpty) {
      _selectedQuestion = exam.groups.first.questions.first.id;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _duration.dispose();
    _clearControllers();
    super.dispose();
  }

  Future<void> _save() async {
    final exam = _exam;
    final examId = widget.examId;
    if (exam == null || examId == null || exam.isPublished || _saving) return;
    final duration = int.tryParse(_duration.text.trim());
    if (_title.text.trim().isEmpty ||
        duration == null ||
        duration < 1 ||
        duration > 300) {
      _showMessage(context, 'Nhập tiêu đề và thời lượng từ 1 đến 300 phút.');
      return;
    }
    setState(() => _saving = true);
    try {
      final groups = exam.groups
          .map(
            (group) => <String, Object?>{
              'id': group.id,
              'instructionText': _instructionControllers[group.id]!.text,
              'passageText': _passageControllers[group.id]!.text,
              'questions': group.questions
                  .map(
                    (question) => <String, Object?>{
                      'id': question.id,
                      'questionText': _questionControllers[question.id]!.text,
                      'correctAnswer': _correctAnswers[question.id],
                      'hint': _hintControllers[question.id]!.text,
                      'shuffleQuestion':
                          _shuffleQuestions[question.id] ?? false,
                      'shuffleAnswers': _shuffleAnswers[question.id] ?? false,
                      'answerOptions': question.options
                          .map(
                            (option) => <String, Object?>{
                              'id': option.id,
                              'content':
                                  _optionControllers['${question.id}:${option.label}']!
                                      .text,
                            },
                          )
                          .toList(),
                    },
                  )
                  .toList(),
            },
          )
          .toList();
      await widget.api.updateExam(
        id: examId,
        title: _title.text.trim(),
        description: _description.text.trim(),
        durationMinutes: duration,
        groups: groups,
      );
      if (!mounted) return;
      _showMessage(context, 'Đã lưu thay đổi vào cơ sở dữ liệu.');
      _controllerExamKey = null;
      _refresh();
    } catch (e) {
      if (mounted) _showMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TeacherExamPreview>(
    future: _loadFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        final needsConnection = !widget.api.isConnected;
        final needsExamSelection = widget.examId == null;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42, color: _muted),
                const SizedBox(height: 12),
                Text(
                  needsExamSelection
                      ? 'Chưa chọn đề thi. Hãy vào Quản lý đề thi và chọn đề bạn muốn sửa.'
                      : snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                if (needsConnection)
                  FilledButton.icon(
                    onPressed: widget.onConnect,
                    icon: const Icon(Icons.cloud_outlined),
                    label: const Text('Kết nối Backend'),
                  )
                else if (needsExamSelection)
                  FilledButton.icon(
                    onPressed: () => widget.onNavigate(0),
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('Đến danh sách đề thi'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final exam = snapshot.data!;
      _initControllers(exam);
      _exam = exam;
      final selectedGroup = exam.groups.firstWhere(
        (g) => g.questions.any((q) => q.id == _selectedQuestion),
        orElse: () => exam.groups.first,
      );
      final question = selectedGroup.questions.firstWhere(
        (q) => q.id == _selectedQuestion,
        orElse: () => selectedGroup.questions.first,
      );
      final canEdit = !exam.isPublished && exam.status.toLowerCase() == 'draft';
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final navigator = _buildQuestionNavigator(exam, compact);
          final editor = _buildQuestionEditor(
            exam,
            selectedGroup,
            question,
            canEdit,
            compact,
          );
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 28,
                  20,
                  compact ? 14 : 28,
                  14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exam.sourceFileName,
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            exam.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${exam.totalQuestions} câu · ${exam.durationMinutes} phút · ${exam.groupCount} nhóm · ${exam.status}',
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tải lại dữ liệu',
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                    if (canEdit) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Đang lưu' : 'Lưu thay đổi'),
                      ),
                    ],
                  ],
                ),
              ),
              if (!canEdit)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 4),
                  child: _InfoBanner(
                    icon: Icons.lock_outline,
                    text: 'Đề đã xuất bản hoặc đóng. Nội dung được khóa để bảo toàn kết quả thi.',
                  ),
                ),
              Expanded(
                child: compact
                    ? Column(
                        children: [
                          SizedBox(height: 145, child: navigator),
                          Expanded(child: editor),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 250, child: navigator),
                          const VerticalDivider(width: 1, color: _line),
                          Expanded(child: editor),
                        ],
                      ),
              ),
            ],
          );
        },
      );
    },
  );

  Widget _buildQuestionNavigator(
    TeacherExamPreview exam,
    bool compact,
  ) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(14),
    child: ListView(
      children: [
        const Text(
          'DANH SÁCH CÂU',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w800,
            color: _muted,
          ),
        ),
        const SizedBox(height: 10),
        for (final group in exam.groups) ...[
          Text(
            'Part ${group.partType} · ${group.questions.length} câu',
            style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final question in group.questions)
                SizedBox(
                  width: compact ? 38 : 40,
                  height: 34,
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _selectedQuestion = question.id),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: _selectedQuestion == question.id
                          ? _blue
                          : null,
                      foregroundColor: _selectedQuestion == question.id
                          ? Colors.white
                          : _ink,
                      side: BorderSide(
                        color: _selectedQuestion == question.id ? _blue : _line,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      '${question.questionNumber}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
        ],
      ],
    ),
  );

  Widget _buildQuestionEditor(
    TeacherExamPreview exam,
    TeacherQuestionGroup group,
    TeacherQuestion question,
    bool canEdit,
    bool compact,
  ) => ListView(
    padding: EdgeInsets.fromLTRB(compact ? 14 : 28, 18, compact ? 14 : 28, 30),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Part ${group.partType} · Câu ${question.questionNumber}',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          _StatusPill(label: canEdit ? 'Bản nháp' : exam.status),
        ],
      ),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thông tin đề',
                style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                enabled: canEdit,
                decoration: const InputDecoration(labelText: 'Tên đề thi'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                enabled: canEdit,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _duration,
                  enabled: canEdit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Thời lượng (phút)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      if (group.partType != 5)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hướng dẫn · Passage ${group.order}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _instructionControllers[group.id],
                  enabled: canEdit,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Hướng dẫn nhóm',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passageControllers[group.id],
                  enabled: canEdit,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung bài đọc',
                  ),
                ),
                if (group.imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final path
                          in group.imageUrl
                              .split('|')
                              .where((p) => p.isNotEmpty))
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 360,
                            maxHeight: 220,
                          ),
                          child: Image.network(
                            path.startsWith('http')
                                ? path
                                : '${widget.api.baseUrl}$path',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const Text('Không tải được ảnh passage.'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nội dung câu hỏi',
                style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _questionControllers[question.id],
                enabled: canEdit,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Câu hỏi'),
              ),
              const SizedBox(height: 14),
              const Text(
                'Các phương án · chọn đáp án đúng',
                style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _correctAnswers[question.id],
                onChanged: (value) {
                  if (canEdit && value != null) {
                    setState(() => _correctAnswers[question.id] = value);
                  }
                },
                child: Column(
                  children: [
                    for (final option in question.options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: option.label,
                              enabled: canEdit,
                            ),
                            SizedBox(
                              width: 32,
                              child: Text(
                                option.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _optionControllers[
                                  '${question.id}:${option.label}'
                                ],
                                enabled: canEdit,
                                decoration: InputDecoration(
                                  labelText: 'Phương án ${option.label}',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _hintControllers[question.id],
                enabled: canEdit,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Giải thích đáp án',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _SwitchLabel(
                    title: 'Trộn câu hỏi',
                    value: group.partType == 5,
                    onChanged: null,
                  ),
                  _SwitchLabel(
                    title: 'Trộn đáp án',
                    value: _shuffleAnswers[question.id] ?? false,
                    onChanged: canEdit
                        ? (value) => setState(
                            () => _shuffleAnswers[question.id] = value,
                          )
                        : null,
                  ),
                ],
              ),
              if (!canEdit)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Đáp án đúng: ${question.correctAnswer}',
                    style: const TextStyle(
                      color: _teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Câu ${question.questionNumber} / ${exam.totalQuestions}',
            style: const TextStyle(color: _muted),
          ),
          if (canEdit)
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Lưu đề'),
            ),
        ],
      ),
    ],
  );
}

class _SwitchLabel extends StatelessWidget {
  const _SwitchLabel({
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Switch.adaptive(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      Text(title, style: const TextStyle(fontSize: 12, color: _muted)),
    ],
  );
}

class ImportScreen extends StatefulWidget {
  const ImportScreen({
    required this.api,
    required this.onConnect,
    required this.onImported,
    super.key,
  });
  final TeacherApi api;
  final VoidCallback onConnect;
  final ValueChanged<int> onImported;
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  PlatformFile? _file;
  List<int>? _fileBytes;
  TeacherExamPreview? _preview;
  String? _error;
  bool _busy = false;

  int _partQuestionCount(int part) {
    final groups = _preview?.groups;
    if (groups == null) return 0;
    return groups
        .where((group) => group.partType == part)
        .fold<int>(0, (total, group) => total + group.questions.length);
  }

  int get _passageCount =>
      _preview?.groups.where((group) => group.partType != 5).length ?? 0;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['docx'],
    );
    if (result.isNotEmpty) {
      final picked = result.first;
      try {
        final bytes = await picked.readAsBytes();
        if (mounted)
          setState(() {
            _file = picked;
            _fileBytes = bytes;
            _preview = null;
            _error = null;
          });
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _validateFile() async {
    if (!widget.api.isConnected) {
      widget.onConnect();
      return;
    }
    if (_fileBytes == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _preview = await widget.api.previewFile(
        name: _file!.name,
        bytes: _fileBytes!,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_preview == null || _fileBytes == null) return;
    setState(() => _busy = true);
    try {
      final result = await widget.api.importDraft(
        name: _file!.name,
        bytes: _fileBytes!,
      );
      if (mounted) widget.onImported(result.examId);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
    children: [
      const _ScreenHeading(
        eyebrow: 'DOCX Â· TOEIC READING',
        title: 'Import & kiểm duyệt đề thi từ File Word (.docx)',
        subtitle: 'Đọc tags, kiểm tra cấu trúc và xem trước dữ liệu trước khi tạo bản nháp.',
      ),
      const SizedBox(height: 14),
      const _InfoBanner(
        icon: Icons.gpp_good_outlined,
        text: 'Kiểm tra toàn bộ tài liệu trước khi ghi dữ liệu. Nếu parser phát hiện lỗi, giao dịch import không được thực hiện.',
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          final panels = [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      number: '01',
                      title: 'Thông tin đề thi từ tài liệu',
                    ),
                    const SizedBox(height: 16),
                    if (_preview == null) ...[
                      const Text(
                        'Parser sẽ đọc tên đề, thời lượng và cấu trúc trực tiếp từ tags trong file Word.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _ImportDataRow(
                        label: 'Tên đề',
                        value: 'Chưa kiểm tra file',
                      ),
                      const _ImportDataRow(label: 'Thời lượng', value: '—'),
                      const _ImportDataRow(label: 'Số câu', value: '—'),
                    ] else ...[
                      _ImportDataRow(label: 'Tên đề', value: _preview!.title),
                      _ImportDataRow(
                        label: 'Thời lượng',
                        value: '${_preview!.durationMinutes} phút',
                      ),
                      _ImportDataRow(
                        label: 'Tổng số câu',
                        value: '${_preview!.totalQuestions} câu',
                      ),
                      _ImportDataRow(
                        label: 'Số nhóm đọc',
                        value: '$_passageCount nhóm',
                      ),
                      const Divider(height: 22),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _Tag('Part 5 Â· ${_partQuestionCount(5)}'),
                          _Tag('Part 6 Â· ${_partQuestionCount(6)}'),
                          _Tag('Part 7 Â· ${_partQuestionCount(7)}'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      number: '02',
                      title: 'Tải lên tệp đề thi Word (.docx)',
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _busy ? null : _pickFile,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 28,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7FC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFB7C8E2)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _file == null
                                  ? Icons.upload_file_rounded
                                  : Icons.description_rounded,
                              size: 39,
                              color: _blue,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _file?.name ??
                                  'Kéo tệp .docx vào đây hoặc chọn file',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _file == null
                                  ? 'Tối đa 20 MB · Microsoft Word'
                                  : '${(_fileBytes!.length / (1024 * 1024)).toStringAsFixed(2)} MB',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _pickFile,
                              icon: const Icon(Icons.folder_open),
                              label: Text(
                                _file == null ? 'Chọn file' : 'Thay file',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _file != null && !_busy
                            ? _validateFile
                            : null,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.fact_check_outlined),
                        label: Text(
                          _busy ? 'Đang kiểm tra...' : 'Kiểm tra & xem trước',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
          if (constraints.maxWidth < 900)
            return Column(children: [panels[0], panels[1]]);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: panels[0]),
              const SizedBox(width: 14),
              Expanded(flex: 6, child: panels[1]),
            ],
          );
        },
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFFFFF0EF),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Color(0xFFB42318)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tài liệu chưa hợp lệ · Không ghi vào CSDL',
                        style: TextStyle(
                          color: Color(0xFFB42318),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFF8F1D18),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Sửa file Word theo thông báo, chọn lại file và chạy kiểm tra lần nữa.',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
      if (_preview != null) ...[
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFFEAF7F1),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_outlined, color: Color(0xFF16845B)),
                    SizedBox(width: 8),
                    Text(
                      'Kiểm tra hợp lệ · 100 câu',
                      style: TextStyle(
                        color: Color(0xFF126849),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_preview!.title} · ${_preview!.durationMinutes} phút · ${_preview!.groupCount} nhóm bài đọc',
                  style: const TextStyle(color: _ink, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: _teal),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'Đề đang ở chế độ xem trước. Chỉ nút dưới đây mới tạo bản nháp trong CSDL.',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _saveDraft,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Lưu bản nháp'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      Card(
        child: ExpansionTile(
          leading: const Icon(Icons.sell_outlined, color: _blue),
          title: const Text(
            'Quy ước tags được parser hỗ trợ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: const [
            _TagGuide(
              '[EXAM_TITLE: ...]  [DURATION: 75]  [TOTAL_QUESTIONS: 100]',
            ),
            _TagGuide('[PART: 5] / [PART: 6] / [PART: 7]'),
            _TagGuide('[PASSAGE_START] ... [PASSAGE_END]'),
            _TagGuide('[Q: 101] ... [A] ... [B] ... [C] ... [D]'),
            _TagGuide(
              '[KEY: B]  [HINT: ...]  [SHUFFLE_Q: TRUE]  [SHUFFLE_A: TRUE]  [END_Q]',
            ),
          ],
        ),
      ),
    ],
  );
}

class _ImportDataRow extends StatelessWidget {
  const _ImportDataRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: _ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    required this.api,
    required this.examId,
    required this.onConnect,
    super.key,
  });
  final TeacherApi api;
  final int? examId;
  final VoidCallback onConnect;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<List<TeacherExam>> _examsFuture;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.examId;
    _examsFuture = widget.api.getExams();
  }

  void _reload() {
    final examsFuture = widget.api.getExams();
    setState(() {
      _examsFuture = examsFuture;
    });
  }

  Future<void> _exportCsv(
    TeacherExam exam,
    TeacherExamStatistics stats,
  ) async {
    String cell(String value) => '"${value.replaceAll('"', '""')}"';
    final rows = <List<String>>[
      ['Chỉ số', 'Giá trị'],
      ['Đề thi', exam.title],
      ['Tổng lượt nộp', '${stats.attemptCount}'],
      ['Điểm trung bình / 100', stats.averageScore.toStringAsFixed(2)],
      ['Nộp đúng giờ', '${stats.onTimeAttemptCount}/${stats.attemptCount}'],
      ['Tỷ lệ nộp đúng giờ', '${stats.onTimeRate.toStringAsFixed(2)}%'],
      ...stats.partAccuracies.map((part) => [
        'Part ${part.partType} (${part.questionCount} lượt trả lời)',
        '${part.correctCount} đúng · ${part.accuracyPercent.toStringAsFixed(2)}%',
      ]),
      ['Top câu sai nhiều', 'Số lượt sai · Tỷ lệ sai'],
      ...stats.mostIncorrectQuestions.map((question) => [
        'Câu ${question.questionNumber} · Part ${question.partType}',
        '${question.incorrectCount} · ${(question.incorrectRate * 100).toStringAsFixed(2)}%',
      ]),
    ];
    final csv = rows.map((row) => row.map(cell).join(',')).join('\r\n');
    try {
      final saved = await FilePicker.saveFile(
        fileName: 'toeic-analysis-${exam.id}.csv',
        bytes: Uint8List.fromList(utf8.encode('\uFEFF$csv')),
        mimeType: 'text/csv',
        dialogTitle: 'Xuất phân tích đề thi',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (!mounted || saved == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xuất báo cáo CSV, có thể mở bằng Excel.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xuất báo cáo: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.api.isConnected)
      return Center(
        child: FilledButton.icon(
          onPressed: widget.onConnect,
          icon: const Icon(Icons.link),
          label: const Text('Kết nối Backend'),
        ),
      );
    return FutureBuilder<List<TeacherExam>>(
      future: _examsFuture,
      builder: (context, examSnapshot) {
        if (examSnapshot.hasError)
          return Center(child: Text(examSnapshot.error.toString()));
        if (!examSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final exams = examSnapshot.data!;
        if (exams.isEmpty)
          return const Center(child: Text('Chưa có đề thi để phân tích.'));
        final selected =
            exams.where((e) => e.id == _selectedId).firstOrNull ??
            exams.firstWhere(
              (e) => e.id == widget.examId,
              orElse: () => exams.first,
            );
        _selectedId = selected.id;
        return FutureBuilder<TeacherExamStatistics>(
          key: ValueKey(selected.id),
          future: widget.api.getStatistics(selected.id),
          builder: (context, statsSnapshot) {
            if (statsSnapshot.hasError)
              return Center(child: Text(statsSnapshot.error.toString()));
            if (!statsSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final stats = statsSnapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: _ScreenHeading(
                        eyebrow: 'ITEM ANALYSIS',
                        title: 'Thống kê & Phân tích kết quả thi TOEIC',
                        subtitle: 'Thống kê lượt làm bài, điểm trung bình và những câu hỏi sinh viên thường trả lời sai.',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Làm mới',
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.assignment_outlined, color: _blue),
                        const SizedBox(width: 10),
                        const Text(
                          'CHỌN ĐỀ THI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selected.id,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            items: exams
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.id,
                                    child: Text(
                                      e.title,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (id) => setState(() => _selectedId = id),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _exportCsv(selected, stats),
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('Xuất Excel (.csv)'),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      label: 'Lượt làm bài',
                      value: '${stats.attemptCount}',
                      caption: 'Bài thi chính thức đã nộp',
                      icon: Icons.groups_2_outlined,
                      tone: _blue,
                    ),
                    _MetricCard(
                      label: 'Điểm trung bình',
                      value: stats.averageScore.toStringAsFixed(1),
                      caption: 'Trên 100 câu',
                      icon: Icons.insights_outlined,
                      tone: _teal,
                    ),
                    _MetricCard(
                      label: 'Hoàn thành đúng giờ',
                      value: '${stats.onTimeRate.toStringAsFixed(0)}%',
                      caption: '${stats.onTimeAttemptCount}/${stats.attemptCount} bài nộp đúng giờ',
                      icon: Icons.timer_outlined,
                      tone: const Color(0xFF18252B),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tỷ lệ làm đúng theo Part', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                        const SizedBox(height: 5),
                        const Text('Tính trên tổng số câu trong các bài thi đã nộp.', style: TextStyle(color: _muted, fontSize: 11)),
                        const SizedBox(height: 14),
                        if (stats.partAccuracies.isEmpty)
                          const Text('Chưa có dữ liệu theo Part.', style: TextStyle(color: _muted)),
                        for (final part in stats.partAccuracies) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text('Part ${part.partType} (${part.questionCount} lượt trả lời)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                                    Text('${part.accuracyPercent.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: part.accuracyPercent < 60 ? const Color(0xFFB42318) : _blue)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: (part.accuracyPercent / 100).clamp(0.0, 1.0).toDouble(),
                                    minHeight: 10,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    color: part.accuracyPercent < 60 ? const Color(0xFFB42318) : _teal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('${part.correctCount}/${part.questionCount} lượt trả lời đúng', style: const TextStyle(fontSize: 10, color: _muted)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (stats.mostIncorrectQuestions.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tỷ lệ làm sai cao nhất',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Tỷ lệ được tính trên số lượt làm bài chính thức của đề này.',
                            style: TextStyle(color: _muted, fontSize: 11),
                          ),
                          const SizedBox(height: 15),
                          for (final q in stats.mostIncorrectQuestions.take(5))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 13),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 118,
                                    child: Text(
                                      'Câu ${q.questionNumber} · P${q.partType}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: q.incorrectRate
                                            .clamp(0.0, 1.0)
                                            .toDouble(),
                                        minHeight: 14,
                                        backgroundColor: const Color(
                                          0xFFE2E8F0,
                                        ),
                                        color: q.incorrectRate >= .7
                                            ? const Color(0xFFB42318)
                                            : _blue,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      '${(q.incorrectRate * 100).toStringAsFixed(1)}%',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
                        child: Text(
                          'Top 10 câu hỏi sinh viên làm sai nhiều nhất',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ),
                      if (stats.mostIncorrectQuestions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Chưa có dữ liệu bài thi đã nộp để phân tích.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted),
                          ),
                        ),
                      for (
                        var i = 0;
                        i < stats.mostIncorrectQuestions.length;
                        i++
                      ) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: i < 3
                                ? const Color(0xFFFFE4E1)
                                : const Color(0xFFE8EDF5),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: i < 3 ? const Color(0xFFB42318) : _muted,
                              ),
                            ),
                          ),
                          title: Text(
                            'Câu ${stats.mostIncorrectQuestions[i].questionNumber} · Part ${stats.mostIncorrectQuestions[i].partType}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${stats.mostIncorrectQuestions[i].incorrectCount} lượt sai',
                          ),
                          trailing: SizedBox(
                            width: 170,
                            child: Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: stats
                                        .mostIncorrectQuestions[i]
                                        .incorrectRate
                                        .clamp(0.0, 1.0)
                                        .toDouble(),
                                    minHeight: 7,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Text(
                                  '${(stats.mostIncorrectQuestions[i].incorrectRate * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ScreenHeading extends StatelessWidget {
  const _ScreenHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  final String eyebrow, title, subtitle;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final titleBlock = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 1.35,
              color: _blue,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, height: 1.4, color: _muted),
          ),
        ],
      );
      return titleBlock;
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.tone,
  });
  final String label, value, caption;
  final IconData icon;
  final Color tone;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 205,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(icon, size: 19, color: tone),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 25,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: _muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title});
  final String number, title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF2FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          number,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: _blue,
          ),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final status = label.trim().toLowerCase();
    final closed = status == 'closed';
    final draft = status == 'draft';
    final text = closed
        ? 'Đã đóng'
        : draft
        ? 'Bản nháp'
        : 'Đang mở thi';
    final bg = closed
        ? const Color(0xFFE8EDF3)
        : draft
        ? const Color(0xFFFFF3D6)
        : const Color(0xFFE4F4EE);
    final fg = closed
        ? const Color(0xFF59636E)
        : draft
        ? const Color(0xFF805600)
        : const Color(0xFF126849);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;
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
        Icon(icon, size: 18, color: _blue),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
              color: Color(0xFF263A54),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF2FF),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: _blue,
      ),
    ),
  );
}

class _TagGuide extends StatelessWidget {
  const _TagGuide(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: SelectableText(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: _muted,
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Column(
      children: [
        Icon(icon, size: 32, color: _muted),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(message, style: const TextStyle(fontSize: 11, color: _muted)),
      ],
    ),
  );
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
