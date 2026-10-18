using Abp.AutoMapper;
using Abp.Modules;
using Abp.Reflection.Extensions;
using LeHongSon.Authorization;

namespace LeHongSon;

[DependsOn(
    typeof(LeHongSonCoreModule),
    typeof(AbpAutoMapperModule))]
public class LeHongSonApplicationModule : AbpModule
{
    public override void PreInitialize()
    {
        Configuration.Authorization.Providers.Add<LeHongSonAuthorizationProvider>();
    }

    public override void Initialize()
    {
        var thisAssembly = typeof(LeHongSonApplicationModule).GetAssembly();

        IocManager.RegisterAssemblyByConvention(thisAssembly);

        Configuration.Modules.AbpAutoMapper().Configurators.Add(
            // Scan the assembly for classes which inherit from AutoMapper.Profile
            cfg => cfg.AddMaps(thisAssembly)
        );
    }
}
