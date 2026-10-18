using Abp.Application.Services;
using Abp.Application.Services.Dto;
using Abp.Authorization;
using Abp.Domain.Entities;
using Abp.Domain.Repositories;
using Abp.UI;
using LeHongSon.Authorization;
using LeHongSon.Toeic.Exams;
using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace LeHongSon.Toeic.Imports;

[AbpAuthorize(PermissionNames.Pages_Exams)]
public class ExamAppService : ApplicationService
{
    private const int MaxEncodedUploadLength = 28 * 1024 * 1024;
    private readonly IRepository<Exam, long> _examRepository;
    private readonly IRepository<ExamAttempt, long> _attemptRepository;
    private readonly IRepository<StudentAnswer, long> _answerRepository;
    private readonly ToeicWordParser _parser;

    public ExamAppService(
        IRepository<Exam, long> examRepository,
        IRepository<ExamAttempt, long> attemptRepository,
        IRepository<StudentAnswer, long> answerRepository,
        ToeicWordParser parser)
    {
        _examRepository = examRepository;
        _attemptRepository = attemptRepository;
        _answerRepository = answerRepository;
        _parser = parser;
    }

    [AbpAuthorize(PermissionNames.Pages_Exams)]
    public async Task<System.Collections.Generic.List<TeacherExamListItemDto>> GetTeacherExamListAsync()
    {
        var exams = await _examRepository.GetAll().AsNoTracking()
            .OrderByDescending(e => e.CreationTime)
            .ToListAsync();
        var completedStatuses = new[] { AttemptStatus.Submitted, AttemptStatus.AutoSubmitted };
        var counts = await _attemptRepository.GetAll().AsNoTracking()
            .Where(a => !a.IsPractice && completedStatuses.Contains(a.Status))
            .GroupBy(a => a.ExamId)
            .Select(g => new { ExamId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.ExamId, x => x.Count);

        return exams.Select(e => new TeacherExamListItemDto
        {
            Id = e.Id,
            Title = e.Title,
            Description = e.Description,
            DurationMinutes = e.DurationMinutes,
            TotalQuestions = e.TotalQuestions,
            IsPublished = e.IsPublished,
            Status = e.Status.ToString(),
            CreationTime = e.CreationTime,
            SourceFileName = e.SourceFileName,
            AttemptCount = counts.TryGetValue(e.Id, out var count) ? count : 0
        }).ToList();
    }

    [AbpAuthorize(PermissionNames.Pages_Exams)]
    public async Task<ToeicExamPreviewDto> GetPreviewAsync(EntityDto<long> input)
    {
        var exam = await _examRepository.GetAll().AsNoTracking()
            .Include(e => e.QuestionGroups)
                .ThenInclude(g => g.Questions)
                    .ThenInclude(q => q.AnswerOptions)
            .Where(e => e.Id == input.Id)
            .FirstOrDefaultAsync();
        if (exam == null) throw new EntityNotFoundException(typeof(Exam), input.Id);
        return BuildPreview(exam);
    }

    [AbpAuthorize(PermissionNames.Pages_Exams_Create)]
    public async Task UpdateAsync(UpdateToeicExamInput input)
    {
        if (input == null || string.IsNullOrWhiteSpace(input.Title))
            throw new UserFriendlyException("Tiêu đề đề thi không được để trống.");
        if (input.Title.Length > Exam.MaxTitleLength || (input.Description?.Length ?? 0) > Exam.MaxDescriptionLength)
            throw new UserFriendlyException("Tiêu đề hoặc mô tả vượt quá độ dài cho phép.");
        if (input.DurationMinutes < 1 || input.DurationMinutes > 300)
            throw new UserFriendlyException("Thời lượng phải từ 1 đến 300 phút.");

        var exam = await _examRepository.GetAll()
            .Include(e => e.QuestionGroups)
                .ThenInclude(g => g.Questions)
                    .ThenInclude(q => q.AnswerOptions)
            .FirstOrDefaultAsync(e => e.Id == input.Id);
        if (exam == null) throw new EntityNotFoundException(typeof(Exam), input.Id);
        if (exam.IsPublished || exam.Status != ExamStatus.Draft)
            throw new UserFriendlyException("Chỉ có thể chỉnh sửa đề đang ở trạng thái bản nháp.");
        if (input.Groups == null || input.Groups.Count != exam.QuestionGroups.Count)
            throw new UserFriendlyException("Không được thêm hoặc xóa nhóm câu hỏi trong màn hình rà soát.");

        exam.Title = input.Title.Trim();
        exam.Description = input.Description?.Trim();
        exam.DurationMinutes = input.DurationMinutes;

        foreach (var groupInput in input.Groups)
        {
            var group = exam.QuestionGroups.FirstOrDefault(g => g.Id == groupInput.Id);
            if (group == null || groupInput.Questions == null || groupInput.Questions.Count != group.Questions.Count)
                throw new UserFriendlyException("Cấu trúc nhóm câu hỏi không khớp với đề đã nhập.");
            if ((groupInput.InstructionText?.Length ?? 0) > QuestionGroup.MaxInstructionLength ||
                (groupInput.PassageText?.Length ?? 0) > QuestionGroup.MaxPassageTextLength)
                throw new UserFriendlyException($"Nội dung nhóm Part {(int)group.PartType} vượt quá độ dài cho phép.");

            group.InstructionText = groupInput.InstructionText?.Trim();
            group.PassageText = groupInput.PassageText?.Trim();
            foreach (var questionInput in groupInput.Questions)
            {
                var question = group.Questions.FirstOrDefault(q => q.Id == questionInput.Id);
                if (question == null || string.IsNullOrWhiteSpace(questionInput.QuestionText) ||
                    questionInput.QuestionText.Length > Question.MaxQuestionTextLength ||
                    (questionInput.Hint?.Length ?? 0) > Question.MaxHintLength)
                    throw new UserFriendlyException("Nội dung câu hỏi hoặc gợi ý không hợp lệ.");
                if (questionInput.AnswerOptions == null || questionInput.AnswerOptions.Count != 4 ||
                    !questionInput.AnswerOptions.Select(o => o.Id).OrderBy(id => id)
                        .SequenceEqual(question.AnswerOptions.Select(o => o.Id).OrderBy(id => id)))
                    throw new UserFriendlyException($"Câu {question.QuestionNumber} phải giữ đủ bốn phương án gốc.");
                if (!new[] { "A", "B", "C", "D" }.Contains(questionInput.CorrectAnswer))
                    throw new UserFriendlyException($"Đáp án đúng câu {question.QuestionNumber} phải là A, B, C hoặc D.");
                if (questionInput.ShuffleQuestion != (group.PartType == PartType.Part5))
                    throw new UserFriendlyException($"Quy tắc trộn câu hỏi của Part {(int)group.PartType} không hợp lệ.");

                question.QuestionText = questionInput.QuestionText.Trim();
                question.CorrectAnswer = questionInput.CorrectAnswer;
                question.Hint = questionInput.Hint?.Trim();
                question.ShuffleQuestion = questionInput.ShuffleQuestion;
                question.ShuffleAnswers = questionInput.ShuffleAnswers;
                foreach (var optionInput in questionInput.AnswerOptions)
                {
                    var option = question.AnswerOptions.First(o => o.Id == optionInput.Id);
                    if (string.IsNullOrWhiteSpace(optionInput.Content) || optionInput.Content.Length > AnswerOption.MaxContentLength)
                        throw new UserFriendlyException($"Phương án {option.Label} câu {question.QuestionNumber} không hợp lệ.");
                    option.Content = optionInput.Content.Trim();
                }
            }
        }

        await CurrentUnitOfWork.SaveChangesAsync();
    }

    [AbpAuthorize(PermissionNames.Pages_Exams_Publish)]
    public async Task PublishAsync(EntityDto<long> input)
    {
        var exam = await _examRepository.GetAsync(input.Id);
        if (exam.Status == ExamStatus.Closed)
            throw new UserFriendlyException("Đề thi đã đóng, không thể xuất bản lại.");
        if (exam.TotalQuestions != 100)
            throw new UserFriendlyException("Chỉ xuất bản đề TOEIC Reading đủ 100 câu.");

        exam.Status = ExamStatus.Published;
        exam.IsPublished = true;
        exam.PublishedTime = DateTime.UtcNow;
        await _examRepository.UpdateAsync(exam);
    }

    [AbpAuthorize(PermissionNames.Pages_Exams_Publish)]
    public async Task CloseAsync(EntityDto<long> input)
    {
        var exam = await _examRepository.GetAsync(input.Id);
        exam.Status = ExamStatus.Closed;
        exam.IsPublished = false;
        await _examRepository.UpdateAsync(exam);
    }

    [AbpAuthorize(PermissionNames.Pages_Exams)]
    public async Task<ExamStatisticsDto> GetStatisticsAsync(EntityDto<long> input)
    {
        var examExists = await _examRepository.GetAll().AnyAsync(e => e.Id == input.Id);
        if (!examExists) throw new EntityNotFoundException(typeof(Exam), input.Id);

        var submittedStatuses = new[] { AttemptStatus.Submitted, AttemptStatus.AutoSubmitted };
        var submittedAttempts = await _attemptRepository.GetAll().AsNoTracking()
            // Teacher-facing exam metrics describe official exam sittings.
            // Practice attempts stay visible in the student's history only.
            .Where(a => a.ExamId == input.Id && !a.IsPractice && submittedStatuses.Contains(a.Status))
            .Select(a => new { a.Id, a.Score, a.EndTime, a.ExpireTime })
            .ToListAsync();
        var attemptIds = submittedAttempts.Select(a => a.Id).ToList();
        var partStatistics = await _answerRepository.GetAll().AsNoTracking()
            .Where(a => attemptIds.Contains(a.ExamAttemptId))
            .GroupBy(a => (int)a.Question.QuestionGroup.PartType)
            .Select(g => new
            {
                PartType = g.Key,
                QuestionCount = g.Count(),
                CorrectCount = g.Count(a => a.IsCorrect == true)
            })
            .OrderBy(x => x.PartType)
            .ToListAsync();
        var incorrectQuestions = await _answerRepository.GetAll().AsNoTracking()
            .Where(a => attemptIds.Contains(a.ExamAttemptId) && a.IsCorrect == false)
            .GroupBy(a => new { a.Question.QuestionNumber, Part = (int)a.Question.QuestionGroup.PartType })
            .Select(g => new { g.Key.QuestionNumber, g.Key.Part, Count = g.Count() })
            .OrderByDescending(x => x.Count)
            .ThenBy(x => x.QuestionNumber)
            .Take(10)
            .ToListAsync();

        return new ExamStatisticsDto
        {
            ExamId = input.Id,
            AttemptCount = submittedAttempts.Count,
            AverageScore = submittedAttempts.Count == 0 ? 0 : submittedAttempts.Average(a => a.Score),
            OnTimeAttemptCount = submittedAttempts.Count(a => a.EndTime.HasValue && a.EndTime.Value <= a.ExpireTime),
            OnTimeRate = submittedAttempts.Count == 0 ? 0 : 100d * submittedAttempts.Count(a => a.EndTime.HasValue && a.EndTime.Value <= a.ExpireTime) / submittedAttempts.Count,
            PartAccuracies = partStatistics.Select(p => new PartAccuracyDto
            {
                PartType = p.PartType,
                QuestionCount = p.QuestionCount,
                CorrectCount = p.CorrectCount,
                AccuracyPercent = p.QuestionCount == 0 ? 0 : 100d * p.CorrectCount / p.QuestionCount
            }).ToList(),
            MostIncorrectQuestions = incorrectQuestions.Select(q => new MostIncorrectQuestionDto
            {
                QuestionNumber = q.QuestionNumber,
                PartType = q.Part,
                IncorrectCount = q.Count,
                IncorrectRate = submittedAttempts.Count == 0 ? 0 : (double)q.Count / submittedAttempts.Count
            }).ToList()
        };
    }

    [AbpAuthorize(PermissionNames.Pages_Exams_Create)]
    public async Task<ToeicExamImportResultDto> ImportDraftAsync(ImportToeicExamInput input)
    {
        var exam = ParseInput(input);
        await _examRepository.InsertAsync(exam);
        await CurrentUnitOfWork.SaveChangesAsync();

        return new ToeicExamImportResultDto
        {
            ExamId = exam.Id,
            Title = exam.Title,
            DurationMinutes = exam.DurationMinutes,
            TotalQuestions = exam.TotalQuestions,
            GroupCount = exam.QuestionGroups.Count,
            Status = exam.Status.ToString()
        };
    }

    /// <summary>Parses and validates the Word document without writing to the database.</summary>
    [AbpAuthorize(PermissionNames.Pages_Exams_Create)]
    public Task<ToeicExamPreviewDto> PreviewImportAsync(ImportToeicExamInput input)
    {
        return Task.FromResult(BuildPreview(ParseInput(input)));
    }

    private static ToeicExamPreviewDto BuildPreview(Exam exam)
    {
        var preview = new ToeicExamPreviewDto
        {
            Title = exam.Title,
            DurationMinutes = exam.DurationMinutes,
            TotalQuestions = exam.TotalQuestions,
            GroupCount = exam.QuestionGroups.Count,
            SourceFileName = exam.SourceFileName,
            Description = exam.Description,
            Status = exam.Status.ToString(),
            IsPublished = exam.IsPublished
        };

        foreach (var group in exam.QuestionGroups.OrderBy(g => g.Order))
        {
            var groupDto = new ToeicQuestionGroupPreviewDto
            {
                Id = group.Id,
                PartType = (int)group.PartType,
                Order = group.Order,
                InstructionText = group.InstructionText,
                PassageText = group.PassageText,
                ImageUrl = group.ImageUrl
            };
            foreach (var question in group.Questions.OrderBy(q => q.QuestionNumber))
            {
                var questionDto = new ToeicQuestionPreviewDto
                {
                    Id = question.Id,
                    QuestionNumber = question.QuestionNumber,
                    QuestionText = question.QuestionText,
                    CorrectAnswer = question.CorrectAnswer,
                    Hint = question.Hint,
                    ShuffleQuestion = question.ShuffleQuestion,
                    ShuffleAnswers = question.ShuffleAnswers
                };
                foreach (var option in question.AnswerOptions.OrderBy(o => o.DisplayOrder))
                    questionDto.AnswerOptions.Add(new ToeicAnswerOptionPreviewDto { Id = option.Id, Label = option.Label, Content = option.Content, DisplayOrder = option.DisplayOrder });
                groupDto.Questions.Add(questionDto);
            }
            preview.Groups.Add(groupDto);
        }
        return preview;
    }

    private Exam ParseInput(ImportToeicExamInput input)
    {
        if (input == null || string.IsNullOrWhiteSpace(input.FileContentBase64))
            throw new UserFriendlyException("Chưa chọn file Word để import.");
        if (input.FileContentBase64.Length > MaxEncodedUploadLength)
            throw new UserFriendlyException("File vượt quá giới hạn 20 MB.");

        byte[] content;
        try { content = Convert.FromBase64String(input.FileContentBase64); }
        catch (FormatException) { throw new UserFriendlyException("Nội dung file upload không đúng định dạng."); }
        if (content.Length == 0 || content.Length > 20 * 1024 * 1024)
            throw new UserFriendlyException("File rỗng hoặc vượt quá giới hạn 20 MB.");

        try
        {
            using var stream = new MemoryStream(content, writable: false);
            return _parser.Parse(stream, input.FileName, AbpSession.TenantId, AbpSession.UserId.Value);
        }
        catch (ToeicWordParseException ex)
        {
            throw new UserFriendlyException("File Word chưa hợp lệ:\n" + ex.Message);
        }
    }
}
