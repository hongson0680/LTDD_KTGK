using Abp.AspNetCore;
using Abp.AspNetCore.TestBase;
using Abp.Modules;
using Abp.Reflection.Extensions;
using LeHongSon.EntityFrameworkCore;
using LeHongSon.Web.Startup;
using Microsoft.AspNetCore.Mvc.ApplicationParts;

namespace LeHongSon.Web.Tests;

[DependsOn(
    typeof(LeHongSonWebMvcModule),
    typeof(AbpAspNetCoreTestBaseModule)
)]
public class LeHongSonWebTestModule : AbpModule
{
    public LeHongSonWebTestModule(LeHongSonEntityFrameworkModule abpProjectNameEntityFrameworkModule)
    {
        abpProjectNameEntityFrameworkModule.SkipDbContextRegistration = true;
    }

    public override void PreInitialize()
    {
        Configuration.UnitOfWork.IsTransactional = false; //EF Core InMemory DB does not support transactions.
    }

    public override void Initialize()
    {
        IocManager.RegisterAssemblyByConvention(typeof(LeHongSonWebTestModule).GetAssembly());
    }

    public override void PostInitialize()
    {
        IocManager.Resolve<ApplicationPartManager>()
            .AddApplicationPartsIfNotAddedBefore(typeof(LeHongSonWebMvcModule).Assembly);
    }
}