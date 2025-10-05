param(
    [string]$SqlInstance = 'DESKTOP-B4FMSBS\MSSQL20',
    [string]$Database = 'ChurchDB',
    [string]$Root = 'D:\Projects\aix-data-rescue-scripts\scripts\sql',
    [ValidateSet('Windows','Sql')] [string]$Auth = 'Windows',
    [string]$SqlUser,
    [string]$SqlPassword,
    [switch]$TrustServerCertificate,
    [switch]$DryRun,
    [switch]$IncludeSeed   # NEW: include 90-seed
)

$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir = 'D:\ChurchApp\Logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir "ddl-run-$timestamp.log"

function Write-Log { param([string]$m) $m | Tee-Object -FilePath $log -Append }

# Detect tools; try to import SqlServer if Invoke-Sqlcmd missing
$SqlCmdPath = (Get-Command sqlcmd -ErrorAction SilentlyContinue)?.Source
$HasInvokeSqlcmd = $false
if (-not $SqlCmdPath) {
    if (-not (Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue)) {
        try { Import-Module SqlServer -ErrorAction Stop } catch {}
    }
    $HasInvokeSqlcmd = [bool](Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue)
} else {
    $HasInvokeSqlcmd = [bool](Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue)
}

function Run-WithSqlCmd {
    param([string]$Db, [string]$Query, [string]$InputFile)
    if ($Query -and $InputFile) { throw "Cannot specify both Query and InputFile." }
    $common = @('-S', $SqlInstance, '-b', '-r', '1') # quit on error; route errors
    if ($TrustServerCertificate) { $common += '-C' }
    if ($Auth -eq 'Windows') { $common += '-E' } else { $common += @('-U', $SqlUser, '-P', $SqlPassword) }
    if ($Db) { $common += @('-d', $Db) }
    # Force UTF-8 for input files
    if ($InputFile) { & $SqlCmdPath @common '-f' '65001' '-i' $InputFile }
    if ($Query)    { & $SqlCmdPath @common '-Q' $Query }
}

function Run-WithInvokeSqlcmd {
    param([string]$Db, [string]$Query, [string]$InputFile)
    if ($Query -and $InputFile) { throw "Cannot specify both Query and InputFile." }
    $invParams = @{ ServerInstance = $SqlInstance; ErrorAction = 'Stop' }
    if ($Db) { $invParams['Database'] = $Db }
    if ($Auth -eq 'Sql') { $invParams['Username'] = $SqlUser; $invParams['Password'] = $SqlPassword }
    if ($Query)    { Invoke-Sqlcmd @invParams -Query $Query | Out-Null }
    if ($InputFile){ Invoke-Sqlcmd @invParams -InputFile $InputFile | Out-Null }
}

function Run-TSql {
    param([string]$Db, [string]$Query, [string]$InputFile)
    if ($DryRun) {
        if ($Query)    { Write-Log "[DRYRUN] Skipped query on [$Db]: $Query" }
        if ($InputFile){ Write-Log "[DRYRUN] Skipped file on [$Db]: $InputFile" }
        return
    }
    if ($SqlCmdPath) { Run-WithSqlCmd -Db $Db -Query $Query -InputFile $InputFile }
    elseif ($HasInvokeSqlcmd) { Run-WithInvokeSqlcmd -Db $Db -Query $Query -InputFile $InputFile }
    else { throw "Neither 'sqlcmd' nor 'Invoke-Sqlcmd' is available. Install SQL Server tools or the SqlServer PowerShell module." }
}

Write-Log "=== DDL RUN START ($timestamp) ==="
Write-Log "[INFO] Instance: $SqlInstance  Database: $Database  Root: $Root  Auth: $Auth  DryRun: $DryRun  IncludeSeed: $IncludeSeed"

# Ensure database exists
try {
    Run-TSql -Db 'master' -Query "IF DB_ID(N'$Database') IS NULL CREATE DATABASE [$Database];"
    Run-TSql -Db 'master' -Query "ALTER DATABASE [$Database] SET RECOVERY SIMPLE WITH NO_WAIT;"
    Write-Log "[INFO] Database [$Database] ensured."
} catch {
    Write-Log "[ERROR] Failed to ensure database: $($_.Exception.Message)"
    throw
}

if (-not (Test-Path $Root)) { throw "Root folder not found: $Root" }

# Deterministic folder order; skip 90-seed unless -IncludeSeed
$planned = @(
    '00-database','10-schemas','20-tables','30-constraints','40-indexes',
    '50-views','60-functions','70-procs','80-triggers'
) + ($(if ($IncludeSeed) { @('90-seed') } else { @() }))

# Gather files explicitly by the above order; include any root-level *.sql first
$files = @()
$files += Get-ChildItem -Path $Root -File -Filter '*.sql' | Sort-Object Name
foreach ($p in $planned) {
    $dir = Join-Path $Root $p
    if (Test-Path $dir) {
        $files += Get-ChildItem -Path $dir -File -Filter '*.sql' | Sort-Object Name
    }
}

if (-not $files) { Write-Log "[INFO] No .sql files found under $Root."; exit 0 }

Write-Log "[INFO] Planned execution order:"
$files | ForEach-Object { Write-Log "  $($_.FullName)" }

# Execute with special-case for 00-database/* on master
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
foreach ($f in $files) {
    $targetDb = if ($f.FullName -imatch "\\00-database\\") { 'master' } else { $Database }
    Write-Log "[RUN] Executing on [$targetDb]: $($f.FullName)"
    try {
        Run-TSql -Db $targetDb -InputFile $f.FullName
        Write-Log "[OK] $($f.Name)"
    } catch {
        Write-Log "[ERROR] in $($f.Name): $($_.Exception.Message)"
        throw
    }
}
$stopwatch.Stop()
Write-Log "=== DDL RUN COMPLETE in $([int]$stopwatch.Elapsed.TotalSeconds)s ==="

# Sanity check
try {
    Run-TSql -Db $Database -Query "SELECT COUNT(*) AS TableCount FROM sys.tables;"
    Write-Log "[INFO] Sanity check query executed."
} catch {
    Write-Log "[ERROR] Sanity check failed: $($_.Exception.Message)"
}
