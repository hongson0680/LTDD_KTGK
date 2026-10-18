using Abp.Application.Services.Dto;
using Abp.AspNetCore.Mvc.Authorization;
using LeHongSon.Authorization;
using LeHongSon.Controllers;
using LeHongSon.MultiTenancy;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;

namespace LeHongSon.Web.Controllers;

[AbpMvcAuthorize(PermissionNames.Pages_Tenants)]
public class TenantsController : LeHongSonControllerBase
{
    private readonly ITenantAppService _tenantAppService;

    public TenantsController(ITenantAppService tenantAppService)
    {
        _tenantAppService = tenantAppService;
    }

    public ActionResult Index() => View();

    public async Task<ActionResult> EditModal(int tenantId)
    {
        var tenantDto = await _tenantAppService.GetAsync(new EntityDto(tenantId));
        return PartialView("_EditModal", tenantDto);
    }
}
