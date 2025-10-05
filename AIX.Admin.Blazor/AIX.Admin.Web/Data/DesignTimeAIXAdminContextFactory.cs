using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace AIX.Admin.Web
{
    public class DesignTimeAIXAdminContextFactory : IDesignTimeDbContextFactory<AIXAdminContext>
    {
        public AIXAdminContext CreateDbContext(string[] args)
        {
            var basePath = Directory.GetCurrentDirectory();
            var config = new ConfigurationBuilder()
                .SetBasePath(basePath)
                .AddJsonFile("appsettings.Development.json", optional: true)
                .AddJsonFile("appsettings.json", optional: true)
                .AddEnvironmentVariables()
                .Build();

            var cs = config.GetConnectionString("DefaultConnection")
                     ?? "Server=localhost;Database=ChurchApp;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True";

            var options = new DbContextOptionsBuilder<AIXAdminContext>()
                .UseSqlServer(cs)
                .Options;

            return new AIXAdminContext(options);
        }
    }
}
