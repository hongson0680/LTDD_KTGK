using Xunit;

namespace LeHongSon.Tests;

public sealed class MultiTenantFactAttribute : FactAttribute
{
    public MultiTenantFactAttribute()
    {
        Skip = LeHongSonConsts.MultiTenancyEnabled
            ? null
            : "MultiTenancy is disabled.";
    }
}
