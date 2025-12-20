# AIX Data Rescue - Project Status

## Overview
Migrate legacy church database from IBM AIX Informix SE 4.10 to SQL Server Express with modern Blazor UI.

## Current State (Dec 2024)
- **Data:** Extracted from AIX, loaded into SQL Server (multiple backups: laptop, workstation, OneDrive, flash drive)
- **Hardware:** SQL Server box built (Seattle desk), ready to deploy to Modesto
- **UI:** Blazor app prototyped, needs keyboard-first redesign
- **Deployment:** VPN tunnel configured, IIS installed but needs cleanup

## Key Requirements
- **Users:** Dad (20 hrs/week) + ex-MIL (40 hrs/week)
- **Primary workflow:** Fast member entry/update/search (muscle memory from green-screen)
- **Volume:** ~45 ordination requests/day (currently manual email processing)

## Known Issues
- Some data quality issues from Informix extraction (TBD investigation)
- Blazor UI too mouse-heavy (needs tab order, keyboard shortcuts)
- GitHub sync needed between laptop/workstation

## Next Steps
- [ ] Define SQL Server schema (document tables/relationships)
- [ ] Design keyboard-first UI workflow
- [ ] Build member search/entry screen (first iteration)
- [ ] Test deployment to Modesto box