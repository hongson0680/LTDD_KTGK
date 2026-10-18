using Abp.MultiTenancy;
using LeHongSon.Authorization.Users;

namespace LeHongSon.MultiTenancy;

public class Tenant : AbpTenant<User>
{
    public Tenant()
    {
    }

    public Tenant(string tenancyName, string name)
        : base(tenancyName, name)
    {
    }
}
