using Abp.Application.Services;
using Abp.Application.Services.Dto;
using Abp.Authorization;
using Abp.Domain.Entities;
using Abp.Domain.Repositories;
using Abp.UI;
using LeHongSon.Toeic.Exams;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace LeHongSon.Toeic.Imports;

/// <summary>Student exam flow. Answer keys and hints are only returned after submission.</summary>
[AbpAuthorize]
public class StudentExamAppService : ApplicationService
{
    private readonly IRepository<Exam, long> _exams;
    private readonly IRepository<ExamAttempt, long> _attempts;
    private readonly IRepository<StudentAnswer, long> _answers;
    private readonly IRepository<Question, long> _questions;
    private readonly IRepository<AnswerOption, long> _options;

    public StudentExamAppService(
        IRepository<Exam, long> exams,
        IRepository<ExamAttempt, long> attempts,
        IRepository<StudentAnswer, long> answers,
        IRepository<Question, long> questions,
        IRepository<AnswerOption, long> options)
    {
        _exams = exams;
        _attempts = attempts;
        _answers = answers;
        _questions = questions;
        _options = options;
    }

    public async Task<List<StudentExamListItemDto>> GetPublishedExamsAsync()
    {
        var userId = RequireUserId();
        var attempts = await _attempts.GetAll().AsNoTracking()
            // Practice is a separate learning flow and must not change the
            // official exam's resume/completion indicators.
            .Where(a => a.UserId == userId && !a.IsPractice)
            .Select(a => new { a.ExamId, a.Status, a.CreationTime })
            .ToListAsync();
        var latest = attempts.GroupBy(a => a.ExamId)
            .ToDictionary(g => g.Key, g => g.OrderByDescending(a => a.CreationTime).First().Status);

        var exams = await _exams.GetAll().AsNoTracking()
            .Where(e => e.IsPublished && e.Status == ExamStatus.Published)
            .OrderByDescending(e => e.PublishedTime)
            .ToListAsync();

        return exams.Select(e => new StudentExamListItemDto
        {
            Id = e.Id,
            Title = e.Title,
            Description = e.Description,
            DurationMinutes = e.DurationMinutes,
            TotalQuestions = e.TotalQuestions,
            HasInProgressAttempt = latest.TryGetValue(e.Id, out var status) && status == AttemptStatus.InProgress,
            HasCompletedAttempt = latest.TryGetValue(e.Id, out status) && (status == AttemptStatus.Submitted || status == AttemptStatus.AutoSubmitted)
        }).ToList();
    }

    /// <summary>Starts a new attempt, or resumes the student's existing in-progress attempt.</summary>
    public async Task<StudentAttemptDto> StartAsync(EntityDto<long> input)
    {
        return await StartAsync(input, isPractice: false);
    }

    public async Task<StudentAttemptDto> StartPracticeAsync(EntityDto<long> input)
    {
        return await StartAsync(input, isPractice: true);
    }

    private async Task<StudentAttemptDto> StartAsync(EntityDto<long> input, bool isPractice)
    {
        var userId = RequireUserId();
        var exam = await _exams.GetAll().AsNoTracking()
            .FirstOrDefaultAsync(e => e.Id == input.Id && e.IsPublished && e.Status == ExamStatus.Published);
        if (exam == null) throw new UserFriendlyException("Đề thi không tồn tại hoặc chưa được xuất bản.");

        var active = await _attempts.GetAll()
            .FirstOrDefaultAsync(a => a.ExamId == exam.Id && a.UserId == userId && a.Status == AttemptStatus.InProgress && a.IsPractice == isPractice);
        if (active != null)
        {
            if (DateTime.UtcNow >= active.ExpireTime)
            {
                await CompleteAsync(active, AttemptStatus.AutoSubmitted);
            }
            else
            {
                return await BuildAttemptAsync(active, includeResult: false);
            }
        }

        var now = DateTime.UtcNow;
        var attempt = new ExamAttempt
        {
            ExamId = exam.Id,
            UserId = userId,
            TenantId = AbpSession.TenantId,
            StartTime = now,
            ExpireTime = now.AddMinutes(exam.DurationMinutes),
            Status = AttemptStatus.InProgress,
            IsPractice = isPractice
        };
        await _attempts.InsertAsync(attempt);
        await CurrentUnitOfWork.SaveChangesAsync();
        return await BuildAttemptAsync(attempt, includeResult: false);
    }

