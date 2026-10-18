using Abp.Domain.Entities;
using Abp.Domain.Entities.Auditing;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace LeHongSon.Toeic.Exams;

/// <summary>
/// Bảng Question - Câu hỏi trong nhóm
/// Mapping với các tag: [Q: 101], [SHUFFLE_Q], [KEY], [HINT]
/// </summary>
public class Question : FullAuditedEntity<long>, IMayHaveTenant
{
    public const int MaxQuestionTextLength = 4000;
    public const int MaxHintLength = 2000;
    public const int MaxCorrectAnswerLength = 1;

    public int? TenantId { get; set; }

    /// <summary>FK tới bảng QuestionGroup</summary>
    public long QuestionGroupId { get; set; }
    public virtual QuestionGroup QuestionGroup { get; set; }

    /// <summary>
    /// Số thứ tự câu hỏi (101-200).
    /// Từ tag [Q: 101] -> [Q: 200].
    /// Phải duy nhất trong phạm vi một Exam.
    /// </summary>
    public int QuestionNumber { get; set; }

    /// <summary>Nội dung câu hỏi - từ [Q: 101] (phần text sau số thứ tự)</summary>
    [Required]
    [StringLength(MaxQuestionTextLength)]
    public string QuestionText { get; set; }

    /// <summary>
    /// Đáp án đúng ("A", "B", "C", hoặc "D") - từ [KEY: A|B|C|D].
    /// </summary>
    [Required]
    [StringLength(MaxCorrectAnswerLength)]
    public string CorrectAnswer { get; set; }

    /// <summary>
    /// Gợi ý / giải thích - từ [HINT: ...].
    /// Bắt buộc theo quy tắc validation.
    /// </summary>
    [StringLength(MaxHintLength)]
    public string Hint { get; set; }

    /// <summary>
    /// Có được phép hoán vị thứ tự câu hỏi trong nhóm hay không.
    /// Từ [SHUFFLE_Q: TRUE|FALSE].
    /// Theo validation: Part 5 = TRUE, Part 6 & 7 = FALSE.
    /// </summary>
    public bool ShuffleQuestion { get; set; }

    public bool ShuffleAnswers { get; set; }

    /// <summary>Thứ tự hiển thị nếu không shuffle (cố định = QuestionNumber)</summary>
    public int DisplayOrder { get; set; }

    /// <summary>Navigation property - danh sách 4 đáp án A/B/C/D</summary>
    public virtual ICollection<AnswerOption> AnswerOptions { get; set; }

    public Question()
    {
        AnswerOptions = new List<AnswerOption>();
    }
}
