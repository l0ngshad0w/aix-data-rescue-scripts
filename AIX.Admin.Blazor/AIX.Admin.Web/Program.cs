using Microsoft.EntityFrameworkCore;
using AIX.Admin.Web.Data;
using MudBlazor.Services;

var builder = WebApplication.CreateBuilder(args);

// Blazor services
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();
builder.Services.AddDbContext<DbContext>(); // Your DbContext

builder.Services.AddMudServices();

//var app = builder.Build();

// Connection string (matches appsettings.json key)
var conn = builder.Configuration.GetConnectionString("SqlExpress")
           ?? "Server=localhost;Database=ChurchDB;Trusted_Connection=True;TrustServerCertificate=True;";

// Register EF Core DbContext with retry logic
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(conn, sql =>
        sql.EnableRetryOnFailure(
            maxRetryCount: 5,
            maxRetryDelay: TimeSpan.FromSeconds(10),
            errorNumbersToAdd: null
        )
    )
);

var app = builder.Build();

// Pipeline
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();

app.MapBlazorHub();
app.MapFallbackToPage("/_Host");

app.Run();