    public async Task<List<StudentAttemptHistoryDto>> GetMyAttemptsAsync()
    {
        var userId = RequireUserId();
        return await _attempts.GetAll().AsNoTracking()
            .Where(a => a.UserId == userId)
            .OrderByDescending(a => a.StartTime)
            .Select(a => new StudentAttemptHistoryDto
            {
                AttemptId = a.Id,
                ExamId = a.ExamId,
                ExamTitle = a.Exam.Title,
                StartTime = a.StartTime,
                EndTime = a.EndTime,
                Status = a.Status.ToString(),
                IsPractice = a.IsPractice,
                TotalCorrect = a.TotalCorrect,
                TotalWrong = a.TotalWrong,
                TotalSkipped = a.TotalSkipped,
                Score = a.Score
            }).ToListAsync();
    }

    public async Task<StudentAttemptDto> GetAttemptAsync(EntityDto<long> input)
    {
        var attempt = await GetOwnedAttemptAsync(input.Id);
        if (attempt.Status == AttemptStatus.InProgress && DateTime.UtcNow >= attempt.ExpireTime)
            await CompleteAsync(attempt, AttemptStatus.AutoSubmitted);
        return await BuildAttemptAsync(attempt, includeResult: attempt.Status != AttemptStatus.InProgress);
    }

    /// <summary>Upserts one answer. Passing null for SelectedOptionId clears the student's answer.</summary>
    public async Task<StudentAttemptDto> SaveAnswerAsync(SaveStudentAnswerInput input)
    {
        if (input == null) throw new UserFriendlyException("Thiếu nội dung câu trả lời.");
        var attempt = await GetOwnedAttemptAsync(input.AttemptId);
        if (attempt.Status != AttemptStatus.InProgress)
            throw new UserFriendlyException("Lượt thi đã được nộp, không thể sửa câu trả lời.");
        if (DateTime.UtcNow >= attempt.ExpireTime)
        {
            await CompleteAsync(attempt, AttemptStatus.AutoSubmitted);
            return await BuildAttemptAsync(attempt, includeResult: true);
        }

        var question = await _questions.GetAll().AsNoTracking()
            .Include(q => q.QuestionGroup)
            .FirstOrDefaultAsync(q => q.Id == input.QuestionId && q.QuestionGroup.ExamId == attempt.ExamId);
        if (question == null) throw new UserFriendlyException("Câu hỏi không thuộc đề thi này.");

        if (input.SelectedOptionId.HasValue)
        {
            var optionIsValid = await _options.GetAll().AnyAsync(o => o.Id == input.SelectedOptionId.Value && o.QuestionId == question.Id);
            if (!optionIsValid) throw new UserFriendlyException("Đáp án đã chọn không thuộc câu hỏi này.");
        }

        var answer = await _answers.GetAll()
            .FirstOrDefaultAsync(a => a.ExamAttemptId == attempt.Id && a.QuestionId == question.Id);
        if (answer == null)
        {
            answer = new StudentAnswer { ExamAttemptId = attempt.Id, QuestionId = question.Id, TenantId = AbpSession.TenantId };
            await _answers.InsertAsync(answer);
        }
        answer.SelectedOptionId = input.SelectedOptionId;
        answer.IsCorrect = input.SelectedOptionId.HasValue
            ? await _options.GetAll().Where(o => o.Id == input.SelectedOptionId.Value).Select(o => o.Label == question.CorrectAnswer).FirstAsync()
            : null;
        answer.AnsweredAt = DateTime.UtcNow;
        answer.TimeSpentSeconds = input.TimeSpentSeconds is >= 0 and <= 86400 ? input.TimeSpentSeconds : null;
        await CurrentUnitOfWork.SaveChangesAsync();
        return await BuildAttemptAsync(attempt, includeResult: false);
    }

