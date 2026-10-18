namespace LeHongSon.Toeic.Exams;

/// <summary>
/// Trạng thái lượt làm bài của sinh viên
/// </summary>
public enum AttemptStatus
{
    /// <summary>Đang làm bài</summary>
    InProgress = 0,

    /// <summary>Đã nộp bài (do sinh viên)</summary>
    Submitted = 1,

    /// <summary>Đã nộp bài (do hết giờ - tự động)</summary>
    AutoSubmitted = 2,

    /// <summary>Đã hủy</summary>
    Cancelled = 3
}
