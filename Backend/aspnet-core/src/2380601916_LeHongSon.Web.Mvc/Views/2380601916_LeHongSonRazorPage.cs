using Abp.AspNetCore.Mvc.Views;
using Abp.Runtime.Session;
using Microsoft.AspNetCore.Mvc.Razor.Internal;

namespace LeHongSon.Web.Views;

public abstract class LeHongSonRazorPage<TModel> : AbpRazorPage<TModel>
{
    [RazorInject]
    public IAbpSession AbpSession { get; set; }

    protected LeHongSonRazorPage()
    {
        LocalizationSourceName = LeHongSonConsts.LocalizationSourceName;
    }
}
