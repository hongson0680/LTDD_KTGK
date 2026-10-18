using Abp.AspNetCore.Mvc.Authorization;
using LeHongSon.Controllers;
using Microsoft.AspNetCore.Mvc;

namespace LeHongSon.Web.Controllers;

[AbpMvcAuthorize]
public class AboutController : LeHongSonControllerBase
{
    public ActionResult Index()
    {
        return View();
    }
}
