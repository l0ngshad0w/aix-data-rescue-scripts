# D:\ChurchApp\ops\create-blazor-project.ps1
# Creates a .NET 8 Blazor Web App (Server interactivity), wires EF Core, and runs it.

$root = "D:\ChurchApp\App\src"
New-Item -ItemType Directory -Force $root | Out-Null
Set-Location $root

# 1) Solution
if (!(Test-Path ".\ChurchApp.sln")) { dotnet new sln -n ChurchApp }

# 2) Blazor Web App (Server interactivity)  ← replaces 'dotnet new blazorserver'
if (!(Test-Path ".\ChurchApp.Web")) {
  dotnet new blazor -n ChurchApp.Web --interactivity Server
}

# 3) Add to solution + EF packages
dotnet sln add .\ChurchApp.Web\ChurchApp.Web.csproj
dotnet add .\ChurchApp.Web\ChurchApp.Web.csproj package Microsoft.EntityFrameworkCore.SqlServer
dotnet add .\ChurchApp.Web\ChurchApp.Web.csproj package Microsoft.EntityFrameworkCore.Design

# 4) Minimal Program.cs with Server interactivity + resilient SQL
$progPath = ".\ChurchApp.Web\Program.cs"
$prog = @"
using Microsoft.EntityFrameworkCore;
using ChurchApp.Web;
using ChurchApp.Web.Components;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

builder.Services.AddDbContextFactory<ChurchContext>(options =>
{
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        sql => sql.EnableRetryOnFailure(5, TimeSpan.FromSeconds(10), null)
    );
});

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseAntiforgery();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
"@
Set-Content -Path $progPath -Value $prog -Encoding UTF8

# 5) DbContext + settings
New-Item -ItemType Directory -Force .\ChurchApp.Web\Data | Out-Null
$ctx = @"
using Microsoft.EntityFrameworkCore;

namespace ChurchApp.Web;

public class ChurchContext : DbContext
{
    public ChurchContext(DbContextOptions<ChurchContext> options) : base(options) {}
    // public DbSet<Member> Members { get; set; } = default!;
}
"@
Set-Content .\ChurchApp.Web\Data\ChurchContext.cs $ctx -Encoding UTF8

$appsettingsDev = @"
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=ChurchApp;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True"
  }
}
"@
Set-Content .\ChurchApp.Web\appsettings.Development.json $appsettingsDev -Encoding UTF8

# 6) First run
Set-Location .\ChurchApp.Web
dotnet dev-certs https --trust | Out-Null
dotnet run
