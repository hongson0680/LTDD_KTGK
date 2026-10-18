using System.Collections.Generic;

namespace LeHongSon.Toeic.Imports;

public class UpdateToeicExamInput
{
    public long Id { get; set; }
    public string Title { get; set; }
    public string Description { get; set; }
    public int DurationMinutes { get; set; }
    public List<UpdateToeicQuestionGroupInput> Groups { get; set; } = new();
}

public class UpdateToeicQuestionGroupInput
{
    public long Id { get; set; }
    public string InstructionText { get; set; }
    public string PassageText { get; set; }
    public List<UpdateToeicQuestionInput> Questions { get; set; } = new();
}

public class UpdateToeicQuestionInput
{
    public long Id { get; set; }
    public string QuestionText { get; set; }
    public string CorrectAnswer { get; set; }
    public string Hint { get; set; }
    public bool ShuffleQuestion { get; set; }
    public bool ShuffleAnswers { get; set; }
    public List<UpdateToeicAnswerOptionInput> AnswerOptions { get; set; } = new();
}

public class UpdateToeicAnswerOptionInput
{
    public long Id { get; set; }
    public string Content { get; set; }
}
