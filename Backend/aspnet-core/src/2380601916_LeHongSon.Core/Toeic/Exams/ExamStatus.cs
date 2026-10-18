namespace LeHongSon.Toeic.Exams;

/// <summary>
/// Trạng thái của bài thi
/// </summary>
public enum ExamStatus
{
    /// <summary>Bản nháp - chưa xuất bản, sinh viên chưa thấy</summary>
    Draft = 0,

    /// <summary>Đã xuất bản - sinh viên có thể bắt đầu thi</summary>
    Published = 1,

    /// <summary>Đã đóng - không cho thi nữa</summary>
    Closed = 2
}
