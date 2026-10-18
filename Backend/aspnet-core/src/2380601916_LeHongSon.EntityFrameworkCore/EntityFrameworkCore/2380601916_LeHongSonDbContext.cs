using Abp.Zero.EntityFrameworkCore;
using LeHongSon.Authorization.Roles;
using LeHongSon.Authorization.Users;
using LeHongSon.MultiTenancy;
using LeHongSon.Toeic.Exams;
using Microsoft.EntityFrameworkCore;

namespace LeHongSon.EntityFrameworkCore;

public class LeHongSonDbContext : AbpZeroDbContext<Tenant, Role, User, LeHongSonDbContext>
{
    public DbSet<Exam> Exams { get; set; }
    public DbSet<QuestionGroup> QuestionGroups { get; set; }
    public DbSet<Question> Questions { get; set; }
    public DbSet<AnswerOption> AnswerOptions { get; set; }
    public DbSet<ExamAttempt> ExamAttempts { get; set; }
    public DbSet<StudentAnswer> StudentAnswers { get; set; }

    public LeHongSonDbContext(DbContextOptions<LeHongSonDbContext> options)
        : base(options)
    {
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Exam>(entity =>
        {
            entity.HasIndex(e => e.CreatorUserId);
            entity.HasOne(e => e.CreatorUser)
                .WithMany()
                .HasForeignKey(e => e.CreatorUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<QuestionGroup>(entity =>
        {
            entity.HasIndex(e => new { e.ExamId, e.Order }).IsUnique();
            entity.HasOne(e => e.Exam)
                .WithMany(e => e.QuestionGroups)
                .HasForeignKey(e => e.ExamId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Question>(entity =>
        {
            entity.HasIndex(e => new { e.QuestionGroupId, e.QuestionNumber }).IsUnique();
            entity.HasOne(e => e.QuestionGroup)
                .WithMany(e => e.Questions)
                .HasForeignKey(e => e.QuestionGroupId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<AnswerOption>(entity =>
        {
            entity.HasIndex(e => new { e.QuestionId, e.Label }).IsUnique();
            entity.HasIndex(e => new { e.QuestionId, e.DisplayOrder }).IsUnique();
            entity.HasOne(e => e.Question)
                .WithMany(e => e.AnswerOptions)
                .HasForeignKey(e => e.QuestionId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ExamAttempt>(entity =>
        {
            entity.HasIndex(e => new { e.ExamId, e.UserId });
            entity.HasOne(e => e.Exam)
                .WithMany(e => e.Attempts)
                .HasForeignKey(e => e.ExamId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(e => e.User)
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<StudentAnswer>(entity =>
        {
            entity.HasIndex(e => new { e.ExamAttemptId, e.QuestionId }).IsUnique();
            entity.HasOne(e => e.ExamAttempt)
                .WithMany(e => e.StudentAnswers)
                .HasForeignKey(e => e.ExamAttemptId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(e => e.Question)
                .WithMany()
                .HasForeignKey(e => e.QuestionId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(e => e.SelectedOption)
                .WithMany()
                .HasForeignKey(e => e.SelectedOptionId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
