# AIX Admin (Blazor Server, .NET 8)

Minimal starter to manage Members in SQL Server Express.

## Prereqs
- .NET SDK 8.x
- SQL Server Express (or LocalDB)
- EF Core tools: `dotnet tool update --global dotnet-ef`

## First run
```powershell
cd AIX.Admin.Blazor/AIX.Admin.Web
# Restore packages
dotnet restore

# Create initial migration + database
dotnet ef migrations add InitialCreate
dotnet ef database update

# Run
dotnet run
```

Then browse to `https://localhost:5001` (or terminal output).

## Connection string
Edit `appsettings.json` if your SQL instance differs. Example for LocalDB:
```
"Server=(localdb)\\MSSQLLocalDB;Database=AixRescue;Trusted_Connection=True;TrustServerCertificate=True;"
```

## Next steps
- Replace `Member` fields with your actual schema.
- Add more entities/pages (Courses, Titles, Member↔Course joins, etc.).
- Add authentication/authorization if needed.
- Deploy to IIS on `D:\` per your environment.