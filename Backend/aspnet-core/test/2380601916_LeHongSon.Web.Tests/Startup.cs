using Abp.AspNetCore;
using Abp.AspNetCore.TestBase;
using Abp.Dependency;
using LeHongSon.Authentication.JwtBearer;
using LeHongSon.Configuration;
using LeHongSon.EntityFrameworkCore;
using LeHongSon.Identity;
using LeHongSon.Web.Resources;
using LeHongSon.Web.Startup;
using Castle.MicroKernel.Registration;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using System;

namespace LeHongSon.Web.Tests;

public class Startup
{
    private readonly IConfigurationRoot _appConfiguration;

    public Startup(IWebHostEnvironment env)
    {
        Environment.SetEnvironmentVariable(
            "Authentication__JwtBearer__SecurityKey",
            "test-only-signing-key-not-for-production-2026");
        _appConfiguration = env.GetAppConfiguration();
    }

    public IServiceProvider ConfigureServices(IServiceCollection services)
    {
        services.AddDataProtection().UseEphemeralDataProtectionProvider();
        services.AddEntityFrameworkInMemoryDatabase();

        services.AddMvc();

        IdentityRegistrar.Register(services);
        AuthConfigurer.Configure(services, _appConfiguration);

        services.AddScoped<IWebResourceManager, WebResourceManager>();

        //Configure Abp and Dependency Injection
        return services.AddAbp<LeHongSonWebTestModule>(options =>
        {
            options.SetupTest();
        });
    }

    public void Configure(IApplicationBuilder app, IWebHostEnvironment env, ILoggerFactory loggerFactory)
    {
        UseInMemoryDb(app.ApplicationServices);

        app.UseAbp(); //Initializes ABP framework.

        app.UseExceptionHandler("/Error");

        app.UseStaticFiles();
        app.UseRouting();

        app.UseAuthentication();

        app.UseJwtTokenMiddleware();

        app.UseAuthorization();

        app.UseEndpoints(endpoints =>
        {
            endpoints.MapControllerRoute("default", "{controller=Home}/{action=Index}/{id?}");
        });
    }

    private void UseInMemoryDb(IServiceProvider serviceProvider)
    {
        var builder = new DbContextOptionsBuilder<LeHongSonDbContext>();
        builder.UseInMemoryDatabase(Guid.NewGuid().ToString()).UseInternalServiceProvider(serviceProvider);
        var options = builder.Options;

        var iocManager = serviceProvider.GetRequiredService<IIocManager>();
        iocManager.IocContainer
            .Register(
                Component.For<DbContextOptions<LeHongSonDbContext>>()
                    .Instance(options)
                    .LifestyleSingleton()
            );
    }
}
