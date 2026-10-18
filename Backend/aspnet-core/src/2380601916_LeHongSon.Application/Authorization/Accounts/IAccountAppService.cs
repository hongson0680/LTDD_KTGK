using Abp.Application.Services;
using LeHongSon.Authorization.Accounts.Dto;
using System.Threading.Tasks;

namespace LeHongSon.Authorization.Accounts;

public interface IAccountAppService : IApplicationService
{
    Task<IsTenantAvailableOutput> IsTenantAvailable(IsTenantAvailableInput input);

    Task<RegisterOutput> Register(RegisterInput input);
}
