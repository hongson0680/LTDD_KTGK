using Abp.Domain.Entities;
using Abp.Domain.Entities.Auditing;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using LeHongSon.Authorization.Users;

namespace LeHongSon.Toeic.Exams;

/// <summary>
/// Bảng ExamAttempt - Mỗi lượt sinh viên làm bài
/// </summary>
public class ExamAttempt : FullAuditedEntity<long>, IMayHaveTenant
{
    public const int MaxNotesLength = 1000;

    public int? TenantId { get; set; }

    /// <summary>FK tới Exam - sinh viên đang làm đề nào</summary>
    public long ExamId { get; set; }
    public virtual Exam Exam { get; set; }

    /// <summary>FK tới User (sinh viên) - dùng UserId có sẵn của ABP</summary>
    public long UserId { get; set; }
    public virtual User User { get; set; }

    /// <summary>Thời điểm bắt đầu làm bài</summary>
    public DateTime StartTime { get; set; }

    /// <summary>Thời điểm nộp bài (null nếu đang làm)</summary>
    public DateTime? EndTime { get; set; }

    /// <summary>Thời điểm hết hạn (StartTime + Exam.DurationMinutes)</summary>
    public DateTime ExpireTime { get; set; }

    /// <summary>Số câu trả lời đúng</summary>
    public int TotalCorrect { get; set; }

    /// <summary>Số câu trả lời sai</summary>
    public int TotalWrong { get; set; }

    /// <summary>Số câu bỏ qua (không chọn đáp án)</summary>
    public int TotalSkipped { get; set; }

    /// <summary>Điểm số (tính theo thang TOEIC: ~5 điểm/câu đúng cho Reading)</summary>
    public int Score { get; set; }

    /// <summary>Trạng thái lượt làm bài</summary>
    public AttemptStatus Status { get; set; } = AttemptStatus.InProgress;

    /// <summary>Điểm danh: sinh viên có thể làm bài nhiều lần không? (mặc định 1 lần)</summary>
    public bool IsPractice { get; set; } = false;

    /// <summary>Ghi chú của giảng viên (nếu có)</summary>
    [StringLength(MaxNotesLength)]
    public string Notes { get; set; }

    /// <summary>Navigation property - danh sách đáp án sinh viên đã chọn</summary>
    public virtual ICollection<StudentAnswer> StudentAnswers { get; set; }

    public ExamAttempt()
    {
        StudentAnswers = new List<StudentAnswer>();
    }
}
