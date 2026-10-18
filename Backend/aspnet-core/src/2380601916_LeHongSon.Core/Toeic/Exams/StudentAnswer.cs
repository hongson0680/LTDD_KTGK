using Abp.Domain.Entities;
using Abp.Domain.Entities.Auditing;
using System;
using System.ComponentModel.DataAnnotations;

namespace LeHongSon.Toeic.Exams;

/// <summary>
/// Bảng StudentAnswer - Đáp án cụ thể mà sinh viên đã chọn cho từng câu hỏi
/// </summary>
public class StudentAnswer : FullAuditedEntity<long>, IMayHaveTenant
{
    public int? TenantId { get; set; }

    /// <summary>FK tới ExamAttempt - lượt làm bài nào</summary>
    public long ExamAttemptId { get; set; }
    public virtual ExamAttempt ExamAttempt { get; set; }

    /// <summary>FK tới Question - câu hỏi nào</summary>
    public long QuestionId { get; set; }
    public virtual Question Question { get; set; }

    /// <summary>FK tới đáp án đã chọn; null nếu sinh viên bỏ qua câu hỏi.</summary>
    public long? SelectedOptionId { get; set; }
    public virtual AnswerOption SelectedOption { get; set; }

    /// <summary>
    /// Có đúng hay không.
    /// Tính bằng cách so sánh đáp án đã chọn với Question.CorrectAnswer.
    /// Null nếu SelectedOptionId là null (bỏ qua).
    /// </summary>
    public bool? IsCorrect { get; set; }

    /// <summary>Thời điểm sinh viên chọn đáp án</summary>
    public DateTime AnsweredAt { get; set; }

    /// <summary>Thời gian sinh viên đã dành cho câu này (giây) - tùy chọn, dùng cho phân tích</summary>
    public int? TimeSpentSeconds { get; set; }
}
