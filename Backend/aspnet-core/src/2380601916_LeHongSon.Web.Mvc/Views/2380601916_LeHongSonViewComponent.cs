using Abp.AspNetCore.Mvc.ViewComponents;

namespace LeHongSon.Web.Views;

public abstract class LeHongSonViewComponent : AbpViewComponent
{
    protected LeHongSonViewComponent()
    {
        LocalizationSourceName = LeHongSonConsts.LocalizationSourceName;
    }
}
