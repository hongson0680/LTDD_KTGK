using Abp.Application.Services;
using LeHongSon.MultiTenancy.Dto;

namespace LeHongSon.MultiTenancy;

public interface ITenantAppService : IAsyncCrudAppService<TenantDto, int, PagedTenantResultRequestDto, CreateTenantDto, TenantDto>
{
}

