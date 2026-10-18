using Microsoft.Extensions.Configuration;
using System;
using System.Text;

namespace LeHongSon.Configuration
{
    public static class JwtSigningKey
    {
        private const string ConfigurationPath = "Authentication:JwtBearer:SecurityKey";
        private const int MinimumKeyLengthBytes = 32;

        public static byte[] GetBytes(IConfiguration configuration)
        {
            var value = configuration[ConfigurationPath];
            if (string.IsNullOrWhiteSpace(value))
            {
                throw new InvalidOperationException(
                    $"Missing {ConfigurationPath}. Set it with .NET User Secrets for Development or " +
                    "the Authentication__JwtBearer__SecurityKey environment variable for deployment.");
            }

            var key = Encoding.UTF8.GetBytes(value);
            if (key.Length < MinimumKeyLengthBytes)
            {
                throw new InvalidOperationException(
                    $"{ConfigurationPath} must contain at least {MinimumKeyLengthBytes} UTF-8 bytes.");
            }

            return key;
        }
    }
}
