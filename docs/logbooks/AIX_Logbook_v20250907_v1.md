# 📓 Project Logbook: AIX Schema & Extraction

## 🗂️ Project Charter

Goal:\
Migrate critical AIX system data into a modern environment by:

\- Discovering structure via probe tools\
- Extracting raw/staged data via extractors\
- Designing a usable schema in SQL Express (or equivalent)\
- Validating fidelity so no data is lost

Target Environment: Ubuntu VM (for staging/testing) → SQL Express

## ✅ What's Done

-   Data copied off AIX: /etc, /home, /opt, /tmp, /var (via FTP)

-   Target environment (Ubuntu VM) ready for use

-   Tools acquired: Extractors + Probe scripts

-   Workspace defined:
    /opt/aix-rescue/{tools,bin,conf,logs,data_raw,data_stage}

-   Transfer methods ready: Shared Folder, SCP, USB passthrough

## 🚧 Next Steps

-   Load tools into VM

-   Normalize line endings & make executables (dos2unix, chmod +x)

-   Run probe on sample dir (/etc) → capture JSON + log outputs

-   Run extractor (limit 100 rows) → validate staged CSVs

-   Begin schema draft → staging tables + data dictionary

-   Validate counts across all stages

## 📝 Working Checklist (Table Format)

### Environment Setup

  --------------------------------------------------------------------------
  Task                       Status                  Notes
  -------------------------- ----------------------- -----------------------
  Create workspace           \[ \] Not Started / \[  \...
  directories in             \] In Progress / \[ \]  
  /opt/aix-rescue            Done                    

  Install utilities          \[ \] Not Started / \[  \...
  (virtualbox-guest-utils,   \] In Progress / \[ \]  
  dos2unix, jq, sqlite3)     Done                    

  Verify data directories    \[ \] Not Started / \[  \...
  mounted/shared             \] In Progress / \[ \]  
                             Done                    

  Confirm SQL Express        \[ \] Not Started / \[  \...
  connectivity               \] In Progress / \[ \]  
  (network/ODBC/JDBC test)   Done                    
  --------------------------------------------------------------------------

### Load Tools

  -----------------------------------------------------------------------
  Task                    Status                  Notes
  ----------------------- ----------------------- -----------------------
  Transfer extractor &    \[ \] Not Started / \[  \...
  probe files →           \] In Progress / \[ \]  
  /opt/aix-rescue/tools   Done                    

  Run dos2unix + chmod +x \[ \] Not Started / \[  \...
                          \] In Progress / \[ \]  
                          Done                    

  Confirm shebang lines   \[ \] Not Started / \[  \...
  (#!/usr/bin/env bash or \] In Progress / \[ \]  
  python3)                Done                    

  Verify interpreter      \[ \] Not Started / \[  \...
  versions (bash          \] In Progress / \[ \]  
  \--version, python3     Done                    
  \--version)                                     
  -----------------------------------------------------------------------

### Probe Run

  -----------------------------------------------------------------------
  Task                    Status                  Notes
  ----------------------- ----------------------- -----------------------
  Run probe on /etc (or   \[ \] Not Started / \[  \...
  chosen dir)             \] In Progress / \[ \]  
                          Done                    

  Save outputs →          \[ \] Not Started / \[  \...
  /data_stage and         \] In Progress / \[ \]  
  /logs/YYYYMMDD_HHMM/    Done                    

  Review JSON + logs for  \[ \] Not Started / \[  \...
  file counts & types     \] In Progress / \[ \]  
                          Done                    

  Capture sample (10      \[ \] Not Started / \[  \...
  lines per file)         \] In Progress / \[ \]  
                          Done                    

  Save MD5 checksums of   \[ \] Not Started / \[  \...
  probed files            \] In Progress / \[ \]  
                          Done                    
  -----------------------------------------------------------------------

### Extractor Run (Pilot)

  -----------------------------------------------------------------------
  Task                    Status                  Notes
  ----------------------- ----------------------- -----------------------
  Run extractor with      \[ \] Not Started / \[  \...
  \--limit 100            \] In Progress / \[ \]  
                          Done                    

  Validate CSV row counts \[ \] Not Started / \[  \...
  vs expectations         \] In Progress / \[ \]  
                          Done                    

  Confirm encoding (file, \[ \] Not Started / \[  \...
  cat -v) and delimiter   \] In Progress / \[ \]  
  correctness             Done                    

  Check for uniqueness of \[ \] Not Started / \[  \...
  expected keys           \] In Progress / \[ \]  
                          Done                    
  -----------------------------------------------------------------------

### Schema Work

  -----------------------------------------------------------------------
  Task                    Status                  Notes
  ----------------------- ----------------------- -----------------------
  Create staging table    \[ \] Not Started / \[  \...
  definitions in SQL      \] In Progress / \[ \]  
  Express                 Done                    

  Draft data dictionary   \[ \] Not Started / \[  \...
  (table names, fields,   \] In Progress / \[ \]  
  keys)                   Done                    

  Build ERD (Entity       \[ \] Not Started / \[  \...
  Relationship Diagram)   \] In Progress / \[ \]  
                          Done                    

  Identify authoritative  \[ \] Not Started / \[  \...
  sources where overlap   \] In Progress / \[ \]  
  occurs                  Done                    
  -----------------------------------------------------------------------

### Validation

  -----------------------------------------------------------------------------
  Task                          Status                  Notes
  ----------------------------- ----------------------- -----------------------
  Compare record counts (AIX →  \[ \] Not Started / \[  \...
  stage → SQL Express)          \] In Progress / \[ \]  
                                Done                    

  Define thresholds for         \[ \] Not Started / \[  \...
  acceptable variance (±0.1%)   \] In Progress / \[ \]  
                                Done                    

  Spot-check key records for    \[ \] Not Started / \[  \...
  accuracy                      \] In Progress / \[ \]  
                                Done                    

  Document                      \[ \] Not Started / \[  \...
  differences/transformations   \] In Progress / \[ \]  
                                Done                    
  -----------------------------------------------------------------------------

## 📌 Deliverables

-   Probe Report: JSON + log + summary table

-   Extractor Samples: First 100 rows (CSV validated)

-   Schema Draft: SQL DDL script + data dictionary

-   Validation Report: Count comparison + variance notes

## 📌 Updates & Milestones

### 🔄 Repository Established (Sept 2025)

• Private GitHub repo created: aix-data-rescue-scripts\
• Includes tailored README.md, .gitignore, Runbook.md, and folder tree
for scripts, SQL, and docs.\
• Repo acts as primary sync mechanism between desk and travel laptops.\
• .gitignore ensures no secrets, VM images, or large binaries are
committed.\
• Aligned with charter deliverables: documented travel workflow,
PowerShell packaging scripts, and sync via OneDrive/Git.\
\
✅ This satisfies part of the "Documented workflow" and "Runbook"
deliverables and reduces risk of sync conflicts.
