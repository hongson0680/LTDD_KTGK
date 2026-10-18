using Abp.Events.Bus;
using Abp.Modules;
using Abp.Reflection.Extensions;
using LeHongSon.Configuration;
using LeHongSon.EntityFrameworkCore;
using LeHongSon.Migrator.DependencyInjection;
using Castle.MicroKernel.Registration;
using Microsoft.Extensions.Configuration;

namespace LeHongSon.Migrator;

[DependsOn(typeof(LeHongSonEntityFrameworkModule))]
public class LeHongSonMigratorModule : AbpModule
{
    private readonly IConfigurationRoot _appConfiguration;

    public LeHongSonMigratorModule(LeHongSonEntityFrameworkModule abpProjectNameEntityFrameworkModule)
    {
        abpProjectNameEntityFrameworkModule.SkipDbSeed = true;

        _appConfiguration = AppConfigurations.Get(
            typeof(LeHongSonMigratorModule).GetAssembly().GetDirectoryPathOrNull()
        );
    }

    public override void PreInitialize()
    {
        Configuration.DefaultNameOrConnectionString = _appConfiguration.GetConnectionString(
            LeHongSonConsts.ConnectionStringName
        );

        Configuration.BackgroundJobs.IsJobExecutionEnabled = false;
        Configuration.ReplaceService(
            typeof(IEventBus),
            () => IocManager.IocContainer.Register(
                Component.For<IEventBus>().Instance(NullEventBus.Instance)
            )
        );
    }

    public override void Initialize()
    {
        IocManager.RegisterAssemblyByConvention(typeof(LeHongSonMigratorModule).GetAssembly());
        ServiceCollectionRegistrar.Register(IocManager);
    }
}
