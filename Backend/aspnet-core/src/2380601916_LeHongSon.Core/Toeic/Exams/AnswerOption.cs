using Abp.Domain.Entities;
using Abp.Domain.Entities.Auditing;
using System.ComponentModel.DataAnnotations;

namespace LeHongSon.Toeic.Exams;

/// <summary>
/// Bảng AnswerOption - 4 đáp án A/B/C/D của mỗi câu hỏi
/// Mapping với các tag: [A], [B], [C], [D], [SHUFFLE_A]
/// </summary>
public class AnswerOption : FullAuditedEntity<long>, IMayHaveTenant
{
    public const int MaxContentLength = 2000;
    public const int MaxLabelLength = 1;

    public int? TenantId { get; set; }

    /// <summary>FK tới bảng Question</summary>
    public long QuestionId { get; set; }
    public virtual Question Question { get; set; }

    /// <summary>
    /// Nhãn của đáp án: "A", "B", "C", hoặc "D".
    /// Lưu ý: nhãn này có thể khác với đáp án đúng sau khi shuffle.
    /// </summary>
    [Required]
    [StringLength(MaxLabelLength)]
    public string Label { get; set; }

    /// <summary>Nội dung đáp án - từ [A] your, [B] you, [C] yourself, [D] yours</summary>
    [Required]
    [StringLength(MaxContentLength)]
    public string Content { get; set; }

    /// <summary>
    /// Thứ tự hiển thị ban đầu (1, 2, 3, 4 tương ứng A, B, C, D).
    /// Khi shuffle, chỉ thay đổi thứ tự hiển thị, không thay đổi Label.
    /// </summary>
    public int DisplayOrder { get; set; }
}
