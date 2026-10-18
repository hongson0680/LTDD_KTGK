using Abp.AutoMapper;
using LeHongSon.Sessions.Dto;

namespace LeHongSon.Web.Views.Shared.Components.TenantChange;

[AutoMapFrom(typeof(GetCurrentLoginInformationsOutput))]
public class TenantChangeViewModel
{
    public TenantLoginInfoDto Tenant { get; set; }
}
