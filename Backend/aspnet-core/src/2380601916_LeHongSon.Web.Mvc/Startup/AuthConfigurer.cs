using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using LeHongSon.Configuration;
using System;

namespace LeHongSon.Web.Startup;

public static class AuthConfigurer
{
    public static void Configure(IServiceCollection services, IConfiguration configuration)
    {
        services.ConfigureApplicationCookie(options =>
        {
            options.AccessDeniedPath = "/Account/Forbidden";
        });

        if (bool.Parse(configuration["Authentication:JwtBearer:IsEnabled"]))
        {
            services.AddAuthentication()
                .AddJwtBearer(options =>
                {
                    options.Audience = configuration["Authentication:JwtBearer:Audience"];

                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        // The signing key must match!
                        ValidateIssuerSigningKey = true,
                        IssuerSigningKey = new SymmetricSecurityKey(JwtSigningKey.GetBytes(configuration)),

                        // Validate the JWT Issuer (iss) claim
                        ValidateIssuer = true,
                        ValidIssuer = configuration["Authentication:JwtBearer:Issuer"],

                        // Validate the JWT Audience (aud) claim
                        ValidateAudience = true,
                        ValidAudience = configuration["Authentication:JwtBearer:Audience"],

                        // Validate the token expiry
                        ValidateLifetime = true,

                        // If you want to allow a certain amount of clock drift, set that here
                        ClockSkew = TimeSpan.Zero
                    };
                });

        }
    }
}
