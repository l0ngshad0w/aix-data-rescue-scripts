# --- Paths
$projDir = "D:\ChurchApp\App\src\ChurchApp.Web"
Set-Location $projDir

# --- Model: Member
New-Item -ItemType Directory -Force .\Models | Out-Null
@'
namespace ChurchApp.Web;

public class Member
{
    public int Id { get; set; }
    public string MemberNo { get; set; } = "";
    public string FirstName { get; set; } = "";
    public string LastName { get; set; } = "";
    public string? Email { get; set; }
    public DateTime? JoinDate { get; set; }
    public bool Active { get; set; } = true;
}
'@ | Set-Content .\Models\Member.cs -Encoding UTF8

# --- Update ChurchContext (adds DbSet + simple mapping)
@'
using Microsoft.EntityFrameworkCore;

namespace ChurchApp.Web;

public class ChurchContext : DbContext
{
    public ChurchContext(DbContextOptions<ChurchContext> options) : base(options) {}

    public DbSet<Member> Members => Set<Member>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Member>(e =>
        {
            e.ToTable("Members");
            e.HasKey(m => m.Id);
            e.Property(m => m.MemberNo).HasMaxLength(32);
            e.Property(m => m.FirstName).HasMaxLength(100);
            e.Property(m => m.LastName).HasMaxLength(100);
            e.Property(m => m.Email).HasMaxLength(200);
        });
    }
}
'@ | Set-Content .\Data\ChurchContext.cs -Encoding UTF8

# --- Design-time factory (helps dotnet-ef create the context)
@'
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace ChurchApp.Web;

public class DesignTimeChurchContextFactory : IDesignTimeDbContextFactory<ChurchContext>
{
    public ChurchContext CreateDbContext(string[] args)
    {
        var basePath = AppContext.BaseDirectory;
        var config = new ConfigurationBuilder()
            .SetBasePath(basePath)
            .AddJsonFile("appsettings.Development.json", optional: true)
            .AddJsonFile("appsettings.json", optional: true)
            .AddEnvironmentVariables()
            .Build();

        var cs = config.GetConnectionString("DefaultConnection")
                 ?? "Server=localhost;Database=ChurchApp;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True";

        var options = new DbContextOptionsBuilder<ChurchContext>()
            .UseSqlServer(cs)
            .Options;

        return new ChurchContext(options);
    }
}
'@ | Set-Content .\Data\DesignTimeChurchContextFactory.cs -Encoding UTF8

# --- Ensure Production config exists (IIS uses ASPNETCORE_ENVIRONMENT=Production)
@'
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=ChurchApp;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True"
  }
}
'@ | Set-Content .\appsettings.Production.json -Encoding UTF8

# --- Members page (.NET 8 lives in Components/Pages)
New-Item -ItemType Directory -Force .\Components\Pages | Out-Null
@'
@page "/members"
@rendermode InteractiveServer
@using Microsoft.EntityFrameworkCore
@inject IDbContextFactory<ChurchApp.Web.ChurchContext> DbFactory

<h3>Members</h3>

@if (_members is null)
{
    <p>Loading…</p>
}
else if (_members.Count == 0)
{
    <p>No members yet.</p>
}
else
{
    <table class="table">
        <thead>
            <tr>
                <th>#</th>
                <th>Member #</th>
                <th>Name</th>
                <th>Email</th>
                <th>Active</th>
            </tr>
        </thead>
        <tbody>
        @foreach (var m in _members)
        {
            <tr>
                <td>@m.Id</td>
                <td>@m.MemberNo</td>
                <td>@m.LastName, @m.FirstName</td>
                <td>@m.Email</td>
                <td>@(m.Active ? "Yes" : "No")</td>
            </tr>
        }
        </tbody>
    </table>
}

@code {
    private List<ChurchApp.Web.Member>? _members;

    protected override async Task OnInitializedAsync()
    {
        await using var db = await DbFactory.CreateDbContextAsync();
        _members = await db.Members
            .OrderBy(m => m.LastName).ThenBy(m => m.FirstName)
            .Take(100)
            .ToListAsync();
    }
}
'@ | Set-Content .\Components\Pages\Members.razor -Encoding UTF8

# --- Optional: add to nav if the file exists
$nav = ".\Components\Layout\NavMenu.razor"
if (Test-Path $nav) {
@'
<li class="nav-item px-3">
    <a class="nav-link" href="members">Members</a>
</li>
'@ | Add-Content $nav -Encoding UTF8
}
