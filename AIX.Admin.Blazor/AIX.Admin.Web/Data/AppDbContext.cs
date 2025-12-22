using Microsoft.EntityFrameworkCore;
using AIX.Admin.Web.Data.Entities;

namespace AIX.Admin.Web.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Member> Members => Set<Member>();
    public DbSet<CourseTitle> CourseTitles { get; set; }
    public DbSet<MemberCourse> MemberCourses { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Configure Member table
        modelBuilder.Entity<Member>(entity =>
        {
            entity.ToTable("membr");
            entity.HasKey(e => e.MemberPkId);
            entity.HasIndex(e => e.MemberNo).IsUnique();

            // Column mappings
            entity.Property(e => e.MemberPkId).HasColumnName("member_pk_id");
            entity.Property(e => e.MemberNo).HasColumnName("member_no");
            entity.Property(e => e.ZipCode).HasColumnName("zip_code");
            entity.Property(e => e.ZipExt).HasColumnName("zip_ext");
            entity.Property(e => e.LastName).HasColumnName("last_name");
            entity.Property(e => e.FirstName).HasColumnName("first_name");
            entity.Property(e => e.MiddleName).HasColumnName("middle_name");
            entity.Property(e => e.Address1).HasColumnName("address1");
            entity.Property(e => e.Address2).HasColumnName("address2");
            entity.Property(e => e.City).HasColumnName("city");
            entity.Property(e => e.State).HasColumnName("state");
            entity.Property(e => e.ForeignAddress).HasColumnName("foreign_address");
            entity.Property(e => e.SameAdr).HasColumnName("same_adr");
            entity.Property(e => e.CongrNum).HasColumnName("congr_num");
            entity.Property(e => e.CongrNum2).HasColumnName("congr_num2");
            entity.Property(e => e.OrdinDate).HasColumnName("ordin_date");
            entity.Property(e => e.SubscrDate).HasColumnName("subscr_date");
            entity.Property(e => e.AreaCode).HasColumnName("area_code");
            entity.Property(e => e.PhoneNo).HasColumnName("phone_no");
            entity.Property(e => e.EmailAdr).HasColumnName("email_adr");
            entity.Property(e => e.LastModifiedDttm)
                  .HasColumnName("last_modified_dttm")
                  .HasDefaultValueSql("GETDATE()");
        });

        //Configure CourseTitle Table
        modelBuilder.Entity<CourseTitle>(entity =>
        {
            entity.ToTable("coursetitle");
            entity.HasKey(e => new { e.CtType, e.CtNumber });

            entity.Property(e => e.CtType).HasColumnName("ct_type").HasMaxLength(1).IsFixedLength();
            entity.Property(e => e.CtNumber).HasColumnName("ct_number");
            entity.Property(e => e.Desc1).HasColumnName("desc1").HasMaxLength(100);
            entity.Property(e => e.Desc2).HasColumnName("desc2").HasMaxLength(50);
        });

        // Configure MemberCourse join table
        modelBuilder.Entity<MemberCourse>(entity =>
        {
            entity.ToTable("ct_membr_xrf");
            entity.HasKey(e => new { e.MemberNo, e.CtType, e.CtNumber });

            entity.Property(e => e.MemberNo).HasColumnName("member_no");
            entity.Property(e => e.CtType).HasColumnName("ct_type").HasMaxLength(1).IsFixedLength();
            entity.Property(e => e.CtNumber).HasColumnName("ct_number");
            entity.Property(e => e.AssignedDate).HasColumnName("assigned_date");

            // Foreign key relationships
            entity.HasOne(e => e.Member)
                  .WithMany()
                  .HasForeignKey(e => e.MemberNo)
                  .HasPrincipalKey(m => m.MemberNo)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.CourseTitle)
                  .WithMany(ct => ct.MemberCourses)
                  .HasForeignKey(e => new { e.CtType, e.CtNumber })
                  .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
