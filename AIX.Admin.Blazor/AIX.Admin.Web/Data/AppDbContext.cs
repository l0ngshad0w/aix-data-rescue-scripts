using Microsoft.EntityFrameworkCore;
using AIX.Admin.Web.Data.Entities;

namespace AIX.Admin.Web.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) {}

    public DbSet<Member> Members => Set<Member>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Member>(e =>
        {
			e.HasKey(m => m.Id);

			e.HasIndex(m => m.MemberNumber).IsUnique();
			e.Property(m => m.MemberNumber).HasMaxLength(32).IsRequired();

			e.Property(m => m.LastName).HasMaxLength(80).IsRequired();
			e.Property(m => m.FirstName).HasMaxLength(80).IsRequired();

			e.Property(m => m.Address1).HasMaxLength(120);
			e.Property(m => m.Address2).HasMaxLength(120);
			e.Property(m => m.City).HasMaxLength(80);
			e.Property(m => m.State).HasMaxLength(10);
			e.Property(m => m.PostalCode).HasMaxLength(20);

			e.Property(m => m.Phone).HasMaxLength(40);
			e.Property(m => m.Email).HasMaxLength(120);

			e.Property(m => m.Status).HasMaxLength(20);
        });
    }
}