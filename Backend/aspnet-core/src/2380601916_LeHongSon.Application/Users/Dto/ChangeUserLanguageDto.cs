using System.ComponentModel.DataAnnotations;

namespace LeHongSon.Users.Dto;

public class ChangeUserLanguageDto
{
    [Required]
    public string LanguageName { get; set; }
}