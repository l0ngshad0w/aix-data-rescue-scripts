using Microsoft.EntityFrameworkCore;
using AIX.Admin.Web.Data.Entities;

namespace AIX.Admin.Web.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Member> Members => Set<Member>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Member>(e =>
        {
            e.ToTable("membr"); // dbo.membr

            e.HasKey(m => m.MemberPkId).HasName("PK_membr_pk_id");
            e.Property(m => m.MemberPkId).HasColumnName("member_pk_id"); // identity

            e.Property(m => m.MemberNo).HasColumnName("member_no").IsRequired();
            // Optional (recommended): unique index on member_no
            e.HasIndex(m => m.MemberNo).IsUnique();

            e.Property(m => m.ZipCode).HasColumnName("zip_code");
            e.Property(m => m.ZipExt).HasColumnName("zip_ext");

            e.Property(m => m.LastName).HasColumnName("last_name").HasMaxLength(40);
            e.Property(m => m.FirstName).HasColumnName("first_name").HasMaxLength(40);
            e.Property(m => m.MiddleName).HasColumnName("middle_name").HasMaxLength(40);

            e.Property(m => m.Address1).HasColumnName("address1").HasMaxLength(100);
            e.Property(m => m.Address2).HasColumnName("address2").HasMaxLength(80);
            e.Property(m => m.City).HasColumnName("city").HasMaxLength(60);
            e.Property(m => m.State).HasColumnName("state").HasMaxLength(10);
            e.Property(m => m.ForeignAddress).HasColumnName("foreign_address").HasMaxLength(120);

            e.Property(m => m.SameAdr).HasColumnName("same_adr");

            e.Property(m => m.CongrNum).HasColumnName("congr_num");
            e.Property(m => m.CongrNum2).HasColumnName("congr_num2");

            e.Property(m => m.OrdinDate).HasColumnName("ordin_date");
            e.Property(m => m.SubscrDate).HasColumnName("subscr_date");

            e.Property(m => m.AreaCode).HasColumnName("area_code").HasMaxLength(10);
            e.Property(m => m.PhoneNo).HasColumnName("phone_no").HasMaxLength(20);
            e.Property(m => m.EmailAdr).HasColumnName("email_adr").HasMaxLength(120);

            e.Property(m => m.LastModifiedDttm).HasColumnName("last_modified_dttm");
        });
    }
}
