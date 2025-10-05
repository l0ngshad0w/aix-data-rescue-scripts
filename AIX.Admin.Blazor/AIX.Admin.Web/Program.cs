using Microsoft.EntityFrameworkCore;
using AIX.Admin.Web;                // adjust namespace if needed

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();

// ✅ EF Core DbContext factory (uses ConnectionStrings:DefaultConnection)
builder.Services.AddDbContextFactory<AIX.Admin.Web.AIXAdminContext>(opt =>
    opt.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.MapBlazorHub();                 // Blazor Server
app.MapFallbackToPage("/_Host");    // Razor Pages fallback
app.Run();
