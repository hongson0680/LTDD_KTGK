using System;

namespace LeHongSon.Toeic.Imports;

public class TeacherExamListItemDto
{
    public long Id { get; set; }
    public string Title { get; set; }
    public string Description { get; set; }
    public int DurationMinutes { get; set; }
    public int TotalQuestions { get; set; }
    public bool IsPublished { get; set; }
    public string Status { get; set; }
    public DateTime CreationTime { get; set; }
    public string SourceFileName { get; set; }
    public int AttemptCount { get; set; }
}

public class ExamStatisticsDto
{
    public long ExamId { get; set; }
    public int AttemptCount { get; set; }
    public double AverageScore { get; set; }
    public int OnTimeAttemptCount { get; set; }
    public double OnTimeRate { get; set; }
    public System.Collections.Generic.List<PartAccuracyDto> PartAccuracies { get; set; } = new();
    public System.Collections.Generic.List<MostIncorrectQuestionDto> MostIncorrectQuestions { get; set; } = new();
}

public class PartAccuracyDto
{
    public int PartType { get; set; }
    public int QuestionCount { get; set; }
    public int CorrectCount { get; set; }
    public double AccuracyPercent { get; set; }
}

public class MostIncorrectQuestionDto
{
    public int QuestionNumber { get; set; }
    public int PartType { get; set; }
    public int IncorrectCount { get; set; }
    public double IncorrectRate { get; set; }
}
