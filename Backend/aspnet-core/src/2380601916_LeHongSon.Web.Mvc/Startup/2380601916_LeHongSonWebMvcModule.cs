using Abp.Modules;
using Abp.Reflection.Extensions;
using LeHongSon.Configuration;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;

namespace LeHongSon.Web.Startup;

[DependsOn(typeof(LeHongSonWebCoreModule))]
public class LeHongSonWebMvcModule : AbpModule
{
    private readonly IWebHostEnvironment _env;
    private readonly IConfigurationRoot _appConfiguration;

    public LeHongSonWebMvcModule(IWebHostEnvironment env)
    {
        _env = env;
        _appConfiguration = env.GetAppConfiguration();
    }

    public override void PreInitialize()
    {
        Configuration.Navigation.Providers.Add<LeHongSonNavigationProvider>();
    }

    public override void Initialize()
    {
        IocManager.RegisterAssemblyByConvention(typeof(LeHongSonWebMvcModule).GetAssembly());
    }
}
