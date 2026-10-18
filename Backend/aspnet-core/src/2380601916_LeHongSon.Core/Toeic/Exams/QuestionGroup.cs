using Abp.Domain.Entities;
using Abp.Domain.Entities.Auditing;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace LeHongSon.Toeic.Exams;

/// <summary>
/// Bảng QuestionGroup - Nhóm câu hỏi theo Part và Passage
/// Mapping với các tag: [PART: 5|6|7], [PASSAGE_START/END]
/// </summary>
public class QuestionGroup : FullAuditedEntity<long>, IMayHaveTenant
{
    public const int MaxPassageTextLength = 8000;
    public const int MaxInstructionLength = 1000;
    public const int MaxImageUrlLength = 500;

    public int? TenantId { get; set; }

    /// <summary>FK tới bảng Exam</summary>
    public long ExamId { get; set; }
    public virtual Exam Exam { get; set; }

    /// <summary>Loại Part (5, 6, hoặc 7) - từ [PART: 5|6|7]</summary>
    public PartType PartType { get; set; }

    /// <summary>Thứ tự của nhóm trong đề (để hiển thị đúng thứ tự Part 5 -> 6 -> 7)</summary>
    public int Order { get; set; }

    /// <summary>
    /// Nội dung bài đọc (Text).
    /// Đối với Part 5: NULL.
    /// Đối với Part 6, 7: chứa toàn bộ nội dung giữa [PASSAGE_START] và [PASSAGE_END].
    /// </summary>
    [StringLength(MaxPassageTextLength)]
    public string PassageText { get; set; }

    /// <summary>
    /// Đường dẫn hình ảnh (nếu passage có hình - Part 7 thường có).
    /// Lưu trên server, lưu đường dẫn tương đối.
    /// </summary>
    [StringLength(MaxImageUrlLength)]
    public string ImageUrl { get; set; }

    /// <summary>
    /// Hướng dẫn cho nhóm câu hỏi (VD: "Questions 131-134 refer to the following memo.").
    /// </summary>
    [StringLength(MaxInstructionLength)]
    public string InstructionText { get; set; }

    /// <summary>Navigation property - danh sách câu hỏi trong nhóm</summary>
    public virtual ICollection<Question> Questions { get; set; }

    public QuestionGroup()
    {
        Questions = new List<Question>();
    }
}
