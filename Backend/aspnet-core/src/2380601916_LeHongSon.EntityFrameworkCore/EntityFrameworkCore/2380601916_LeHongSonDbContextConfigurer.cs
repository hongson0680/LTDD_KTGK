using Microsoft.EntityFrameworkCore;
using System.Data.Common;

namespace LeHongSon.EntityFrameworkCore;

public static class LeHongSonDbContextConfigurer
{
    public static void Configure(DbContextOptionsBuilder<LeHongSonDbContext> builder, string connectionString)
    {
        builder.UseSqlServer(connectionString);
    }

    public static void Configure(DbContextOptionsBuilder<LeHongSonDbContext> builder, DbConnection connection)
    {
        builder.UseSqlServer(connection);
    }
}
