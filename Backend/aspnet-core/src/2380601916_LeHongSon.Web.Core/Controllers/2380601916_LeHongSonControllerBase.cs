using Abp.AspNetCore.Mvc.Controllers;
using Abp.IdentityFramework;
using Microsoft.AspNetCore.Identity;

namespace LeHongSon.Controllers
{
    public abstract class LeHongSonControllerBase : AbpController
    {
        protected LeHongSonControllerBase()
        {
            LocalizationSourceName = LeHongSonConsts.LocalizationSourceName;
        }

        protected void CheckErrors(IdentityResult identityResult)
        {
            identityResult.CheckErrors(LocalizationManager);
        }
    }
}
