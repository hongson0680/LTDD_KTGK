using Abp.Auditing;
using Abp.Domain.Entities;
using Abp.Domain.Entities.Auditing;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using LeHongSon.Authorization.Users;

namespace LeHongSon.Toeic.Exams;

/// <summary>
/// Bảng Exam (Đề thi) - Lưu trữ thông tin đề thi TOEIC Reading
/// Mapping với các tag: [EXAM_TITLE], [DURATION], [TOTAL_QUESTIONS]
/// </summary>
public class Exam : FullAuditedEntity<long>, IMayHaveTenant
{
    public const int MaxTitleLength = 500;
    public const int MaxDescriptionLength = 2000;

    public int? TenantId { get; set; }

    /// <summary>Tên đề thi (từ [EXAM_TITLE])</summary>
    [Required]
    [StringLength(MaxTitleLength)]
    public string Title { get; set; }

    /// <summary>Mô tả đề thi</summary>
    [StringLength(MaxDescriptionLength)]
    public string Description { get; set; }

    /// <summary>Thời gian làm bài (phút) - từ [DURATION]</summary>
    public int DurationMinutes { get; set; }

    /// <summary>Tổng số câu hỏi - từ [TOTAL_QUESTIONS]</summary>
    public int TotalQuestions { get; set; }

    /// <summary>Đề thi đã được xuất bản hay chưa (giảng viên bấm "Publish")</summary>
    public bool IsPublished { get; set; }

    public virtual User CreatorUser { get; set; }

    /// <summary>Trạng thái đề thi (Draft/Published/Closed)</summary>
    public ExamStatus Status { get; set; } = ExamStatus.Draft;

    /// <summary>Ngày xuất bản (để sinh viên tham gia)</summary>
    public DateTime? PublishedTime { get; set; }

    /// <summary>Đường dẫn file Word gốc (nếu cần backup)</summary>
    [StringLength(500)]
    public string SourceFileName { get; set; }

    /// <summary>Navigation property - danh sách nhóm câu hỏi</summary>
    public virtual ICollection<QuestionGroup> QuestionGroups { get; set; }

    /// <summary>Navigation property - danh sách lượt làm bài của sinh viên</summary>
    public virtual ICollection<ExamAttempt> Attempts { get; set; }

    public Exam()
    {
        QuestionGroups = new List<QuestionGroup>();
        Attempts = new List<ExamAttempt>();
    }
}
