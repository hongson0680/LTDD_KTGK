using System.Collections.Generic;

namespace LeHongSon.Toeic.Imports;

public class ToeicExamPreviewDto
{
    public string Title { get; set; }
    public int DurationMinutes { get; set; }
    public int TotalQuestions { get; set; }
    public int GroupCount { get; set; }
    public string SourceFileName { get; set; }
    public string Description { get; set; }
    public string Status { get; set; }
    public bool IsPublished { get; set; }
    public List<ToeicQuestionGroupPreviewDto> Groups { get; set; } = new();
}

public class ToeicQuestionGroupPreviewDto
{
    public long Id { get; set; }
    public int PartType { get; set; }
    public int Order { get; set; }
    public string InstructionText { get; set; }
    public string PassageText { get; set; }
    public string ImageUrl { get; set; }
    public List<ToeicQuestionPreviewDto> Questions { get; set; } = new();
}

public class ToeicQuestionPreviewDto
{
    public long Id { get; set; }
    public int QuestionNumber { get; set; }
    public string QuestionText { get; set; }
    public string CorrectAnswer { get; set; }
    public string Hint { get; set; }
    public bool ShuffleQuestion { get; set; }
    public bool ShuffleAnswers { get; set; }
    public List<ToeicAnswerOptionPreviewDto> AnswerOptions { get; set; } = new();
}

public class ToeicAnswerOptionPreviewDto
{
    public long Id { get; set; }
    public string Label { get; set; }
    public string Content { get; set; }
    public int DisplayOrder { get; set; }
}