    public async Task<StudentAttemptDto> SubmitAsync(EntityDto<long> input)
    {
        var attempt = await GetOwnedAttemptAsync(input.Id);
        if (attempt.Status == AttemptStatus.InProgress)
        {
            var endStatus = DateTime.UtcNow >= attempt.ExpireTime
                ? AttemptStatus.AutoSubmitted
                : AttemptStatus.Submitted;
            await CompleteAsync(attempt, endStatus);
        }
        return await BuildAttemptAsync(attempt, includeResult: true);
    }

    public async Task<StudentAttemptDto> GetResultAsync(EntityDto<long> input)
    {
        var attempt = await GetOwnedAttemptAsync(input.Id);
        if (attempt.Status == AttemptStatus.InProgress && DateTime.UtcNow >= attempt.ExpireTime)
            await CompleteAsync(attempt, AttemptStatus.AutoSubmitted);
        if (attempt.Status == AttemptStatus.InProgress)
            throw new UserFriendlyException("Chỉ xem được kết quả sau khi nộp bài.");
        return await BuildAttemptAsync(attempt, includeResult: true);
    }

    private async Task CompleteAsync(ExamAttempt attempt, AttemptStatus status)
    {
        var questions = await _questions.GetAll()
            .Where(q => q.QuestionGroup.ExamId == attempt.ExamId)
            .Include(q => q.AnswerOptions)
            .ToListAsync();
        var stored = await _answers.GetAll()
            .Where(a => a.ExamAttemptId == attempt.Id)
            .ToDictionaryAsync(a => a.QuestionId);

        foreach (var question in questions)
        {
            if (!stored.TryGetValue(question.Id, out var answer))
            {
                answer = new StudentAnswer
                {
                    ExamAttemptId = attempt.Id,
                    QuestionId = question.Id,
                    TenantId = attempt.TenantId,
                    AnsweredAt = DateTime.UtcNow,
                    IsCorrect = null
                };
                await _answers.InsertAsync(answer);
            }
            else if (answer.SelectedOptionId.HasValue)
            {
                var selected = question.AnswerOptions.FirstOrDefault(o => o.Id == answer.SelectedOptionId.Value);
                answer.IsCorrect = selected != null && selected.Label == question.CorrectAnswer;
            }
            else
            {
                answer.IsCorrect = null;
            }
        }

        var answers = await _answers.GetAll().Where(a => a.ExamAttemptId == attempt.Id).ToListAsync();
        attempt.TotalCorrect = answers.Count(a => a.IsCorrect == true);
        attempt.TotalWrong = answers.Count(a => a.IsCorrect == false);
        attempt.TotalSkipped = Math.Max(0, questions.Count - attempt.TotalCorrect - attempt.TotalWrong);
        attempt.Score = attempt.TotalCorrect;
        attempt.Status = status;
        attempt.EndTime = DateTime.UtcNow;
        await _attempts.UpdateAsync(attempt);
        await CurrentUnitOfWork.SaveChangesAsync();
    }

