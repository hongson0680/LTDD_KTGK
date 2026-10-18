using System.ComponentModel.DataAnnotations;

namespace LeHongSon.Toeic.Imports;

public class ImportToeicExamInput
{
    [Required]
    [StringLength(260)]
    public string FileName { get; set; }

    /// <summary>Base64-encoded .docx bytes, suitable for the current ABP dynamic API transport.</summary>
    [Required]
    public string FileContentBase64 { get; set; }
}
