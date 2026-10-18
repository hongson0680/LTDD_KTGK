namespace LeHongSon.Toeic.Imports;

public class ToeicExamImportResultDto
{
    public long ExamId { get; set; }
    public string Title { get; set; }
    public int DurationMinutes { get; set; }
    public int TotalQuestions { get; set; }
    public int GroupCount { get; set; }
    public string Status { get; set; }
}