    private async Task<ExamAttempt> GetOwnedAttemptAsync(long id)
    {
        var userId = RequireUserId();
        var attempt = await _attempts.GetAll().FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId);
        if (attempt == null) throw new EntityNotFoundException(typeof(ExamAttempt), id);
        return attempt;
    }

    private long RequireUserId() => AbpSession.UserId ?? throw new AbpAuthorizationException("Cần đăng nhập tài khoản sinh viên.");

    private async Task<StudentAttemptDto> BuildAttemptAsync(ExamAttempt attempt, bool includeResult)
    {
        var exam = await _exams.GetAll().AsNoTracking()
            .Include(e => e.QuestionGroups).ThenInclude(g => g.Questions).ThenInclude(q => q.AnswerOptions)
            .FirstAsync(e => e.Id == attempt.ExamId);
        var saved = await _answers.GetAll().AsNoTracking()
            .Where(a => a.ExamAttemptId == attempt.Id)
            .ToDictionaryAsync(a => a.QuestionId, a => a.SelectedOptionId);

        return new StudentAttemptDto
        {
            AttemptId = attempt.Id,
            ExamId = exam.Id,
            ExamTitle = exam.Title,
            DurationMinutes = exam.DurationMinutes,
            StartTime = attempt.StartTime,
            ExpireTime = attempt.ExpireTime,
            EndTime = attempt.EndTime,
            Status = attempt.Status.ToString(),
            IsResult = includeResult,
            TotalCorrect = includeResult ? attempt.TotalCorrect : null,
            TotalWrong = includeResult ? attempt.TotalWrong : null,
            TotalSkipped = includeResult ? attempt.TotalSkipped : null,
            Score = includeResult ? attempt.Score : null,
            Groups = exam.QuestionGroups.OrderBy(g => g.Order).Select(g => new StudentQuestionGroupDto
            {
                PartType = (int)g.PartType,
                InstructionText = g.InstructionText,
                PassageText = g.PassageText,
                ImageUrl = g.ImageUrl,
                Questions = g.Questions.OrderBy(q => q.ShuffleQuestion
                    ? StableOrder($"{attempt.Id}:group:{g.Id}:question:{q.Id}")
                    : q.QuestionNumber.ToString("D8")).Select(q => new StudentQuestionDto
                {
                    Id = q.Id,
                    QuestionNumber = q.QuestionNumber,
                    QuestionText = q.QuestionText,
                    SelectedOptionId = saved.TryGetValue(q.Id, out var selectedId) ? selectedId : null,
                    CorrectAnswer = includeResult ? q.CorrectAnswer : null,
                    Hint = includeResult ? q.Hint : null,
                    Options = q.AnswerOptions.OrderBy(o => q.ShuffleAnswers
                        ? StableOrder($"{attempt.Id}:question:{q.Id}:option:{o.Id}")
                        : o.DisplayOrder.ToString("D8")).Select(o => new StudentAnswerOptionDto
                    {
                        Id = o.Id,
                        Label = o.Label,
                        Content = o.Content
                    }).ToList()
                }).ToList()
            }).ToList()
        };
    }

    private static string StableOrder(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
}

public class StudentAttemptHistoryDto
{
    public long AttemptId { get; set; }
    public long ExamId { get; set; }
    public string ExamTitle { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime? EndTime { get; set; }
    public string Status { get; set; }
    public bool IsPractice { get; set; }
    public int TotalCorrect { get; set; }
    public int TotalWrong { get; set; }
    public int TotalSkipped { get; set; }
    public int Score { get; set; }
}

public class StudentExamListItemDto
{
    public long Id { get; set; }
    public string Title { get; set; }
    public string Description { get; set; }
    public int DurationMinutes { get; set; }
    public int TotalQuestions { get; set; }
    public bool HasInProgressAttempt { get; set; }
    public bool HasCompletedAttempt { get; set; }
}

public class SaveStudentAnswerInput
{
    public long AttemptId { get; set; }
    public long QuestionId { get; set; }
    public long? SelectedOptionId { get; set; }
    public int? TimeSpentSeconds { get; set; }
}

public class StudentAttemptDto
{
    public long AttemptId { get; set; }
    public long ExamId { get; set; }
    public string ExamTitle { get; set; }
    public int DurationMinutes { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime ExpireTime { get; set; }
    public DateTime? EndTime { get; set; }
    public string Status { get; set; }
    public bool IsResult { get; set; }
    public int? TotalCorrect { get; set; }
    public int? TotalWrong { get; set; }
    public int? TotalSkipped { get; set; }
    public int? Score { get; set; }
    public List<StudentQuestionGroupDto> Groups { get; set; } = new();
}

public class StudentQuestionGroupDto
{
    public int PartType { get; set; }
    public string InstructionText { get; set; }
    public string PassageText { get; set; }
    public string ImageUrl { get; set; }
    public List<StudentQuestionDto> Questions { get; set; } = new();
}

public class StudentQuestionDto
{
    public long Id { get; set; }
    public int QuestionNumber { get; set; }
    public string QuestionText { get; set; }
    public long? SelectedOptionId { get; set; }
    public string CorrectAnswer { get; set; }
    public string Hint { get; set; }
    public List<StudentAnswerOptionDto> Options { get; set; } = new();
}

public class StudentAnswerOptionDto
{
    public long Id { get; set; }
    public string Label { get; set; }
    public string Content { get; set; }
}
