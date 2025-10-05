using Microsoft.EntityFrameworkCore;
using AIX.Admin.Web.Data.Entities;

namespace AIX.Admin.Web
{
    public class AIXAdminContext : DbContext
    {
        public AIXAdminContext(DbContextOptions<AIXAdminContext> options) : base(options) { }

        public DbSet<Member> Members => Set<Member>();
    }
}
