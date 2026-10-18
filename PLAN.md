# Kế hoạch sửa các vấn đề còn lại

## Context
Đã sửa xong Vấn đề #1 (lỗi compile `part.Value`). Vấn đề #2 không phải bug (URL convention khớp). Các vấn đề còn lại: #3 (Student API Map<String,dynamic>), #4 (CORS), #5 (HTTPS Android), #6 (FutureBuilder), #7 (dead mock code), #8 (file Dart quá dài).

---

## Vấn đề #3 — Student API dùng `Map<String, dynamic>` lỏng lẻo

### Mô tả
`student_exam_api.dart` trả về `Map<String, dynamic>` hoặc `List<Map<String, dynamic>>` thay vì typed models. Code `student_portal.dart` phải cast thủ công (`e['id']`, `e['title']`, v.v.) — dễ sai key, không type-check, không có IDE autocomplete.

Teacher API đã có pattern tốt (typed models như `TeacherExam`, `TeacherExamPreview`). Student API nên thống nhất theo.

### Cách sửa
1. **Tạo file mới** `Frontend/lib/services/student_exam_models.dart` chứa tất cả typed models:
   - `StudentExamListItem`
   - `StudentAttempt` (dùng trong exam flow)
   - `StudentAttemptHistory` (dùng trong history)
   - `StudentQuestionGroup`
   - `StudentQuestion`
   - `StudentAnswerOption`

2. **Cập nhật** `student_exam_api.dart`: đổi kiểu trả về từ `Map/List<Map>` → typed models.

3. **Cập nhật** `student_portal.dart`: thay `Map<String, dynamic>` bằng typed models.

### Tệp bị ảnh hưởng
- `Frontend/lib/services/student_exam_models.dart` (tạo mới)
- `Frontend/lib/services/student_exam_api.dart` (sửa kiểu trả về)
- `Frontend/lib/student_portal.dart` (dùng typed models)

### Xác minh
```bash
cd Frontend && flutter analyze lib/services/student_exam_models.dart lib/services/student_exam_api.dart lib/student_portal.dart
```
Kỳ vọng: 0 lỗi type.

---

## Vấn đề #4 — CORS không bao gồm Flutter Web/Windows

### Mô tả
```json
"CorsOrigins": "http://localhost:4200,http://localhost:8080,http://localhost:8081,http://localhost:3000"
```
Flutter Web/Desktop dùng port ngẫu nhiên (không cố định). Android emulator gọi `https://10.0.2.2:44311` (không phải localhost). Cần mở rộng CORS.

### Cách sửa
```json
"CorsOrigins": "http://localhost:4200,http://localhost:8080,http://localhost:8081,http://localhost:3000,http://localhost:*"
```

### Tệp bị ảnh hưởng
- `Backend/aspnet-core/src/2380601916_LeHongSon.Web.Host/appsettings.json`

### Xác minh
Build lại Web.Host, kiểm tra không có lỗi config.

---

## Vấn đề #5 — HTTPS self-signed cho Android

### Mô tả
Backend dùng HTTPS self-signed. Flutter Android cần cấu hình `network_security_config.xml` để cho phép cert tự ký cho `localhost` và `10.0.2.2`.

### Cách sửa
1. Kiểm tra xem `android/app/src/main/res/xml/` đã có `network_security_config.xml` chưa.
2. Nếu chưa có → tạo file:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <network-security-config>
     <domain-config cleartextTrafficPermitted="true">
       <domain includeSubdomains="true">10.0.2.2</domain>
     </domain-config>
     <base-config cleartextTrafficPermitted="false">
       <trust-anchors>
         <certificates src="system" />
       </trust-anchors>
     </base-config>
   </network-security-config>
   ```
3. Cập nhật `AndroidManifest.xml` thêm `android:networkSecurityConfig="@xml/network_security_config"`.

### Tệp bị ảnh hưởng
- `Frontend/android/app/src/main/res/xml/network_security_config.xml` (tạo mới nếu chưa có)
- `Frontend/android/app/src/main/AndroidManifest.xml` (thêm attribute)

### Xác minh
Build Android APK: `flutter build apk --debug`.

---

## Vấn đề #6 — `FutureBuilder` tạo Future mới mỗi lần build

### Mô tả
Trong `teacher_portal.dart`, `FutureBuilder` dùng `future: widget.api.getExams()` — tạo Future mới mỗi khi `build()` chạy, gây request API lặp.

### Cách sửa
Dùng `late final` hoặc `initState` để tạo Future một lần:

```dart
class _ExamListScreenState extends State<ExamListScreen> {
  late final Future<List<TeacherExam>> _examsFuture;

  @override
  void initState() {
    super.initState();
    _examsFuture = widget.api.getExams();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TeacherExam>>(
      future: _examsFuture,
      // ...
    );
  }
}
```

Cần áp dụng pattern này cho **3 FutureBuilder** trong `teacher_portal.dart`:
- Dòng 432: `ExamListScreen.getExams()`
- Dòng 854: `ExamEditorScreen.getPreview()`
- Dòng 1601: `AnalyticsScreen.getStatistics()`

### Tệp bị ảnh hưởng
- `Frontend/lib/teacher_portal.dart` (sửa 3 screen)

### Xác minh
`flutter analyze lib/teacher_portal.dart` — 0 lỗi.

---

## Vấn đề #7 — Mock `_ExamSummary` không dùng

### Mô tả
`_ExamSummary` và danh sách mock ở dòng 394-427 trong `teacher_portal.dart` không bao giờ được render vì `if (widget.api.isConnected)` luôn hiển thị data từ server.

### Cách sửa
Xóa class `_ExamSummary` (dòng ~393) và danh sách mock (dòng ~394-427).

### Tệp bị ảnh hưởng
- `Frontend/lib/teacher_portal.dart`

### Xác minh
`flutter analyze lib/teacher_portal.dart` — 0 lỗi.

---

## Vấn đề #8 — File Dart quá dài

### Mô tả
- `teacher_portal.dart`: 2165 dòng
- `student_portal.dart`: 1908 dòng

Quá lớn để maintain, nên tách thành nhiều file theo widget/screen.

### Cách sửa
Tách theo cấu trúc thư mục:
```
lib/
  screens/
    teacher/
      exam_list_screen.dart
      exam_editor_screen.dart
      import_screen.dart
      analytics_screen.dart
      widgets/
        exam_card.dart
        stat_card.dart
    student/
      exam_screen.dart
      history_screen.dart
      widgets/
  shell/
    teacher_shell.dart
    student_shell.dart
  models/
    teacher_models.dart
    student_models.dart
```

**Lưu ý**: Đây là refactor lớn, có thể mất thời gian. Cần user xác nhận mức độ ưu tiên. Tạm thời có thể skip nếu cần ưu tiên các vấn đề khác.

---

## Thứ tự thực hiện đề xuất

1. **#3** — Student API typed models (tác động lớn, sạch sẽ hơn)
2. **#4** — CORS (nhanh, 1 dòng)
3. **#6** — FutureBuilder (cải thiện performance)
4. **#7** — Xóa dead mock (nhanh, dọn code)
5. **#5** — HTTPS Android (tùy platform)
6. **#8** — Tách file (refactor lớn, cần user quyết định)
