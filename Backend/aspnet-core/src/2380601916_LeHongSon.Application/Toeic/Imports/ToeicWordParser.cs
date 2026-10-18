using Abp.Dependency;
using LeHongSon.Toeic.Exams;
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using System.Xml;
using System.Xml.Linq;
using Microsoft.AspNetCore.Hosting;

namespace LeHongSon.Toeic.Imports;

/// <summary>Reads the tagged TOEIC .docx format and validates it before any database write.</summary>
public class ToeicWordParser : ITransientDependency
{
    private const int MaxUploadBytes = 20 * 1024 * 1024;
    private const int MaxDocumentXmlBytes = 30 * 1024 * 1024;
    private static readonly XNamespace WordNs = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
    private static readonly XNamespace DrawingNs = "http://schemas.openxmlformats.org/drawingml/2006/main";
    private static readonly XNamespace RelationshipNs = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
    private static readonly Regex HeaderTag = new(@"^\[(EXAM_TITLE|DURATION|TOTAL_QUESTIONS):\s*(.*?)\s*\]$", RegexOptions.Compiled | RegexOptions.IgnoreCase);
    private static readonly Regex PartTag = new(@"^\[PART:\s*([567])\](?:\s*(.*))?$", RegexOptions.Compiled | RegexOptions.IgnoreCase);
    private static readonly Regex QuestionTag = new(@"^\[Q:\s*(\d+)\]\s*(.*)$", RegexOptions.Compiled | RegexOptions.IgnoreCase);
    private static readonly Regex ValueTag = new(@"^\[(SHUFFLE_Q|SHUFFLE_A|KEY|HINT):\s*(.*?)\s*\]$", RegexOptions.Compiled | RegexOptions.IgnoreCase);
    private static readonly Regex OptionTag = new(@"^\[([ABCD])\]\s*(.*)$", RegexOptions.Compiled | RegexOptions.IgnoreCase);
    private static readonly Regex PassageStartTag = new(@"^\[PASSAGE_START\]\s*(.*)$", RegexOptions.Compiled | RegexOptions.IgnoreCase);
    private readonly string _webRootPath;

    public ToeicWordParser(IWebHostEnvironment environment)
    {
        _webRootPath = environment.WebRootPath;
    }

    public Exam Parse(Stream stream, string fileName, int? tenantId, long creatorUserId)
    {
        if (stream == null || !stream.CanRead)
            throw new ToeicWordParseException("Không đọc được nội dung file Word.");
        if (!string.Equals(Path.GetExtension(fileName), ".docx", StringComparison.OrdinalIgnoreCase))
            throw new ToeicWordParseException("Chỉ chấp nhận file .docx.");

        var pendingImages = new Dictionary<string, byte[]>(StringComparer.Ordinal);
        var lines = ReadParagraphs(stream, pendingImages);
        var exam = ParseLines(lines, Path.GetFileName(fileName), tenantId, creatorUserId);

        // Do not leave orphaned media behind when any tag or validation rule fails.
        // The URLs are deterministic hashes, so concurrent imports can safely reuse files.
        var outputDirectory = Path.Combine(_webRootPath ?? Path.Combine(AppContext.BaseDirectory, "wwwroot"), "toeic-images");
        Directory.CreateDirectory(outputDirectory);
        foreach (var image in pendingImages)
        {
            var fileNameOnly = Path.GetFileName(image.Key);
            var filePath = Path.Combine(outputDirectory, fileNameOnly);
            if (!File.Exists(filePath)) File.WriteAllBytes(filePath, image.Value);
        }
        return exam;
    }

