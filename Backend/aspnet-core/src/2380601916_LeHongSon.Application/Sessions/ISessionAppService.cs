using Abp.Application.Services;
using LeHongSon.Sessions.Dto;
using System.Threading.Tasks;

namespace LeHongSon.Sessions;

public interface ISessionAppService : IApplicationService
{
    Task<GetCurrentLoginInformationsOutput> GetCurrentLoginInformations();
}
