# Database Schema

## Tables

### membr (Members)
- **Source:** `membr__138.unl`
- **Size:** 175 MB (~millions of records)
- **Purpose:** Member/ordination records
- **Fields:** [To be filled in from standard.sql]

### ctxrf (Course Cross-Reference)
- **Source:** `ctxrf__101.unl`
- **Size:** 19 MB
- **Purpose:** Join table linking members to courses
- **Fields:** [To be filled in]

### corti (Courses/Certificates)
- **Source:** `corti__102.unl`
- **Size:** 9 KB
- **Purpose:** Available courses/certifications
- **Fields:** [To be filled in]

## Known Issues
- Some data quality issues from Informix extraction (details TBD)
- Validation needed on field mappings

## Data Load Status
- [X] Extracted from AIX
- [X] Validated .unl files
- [ ] Loaded into SQL Server (verify row counts)
- [ ] Data quality checks