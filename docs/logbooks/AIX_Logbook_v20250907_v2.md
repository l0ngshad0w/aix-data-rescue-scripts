# Travel VM / Dev Sync — Update (2025-09-07)

## Status
- ✅ Blazor admin app stands up locally and is deployed to IIS (`C:\ChurchApp\App\publish`).  
- ✅ Target stack locked: **.NET 9**, **EF Core 9**, **Blazor Server**.  
- ✅ Repo location for UI: `AIX.Admin.Blazor\AIX.Admin.Web` (under main scripts repo).  

## Decisions
- App serves as the **data entry + maintenance** UI for migrated members and related tables.  
- Source lives on **D:\** with Git; deploy output lives on **C:\ChurchApp** behind IIS.  
- SQL instance: `.\SQLEXPRESS` (override via `appsettings.json` if needed).  

## Environment snapshot
- Source: `D:\Projects\aix_data_rescue\aix-data-rescue-scripts\AIX.Admin.Blazor\AIX.Admin.Web`  
- Publish: `C:\ChurchApp\App\publish`  
- Connection string key: `ConnectionStrings:SqlExpress`  

## Near-term tasks (next 7 days)
1. Align **Member** fields to match AIX/4GL form (Address1/2, City, State, Zip, BirthDate, Status, Join/Expire, etc.).  
2. Add EF migration `Member_4GL_Shape` and update database.  
3. Add minimal validation (required Last/First/MemberNumber; max lengths).  
4. Create SQL **staging table** + mapping script for pipe-delimited import.  
5. Publish a Release build to IIS and smoke test with Dad & Dyan.  

## Risks / mitigations
- **Hosting bundle mismatch** → Confirm **.NET 9 Hosting Bundle** installed on server.  
- **Data shape mismatch** → Stage → map → load; do not import directly into live tables.  
- **Config drift** → Keep `appsettings.Development.json` local; don’t overwrite server config without review.  

## Definition of Done (Phase “UI-MVP”)
- Members: search, add, edit, delete working.  
- Form matches required 4GL fields and validations.  
- One successful import from staging into live members.  
- Basic usage guide for Dad & Dyan (one page with screenshots).  

## Change log
- **2025-09-07** – Initial Blazor app online in IIS; stack pinned to .NET 9 / EF 9; publish path and repo layout finalized.
