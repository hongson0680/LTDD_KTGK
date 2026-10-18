using Abp.Modules;
using Abp.Reflection.Extensions;
using LeHongSon.Configuration;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;

namespace LeHongSon.Web.Host.Startup
{
    [DependsOn(
       typeof(LeHongSonWebCoreModule))]
    public class LeHongSonWebHostModule : AbpModule
    {
        private readonly IWebHostEnvironment _env;
        private readonly IConfigurationRoot _appConfiguration;

        public LeHongSonWebHostModule(IWebHostEnvironment env)
        {
            _env = env;
            _appConfiguration = env.GetAppConfiguration();
        }

        public override void Initialize()
        {
            IocManager.RegisterAssemblyByConvention(typeof(LeHongSonWebHostModule).GetAssembly());
        }
    }
}
