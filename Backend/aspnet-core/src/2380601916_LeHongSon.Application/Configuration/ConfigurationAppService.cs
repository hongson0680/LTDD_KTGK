using Abp.Authorization;
using Abp.Runtime.Session;
using LeHongSon.Configuration.Dto;
using System.Threading.Tasks;

namespace LeHongSon.Configuration;

[AbpAuthorize]
public class ConfigurationAppService : LeHongSonAppServiceBase, IConfigurationAppService
{
    public async Task ChangeUiTheme(ChangeUiThemeInput input)
    {
        await SettingManager.ChangeSettingForUserAsync(AbpSession.ToUserIdentifier(), AppSettingNames.UiTheme, input.Theme);
    }
}
