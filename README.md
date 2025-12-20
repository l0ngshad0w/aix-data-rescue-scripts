# AIX Data Rescue Scripts

Legacy church database migration from IBM AIX Informix to SQL Server + Blazor UI.

## Project Structure
```
├── AIX.Admin.Blazor/      # Blazor web application
├── scripts/               # Migration and deployment scripts
│   ├── bash/             # Linux/AIX extraction scripts
│   ├── powershell/       # Windows automation
│   ├── sql/              # DDL and data transforms
│   └── deploy/           # Deployment automation
├── docs/                 # Project documentation
└── config/               # Configuration files
```

## Quick Start (Development)

1. **Database setup:**
```bash
   # Run SQL scripts to create schema
   sqlcmd -S localhost -i scripts/sql/create-schema.sql
```

2. **Run Blazor app:**
```bash
   cd AIX.Admin.Blazor/AIX.Admin.Web
   dotnet run
```

3. **Access locally:**
   Navigate to `https://localhost:5001`

## Documentation
- [Project Status](docs/project-status.md) - Current state and next steps
- [Tech Stack](docs/tech-stack.md) - Technology decisions
- See `docs/` for workflow documentation and design decisions

## Deployment
- Target: SQL Server box in Modesto, CA (VPN accessible)
- See `scripts/deploy/` for deployment automation