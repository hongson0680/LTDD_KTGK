using LeHongSon.Configuration.Dto;
using System.Threading.Tasks;

namespace LeHongSon.Configuration;

public interface IConfigurationAppService
{
    Task ChangeUiTheme(ChangeUiThemeInput input);
}