    private static List<string> ReadParagraphs(Stream stream, IDictionary<string, byte[]> pendingImages)
    {
        if (stream.CanSeek && stream.Length > MaxUploadBytes)
            throw new ToeicWordParseException("File vượt quá giới hạn 20 MB.");

        try
        {
            using var archive = new ZipArchive(stream, ZipArchiveMode.Read, leaveOpen: true);
            var entry = archive.GetEntry("word/document.xml");
            if (entry == null || entry.Length > MaxDocumentXmlBytes)
                throw new ToeicWordParseException("File không phải tài liệu Word .docx hợp lệ hoặc phần nội dung vượt giới hạn.");

            using var entryStream = entry.Open();
            var settings = new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = MaxDocumentXmlBytes };
            using var reader = XmlReader.Create(entryStream, settings);
            var document = XDocument.Load(reader);
            var imageUrls = ReadImages(archive, pendingImages);
            return document.Descendants(WordNs + "p").Select(p => ReadParagraph(p, imageUrls)).ToList();
        }
        catch (ToeicWordParseException) { throw; }
        catch (Exception ex) when (ex is InvalidDataException || ex is XmlException || ex is IOException)
        {
            throw new ToeicWordParseException("Không thể đọc file .docx. Hãy kiểm tra file có bị hỏng hay không.");
        }
    }

    private static string ReadParagraph(XElement paragraph, IReadOnlyDictionary<string, string> imageUrls)
    {
        var parts = new List<string>();
        foreach (var node in paragraph.Descendants())
        {
            if (node.Name == WordNs + "t") parts.Add(node.Value);
            else if (node.Name == WordNs + "tab") parts.Add("\t");
            else if (node.Name == WordNs + "br" || node.Name == WordNs + "cr") parts.Add("\n");
            else if (node.Name == DrawingNs + "blip")
            {
                var relationshipId = (string)node.Attribute(RelationshipNs + "embed");
                if (relationshipId != null && imageUrls.TryGetValue(relationshipId, out var imageUrl))
                    parts.Add($"[DOCX_IMAGE:{imageUrl}]");
            }
        }
        return string.Concat(parts).Trim();
    }

    private static Exam ParseLines(IReadOnlyList<string> lines, string fileName, int? tenantId, long creatorUserId)
    {
        var errors = new List<string>();
        string title = null;
        int? duration = null;
        int? declaredTotal = null;
        var started = false;
        PartType? part = null;
        QuestionGroup currentGroup = null;
        QuestionGroup part5Group = null;
        var groups = new List<QuestionGroup>();
        var seenQuestionNumbers = new HashSet<int>();
        var questionParts = new Dictionary<int, PartType>();
        var headerTags = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var lastPartValue = 0;

        for (var i = 0; i < lines.Count; i++)
        {
            var line = lines[i].Trim();
            if (line.Length == 0) continue;

            var header = HeaderTag.Match(line);
            if (!started && header.Success)
            {
                var value = header.Groups[2].Value.Trim();
                var headerName = header.Groups[1].Value.ToUpperInvariant();
                if (!headerTags.Add(headerName)) errors.Add($"Khai báo [{headerName}] bị lặp.");
                switch (headerName)
                {
                    case "EXAM_TITLE": if (title != null) errors.Add("Khai báo [EXAM_TITLE] bị lặp."); else title = value; break;
                    case "DURATION": if (int.TryParse(value, out var minutes)) duration = minutes; else errors.Add("[DURATION] phải là số phút."); break;
                    case "TOTAL_QUESTIONS": if (int.TryParse(value, out var total)) declaredTotal = total; else errors.Add("[TOTAL_QUESTIONS] phải là số."); break;
                }
                continue;
            }

            // The supplied Word document includes a tag specification with illustrative tags.
            // Only the first exact [PART: 5] (not [PART: 5|6|7]) begins the actual exam.
            var partMatch = PartTag.Match(line);
            if (partMatch.Success)
            {
                started = true;
                part = (PartType)int.Parse(partMatch.Groups[1].Value);
                if ((int)part < lastPartValue) errors.Add("Thứ tự Part phải là 5 rồi 6 rồi 7.");
                lastPartValue = (int)part;
                currentGroup = null;
                if (part == PartType.Part5)
                {
                    part5Group = new QuestionGroup { PartType = part!.Value, Order = groups.Count + 1, TenantId = tenantId, InstructionText = TrimInstruction(partMatch.Groups[2].Value) };
                    groups.Add(part5Group);
                    currentGroup = part5Group;
                }
                else
                {
                    // Directions are associated with each passage group below.
                    currentGroup = null;
                }
                continue;
            }

            if (!started) continue;

            var passageStart = PassageStartTag.Match(line);
            if (passageStart.Success)
            {
                if (part == null || part == PartType.Part5)
                {
                    errors.Add($"Dòng {i + 1}: passage chỉ hợp lệ trong Part 6 hoặc Part 7.");
                    continue;
                }
                if (currentGroup != null && currentGroup.Questions.Count == 0)
                    errors.Add($"Dòng {i + 1}: passage trước đó không có câu hỏi.");
                var passageLines = new List<string>();
                var passageImages = new List<string>();
                var instruction = passageStart.Groups[1].Value.Trim();
                var foundEnd = false;
                while (++i < lines.Count)
                {
                    var passageLine = lines[i].Trim();
                    if (string.Equals(passageLine, "[PASSAGE_END]", StringComparison.OrdinalIgnoreCase)) { foundEnd = true; break; }
                    foreach (Match image in Regex.Matches(passageLine, @"\[DOCX_IMAGE:(/toeic-images/[a-f0-9]+\.[a-z]+)\]", RegexOptions.IgnoreCase))
                        passageImages.Add(image.Groups[1].Value);
                    passageLine = Regex.Replace(passageLine, @"\[DOCX_IMAGE:/toeic-images/[a-f0-9]+\.[a-z]+\]", "", RegexOptions.IgnoreCase).Trim();
                    if (passageLine.Length > 0) passageLines.Add(passageLine);
                }
                if (!foundEnd) { errors.Add("Thiếu [PASSAGE_END] cho passage."); break; }
                var passageText = string.Join(Environment.NewLine, passageLines.Where(x => x.Length > 0)).Trim();
                var passageImageUrls = string.Join("|", passageImages.Distinct());
                if (passageText.Length == 0) errors.Add($"Passage {groups.Count + 1} không có nội dung.");
                if (passageText.Length > QuestionGroup.MaxPassageTextLength) errors.Add($"Passage {groups.Count + 1} vượt quá {QuestionGroup.MaxPassageTextLength} ký tự.");
                if (passageImageUrls.Length > QuestionGroup.MaxImageUrlLength)
                    errors.Add($"Passage {groups.Count + 1} image paths exceed {QuestionGroup.MaxImageUrlLength} characters.");
                currentGroup = new QuestionGroup
                {
                    PartType = part!.Value,
                    Order = groups.Count + 1,
                    TenantId = tenantId,
                    PassageText = passageText,
                    ImageUrl = passageImageUrls,
                    InstructionText = Clip(instruction, QuestionGroup.MaxInstructionLength)
                };
                groups.Add(currentGroup);
                continue;
            }

            if (line.StartsWith("[PASSAGE_END]", StringComparison.OrdinalIgnoreCase))
            {
                errors.Add($"Dòng {i + 1}: [PASSAGE_END] không có [PASSAGE_START] tương ứng.");
                continue;
            }

            var questionMatch = QuestionTag.Match(line);
            if (!questionMatch.Success) continue;
            if (part == null) { errors.Add($"Dòng {i + 1}: câu hỏi nằm ngoài Part."); continue; }
            if (currentGroup == null)
            {
                errors.Add($"Câu {questionMatch.Groups[1].Value}: thiếu [PASSAGE_START] ở Part {(int)part}.");
                continue;
            }

            if (!int.TryParse(questionMatch.Groups[1].Value, out var number)) { errors.Add($"Dòng {i + 1}: số câu không hợp lệ."); continue; }
            if (!seenQuestionNumbers.Add(number)) errors.Add($"Câu {number} bị trùng.");
            questionParts[number] = part!.Value;
            var questionText = new List<string>();
            if (!string.IsNullOrWhiteSpace(questionMatch.Groups[2].Value)) questionText.Add(questionMatch.Groups[2].Value.Trim());
            var options = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            bool? shuffleQuestion = null, shuffleAnswers = null;
            string key = null, hint = null;
            var ended = false;

            while (++i < lines.Count)
            {
                var qLine = lines[i].Trim();
                if (string.Equals(qLine, "[END_Q]", StringComparison.OrdinalIgnoreCase)) { ended = true; break; }
                var valueMatch = ValueTag.Match(qLine);
                if (valueMatch.Success)
                {
                    var value = valueMatch.Groups[2].Value.Trim();
                    switch (valueMatch.Groups[1].Value.ToUpperInvariant())
                    {
                        case "SHUFFLE_Q": shuffleQuestion = ParseBoolean(value, "SHUFFLE_Q", number, errors); break;
                        case "SHUFFLE_A": shuffleAnswers = ParseBoolean(value, "SHUFFLE_A", number, errors); break;
                        case "KEY": key = value.ToUpperInvariant(); break;
                        case "HINT": hint = value; break;
                    }
                    continue;
                }
                var optionMatch = OptionTag.Match(qLine);
                if (optionMatch.Success)
                {
                    var label = optionMatch.Groups[1].Value.ToUpperInvariant();
                    if (options.ContainsKey(label)) errors.Add($"Câu {number}: thẻ [{label}] bị lặp.");
                    else options[label] = optionMatch.Groups[2].Value.Trim();
                    continue;
                }
                if (qLine.StartsWith("[", StringComparison.Ordinal)) errors.Add($"Câu {number}, dòng {i + 1}: tag không được hỗ trợ '{qLine}'.");
                else if (qLine.Length > 0) questionText.Add(qLine);
            }

            if (!ended) { errors.Add($"Câu {number}: thiếu [END_Q]."); break; }
            if (questionText.Count == 0) errors.Add($"Câu {number}: thiếu nội dung câu hỏi.");
            if (options.Count != 4 || new[] { "A", "B", "C", "D" }.Any(label => !options.ContainsKey(label))) errors.Add($"Câu {number}: phải có đủ [A], [B], [C], [D].");
            if (string.IsNullOrWhiteSpace(key) || !new[] { "A", "B", "C", "D" }.Contains(key)) errors.Add($"Câu {number}: [KEY] phải là A, B, C hoặc D.");
            if (string.IsNullOrWhiteSpace(hint)) errors.Add($"Câu {number}: thiếu [HINT].");
            if (!shuffleQuestion.HasValue) errors.Add($"Câu {number}: thiếu [SHUFFLE_Q].");
            if (!shuffleAnswers.HasValue) errors.Add($"Câu {number}: thiếu [SHUFFLE_A].");
            if (shuffleQuestion.HasValue && shuffleQuestion.Value != (part == PartType.Part5)) errors.Add($"Câu {number}: SHUFFLE_Q phải là {(part == PartType.Part5 ? "TRUE" : "FALSE")} trong Part {(int)part}.");
            if (questionText.Sum(x => x.Length) > Question.MaxQuestionTextLength) errors.Add($"Câu {number}: nội dung vượt quá {Question.MaxQuestionTextLength} ký tự.");
            if (hint?.Length > Question.MaxHintLength) errors.Add($"Câu {number}: HINT vượt quá {Question.MaxHintLength} ký tự.");
            foreach (var option in options) if (option.Value.Length == 0 || option.Value.Length > AnswerOption.MaxContentLength) errors.Add($"Câu {number}: đáp án {option.Key} rỗng hoặc vượt quá {AnswerOption.MaxContentLength} ký tự.");

            var question = new Question
            {
                TenantId = tenantId,
                QuestionNumber = number,
                DisplayOrder = number,
                QuestionText = Clip(string.Join(Environment.NewLine, questionText).Trim(), Question.MaxQuestionTextLength),
                CorrectAnswer = key,
                Hint = Clip(hint, Question.MaxHintLength),
                ShuffleQuestion = shuffleQuestion ?? false,
                ShuffleAnswers = shuffleAnswers ?? false
            };
            foreach (var label in new[] { "A", "B", "C", "D" })
                if (options.TryGetValue(label, out var content)) question.AnswerOptions.Add(new AnswerOption { TenantId = tenantId, Label = label, Content = Clip(content, AnswerOption.MaxContentLength), DisplayOrder = Array.IndexOf(new[] { "A", "B", "C", "D" }, label) + 1 });
            currentGroup.Questions.Add(question);
        }

        if (string.IsNullOrWhiteSpace(title)) errors.Add("Thiếu [EXAM_TITLE].");
        if (title?.Length > Exam.MaxTitleLength) errors.Add($"EXAM_TITLE vượt quá {Exam.MaxTitleLength} ký tự.");
        if (!duration.HasValue || duration <= 0 || duration > 300) errors.Add("[DURATION] phải từ 1 đến 300 phút.");
        if (!declaredTotal.HasValue || declaredTotal <= 0) errors.Add("Thiếu [TOTAL_QUESTIONS] hợp lệ.");
        if (!started) errors.Add("Không tìm thấy phần đề bắt đầu bằng [PART: 5], [PART: 6] hoặc [PART: 7].");
        if (declaredTotal.HasValue && seenQuestionNumbers.Count != declaredTotal.Value) errors.Add($"File khai báo {declaredTotal.Value} câu nhưng tìm thấy {seenQuestionNumbers.Count} câu.");
        if (declaredTotal == 100 && Enumerable.Range(101, 100).Any(n => !seenQuestionNumbers.Contains(n))) errors.Add("Số câu phải liên tục từ 101 đến 200.");
        if (declaredTotal == 100)
        {
            var expectedParts = new[] { (PartType.Part5, 101, 130, 30), (PartType.Part6, 131, 146, 16), (PartType.Part7, 147, 200, 54) };
            foreach (var expected in expectedParts)
            {
                var actualCount = questionParts.Count(x => x.Value == expected.Item1);
                if (actualCount != expected.Item4) errors.Add($"Part {(int)expected.Item1} phải có {expected.Item4} câu nhưng có {actualCount}.");
                foreach (var questionNumber in Enumerable.Range(expected.Item2, expected.Item3 - expected.Item2 + 1))
                    if (questionParts.TryGetValue(questionNumber, out var actualPart) && actualPart != expected.Item1)
                        errors.Add($"Câu {questionNumber} phải thuộc Part {(int)expected.Item1}.");
            }
        }
        if (!groups.Any(g => g.PartType == PartType.Part5) || !groups.Any(g => g.PartType == PartType.Part6) || !groups.Any(g => g.PartType == PartType.Part7)) errors.Add("Đề phải có đủ Part 5, Part 6 và Part 7.");
        foreach (var group in groups.Where(g => g.PartType != PartType.Part5 && g.Questions.Count == 0)) errors.Add($"Nhóm passage thứ tự {group.Order} không có câu hỏi.");
        if (part5Group != null && part5Group.PassageText != null) errors.Add("Part 5 không được chứa passage.");

        if (errors.Count > 0) throw new ToeicWordParseException(errors);
        return new Exam
        {
            TenantId = tenantId,
            CreatorUserId = creatorUserId,
            Title = title.Trim(),
            DurationMinutes = duration.Value,
            TotalQuestions = declaredTotal.Value,
            IsPublished = false,
            Status = ExamStatus.Draft,
            SourceFileName = Clip(fileName, 500),
            QuestionGroups = groups
        };
    }

    private static Dictionary<string, string> ReadImages(ZipArchive archive, IDictionary<string, byte[]> pendingImages)
    {
        var result = new Dictionary<string, string>(StringComparer.Ordinal);
        var relationships = archive.GetEntry("word/_rels/document.xml.rels");
        if (relationships == null) return result;

        using var relationStream = relationships.Open();
        using var reader = XmlReader.Create(relationStream, new XmlReaderSettings
        {
            DtdProcessing = DtdProcessing.Prohibit,
            XmlResolver = null,
            MaxCharactersInDocument = 1024 * 1024
        });
        var relationDocument = XDocument.Load(reader);
        XNamespace packageNs = "http://schemas.openxmlformats.org/package/2006/relationships";
        long totalImageBytes = 0;
        foreach (var relation in relationDocument.Descendants(packageNs + "Relationship"))
        {
            var id = (string)relation.Attribute("Id");
            var target = (string)relation.Attribute("Target");
            var type = (string)relation.Attribute("Type");
            if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(target) || type?.EndsWith("/image", StringComparison.OrdinalIgnoreCase) != true)
                continue;

            var entryPath = target.StartsWith("/", StringComparison.Ordinal)
                ? target.TrimStart('/')
                : "word/" + target;
            entryPath = entryPath.Replace('\\', '/');
            if (entryPath.Split('/').Any(part => part == "..")) continue;
            var imageEntry = archive.GetEntry(entryPath);
            if (imageEntry == null || imageEntry.Length <= 0 || imageEntry.Length > MaxUploadBytes) continue;
            totalImageBytes += imageEntry.Length;
            if (totalImageBytes > MaxUploadBytes)
                throw new ToeicWordParseException("Total image data in this Word file exceeds 20 MB.");

            var extension = Path.GetExtension(entryPath).ToLowerInvariant();
            if (extension is not (".png" or ".jpg" or ".jpeg" or ".gif" or ".bmp" or ".webp")) continue;
            using var imageStream = imageEntry.Open();
            using var bytes = new MemoryStream();
            imageStream.CopyTo(bytes);
            var content = bytes.ToArray();
            var hash = Convert.ToHexString(SHA256.HashData(content)).ToLowerInvariant();
            var imageUrl = "/toeic-images/" + hash + extension;
            pendingImages.TryAdd(imageUrl, content);
            result[id] = imageUrl;
        }
        return result;
    }

    private static bool? ParseBoolean(string value, string tag, int number, ICollection<string> errors)
    {
        if (string.Equals(value, "TRUE", StringComparison.OrdinalIgnoreCase)) return true;
        if (string.Equals(value, "FALSE", StringComparison.OrdinalIgnoreCase)) return false;
        errors.Add($"Câu {number}: [{tag}] chỉ nhận TRUE hoặc FALSE.");
        return null;
    }

    private static string TrimInstruction(string text)
    {
        var marker = text.IndexOf("Directions:", StringComparison.OrdinalIgnoreCase);
        return marker >= 0 ? Clip(text[(marker + "Directions:".Length)..].Trim(), QuestionGroup.MaxInstructionLength) : Clip(text, QuestionGroup.MaxInstructionLength);
    }

    private static string Clip(string value, int maxLength) => value == null || value.Length <= maxLength ? value : value[..maxLength];
}

public class ToeicWordParseException : Exception
{
    public IReadOnlyList<string> Errors { get; }
    public ToeicWordParseException(string error) : this(new[] { error }) { }
    public ToeicWordParseException(IEnumerable<string> errors) : base(string.Join(Environment.NewLine, errors)) => Errors = errors.ToArray();
}
