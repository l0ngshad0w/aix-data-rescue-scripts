param(
  [string]$OldRoot = "C:\ChurchApp",
  [string]$NewRoot = "D:\ChurchApp",
  [string]$SiteName = "ChurchApp",
  [int]$Port = 8080,
  [switch]$StopSiteDuringPublish,
  [switch]$SkipBackupZip,
  [string]$PublishScriptPath,
  [string]$ProjectPath                  # NEW: pass explicit csproj
)

$ErrorActionPreference = "Stop"

function Require-Admin {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) { throw "Run PowerShell as Administrator." }
}

function Ensure-Dir($p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force $p | Out-Null } }

function Zip-Backup($sourcePath) {
  $ts = Get-Date -Format "yyyyMMdd-HHmmss"
  $dest = Join-Path $env:SystemDrive ("Backup-ChurchApp-pre-move-$ts.zip")
  Write-Host "Creating backup zip: $dest" -ForegroundColor Cyan
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  if (Test-Path $dest) { Remove-Item $dest -Force }
  [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcePath, $dest)
  Write-Host "[OK] Backup zip created." -ForegroundColor Green
  return $dest
}

function Robocopy-Copy($src, $dst) {
  Ensure-Dir $dst
  $args = @("$src", "$dst", "/E", "/COPY:DAT", "/R:1", "/W:1", "/NFL", "/NDL", "/NP", "/XO")
  Write-Host "Robocopy $src -> $dst" -ForegroundColor Cyan
  $rc = Start-Process -FilePath robocopy.exe -ArgumentList $args -PassThru -Wait
  if ($rc.ExitCode -ge 8) { throw "Robocopy failed with ExitCode $($rc.ExitCode)." }
}

function Ensure-WebAdministration { Import-Module WebAdministration -ErrorAction Stop | Out-Null }

function Score-Csproj([string]$path) {
  $score = 0
  $name = [IO.Path]::GetFileName($path)
  $dir  = Split-Path $path -Parent
  if ($name -ieq "ChurchApp.Web.csproj") { $score += 100 }
  if ((Split-Path $dir -Leaf) -ieq "ChurchApp.Web") { $score += 80 }
  $xml = Get-Content $path -Raw
  if ($xml -match 'Microsoft\.NET\.Sdk\.Web') { $score += 60 }
  if ($xml -match '<TargetFramework>net8\.0</TargetFramework>') { $score += 10 }
  return $score
}

function Find-WebProjectCsproj([string[]]$roots) {
  $candidates = @()
  foreach ($r in $roots) {
    if (-not (Test-Path $r)) { continue }
    $candidates += Get-ChildItem -Path $r -Filter *.csproj -Recurse -ErrorAction SilentlyContinue
  }
  if (-not $candidates) { return $null }
  $scored = foreach ($c in $candidates) {
    [pscustomobject]@{ Path = $c.FullName; Score = (Score-Csproj $c.FullName) }
  }
  ($scored | Sort-Object Score -Descending | Select-Object -First 1).Path
}

function Get-AssemblyNameFromCsproj([string]$csprojPath) {
  [xml]$p = Get-Content $csprojPath -Raw
  $asm = ($p.Project.PropertyGroup | ForEach-Object { $_.AssemblyName } | Where-Object { $_ }) | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($asm)) { $asm = [IO.Path]::GetFileNameWithoutExtension($csprojPath) }
  return "$asm.dll"
}

function Fix-PublishProfiles([string]$projectDir, [string]$publishDir) {
  $ppDir = Join-Path $projectDir "Properties\PublishProfiles"
  Ensure-Dir $ppDir
  $profiles = Get-ChildItem -Path $ppDir -Filter *.pubxml -ErrorAction SilentlyContinue
  if (-not $profiles) {
    $pubxml = @"
<Project>
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Configuration>Release</Configuration>
    <PublishSingleFile>false</PublishSingleFile>
    <PublishTrimmed>false</PublishTrimmed>
    <SelfContained>false</SelfContained>
    <PublishProtocol>FileSystem</PublishProtocol>
    <DeleteExistingFiles>true</DeleteExistingFiles>
    <WebPublishMethod>FileSystem</WebPublishMethod>
    <PublishDir>$([IO.Path]::GetFullPath($publishDir))\</PublishDir>
  </PropertyGroup>
</Project>
"@
    $profilePath = Join-Path $ppDir "FolderProfile.pubxml"
    Set-Content $profilePath $pubxml -Encoding UTF8
    Write-Host "Created publish profile: $profilePath" -ForegroundColor Green
  } else {
    foreach ($f in $profiles) {
      [xml]$x = Get-Content $f.FullName -Raw
      if (-not $x.Project.PropertyGroup) { [void]$x.Project.AppendChild($x.CreateElement("PropertyGroup")) }
      $pg = $x.Project.PropertyGroup
      if (-not $pg.PublishDir) { [void]$pg.AppendChild($x.CreateElement("PublishDir")) }
      $pg.PublishDir = ([IO.Path]::GetFullPath($publishDir) + "\")
      $x.Save($f.FullName)
      Write-Host "Updated PublishDir in $($f.Name) -> $publishDir" -ForegroundColor Green
    }
  }
}

function Ensure-Modify-Acl($path, $appPoolName) {
  $identity = "IIS AppPool\$appPoolName"
  $acl = Get-Acl $path
  $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $identity, "Modify", "ContainerInherit, ObjectInherit", "None", "Allow"
  )
  $acl.SetAccessRule($rule)
  Set-Acl $path $acl
}

function Ensure-IISSite {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$SiteName,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$PhysicalPath,
    [int]$Port = 8080
  )

  Import-Module WebAdministration | Out-Null
  if (-not (Test-Path $PhysicalPath)) { New-Item -ItemType Directory -Force $PhysicalPath | Out-Null }

  $appPool = "$SiteName`Pool"
  if (-not (Test-Path "IIS:\AppPools\$appPool")) { New-Item "IIS:\AppPools\$appPool" | Out-Null }
  Set-ItemProperty "IIS:\AppPools\$appPool" managedRuntimeVersion ""
  Set-ItemProperty "IIS:\AppPools\$appPool" startMode "AlwaysRunning"
  Set-ItemProperty "IIS:\AppPools\$appPool" processModel.identityType "ApplicationPoolIdentity"

  $binding = "*:{0}:" -f $Port
  if (-not (Test-Path "IIS:\Sites\$SiteName")) {
    New-Item "IIS:\Sites\$SiteName" -bindings @{ protocol="http"; bindingInformation=$binding } -physicalPath $PhysicalPath | Out-Null
  } else {
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $PhysicalPath
    $haveBinding = (Get-WebBinding -Name $SiteName -Protocol "http" -ErrorAction SilentlyContinue |
      Where-Object { $_.bindingInformation -eq $binding })
    if (-not $haveBinding) { New-WebBinding -Name $SiteName -Protocol "http" -Port $Port -IPAddress "*" | Out-Null }
  }
  Set-ItemProperty "IIS:\Sites\$SiteName" applicationPool $appPool
  Set-ItemProperty "IIS:\Sites\$SiteName" -Name applicationDefaults.preloadEnabled -Value $true
}

# ----------------- MAIN -----------------
Require-Admin
Ensure-WebAdministration

# Compute and verify publish dir BEFORE calling Ensure-IISSite
$newPublishDir = Join-Path $NewRoot "App\publish"
if ([string]::IsNullOrWhiteSpace($newPublishDir)) { throw "Computed publish directory is empty." }
if (-not (Test-Path $newPublishDir)) { New-Item -ItemType Directory -Force $newPublishDir | Out-Null }

# Now safe to call:
Ensure-IISSite -SiteName $SiteName -PhysicalPath $newPublishDir -Port $Port

Write-Host "Old root: $OldRoot" -ForegroundColor Yellow
Write-Host "New root: $NewRoot" -ForegroundColor Yellow

# 0) Safety backup
if (-not $SkipBackupZip -and (Test-Path $OldRoot)) { [void](Zip-Backup $OldRoot) }

# 1) Copy to D:\ChurchApp (non-destructive)
Robocopy-Copy $OldRoot $NewRoot

# 2) Resolve the project
$resolvedCsproj = $null
if ($ProjectPath) {
  if (-not (Test-Path $ProjectPath)) { throw "ProjectPath not found: $ProjectPath" }
  $resolvedCsproj = $ProjectPath
} else {
  $resolvedCsproj = Find-WebProjectCsproj @(
    (Join-Path $NewRoot "."),          # D:\ChurchApp
    (Join-Path $OldRoot ".")           # C:\ChurchApp
  )
  if (-not $resolvedCsproj) {
    # Fallback scan of common dev locations (bounded)
    $fallbacks = @(
      "$env:USERPROFILE\source\repos",
      "$env:USERPROFILE\Documents",
      "C:\Projects","D:\Projects"
    ) | Where-Object { Test-Path $_ }
    $resolvedCsproj = Find-WebProjectCsproj $fallbacks
  }
}

if (-not $resolvedCsproj) {
  throw "Could not find a Blazor/ASP.NET Core .csproj automatically. Re-run with -ProjectPath <full path to ChurchApp.Web.csproj>."
}

$projectDir    = Split-Path $resolvedCsproj -Parent
$newPublishDir = Join-Path $NewRoot "App\publish"
Ensure-Dir $newPublishDir
$dllName       = Get-AssemblyNameFromCsproj $resolvedCsproj

Write-Host "Detected project: $resolvedCsproj" -ForegroundColor Green
Write-Host "Assembly/DLL:    $dllName" -ForegroundColor Green
Write-Host "Publish dir:     $newPublishDir" -ForegroundColor Green

# 3) Fix or create publish profiles to point to D:\ChurchApp\App\publish
Fix-PublishProfiles -projectDir $projectDir -publishDir $newPublishDir

# 4) Point IIS to D:\ChurchApp\App\publish and ensure ACLs
Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $newPublishDir
$appPool = (Get-Item "IIS:\Sites\$SiteName").applicationPool
Ensure-Modify-Acl $newPublishDir $appPool

# 5) Publish
if (-not $PublishScriptPath) {
  $PublishScriptPath = Join-Path $PSScriptRoot "publish-and-recycle.ps1"
  if (-not (Test-Path $PublishScriptPath)) {
    $alt = "D:\aix-data-rescue-scripts\scripts\powershell\publish-and-recycle.ps1"
    if (Test-Path $alt) { $PublishScriptPath = $alt }
  }
}

if (Test-Path $PublishScriptPath) {
  Write-Host "Using publish script: $PublishScriptPath" -ForegroundColor Cyan
  & $PublishScriptPath `
      -ProjectPath $resolvedCsproj `
      -PublishDir $newPublishDir `
      -SiteName $SiteName `
      -FixCsprojWebSdk `
      -FixPermissions `
      -StopSiteDuringPublish:$StopSiteDuringPublish `
      -SmokeTestUrl ("http://localhost:{0}/members" -f $Port)
} else {
  Write-Warning "publish-and-recycle.ps1 not found. Falling back to raw publish."
  if ($StopSiteDuringPublish) { Stop-WebSite $SiteName -ErrorAction SilentlyContinue }
  dotnet publish $resolvedCsproj -c Release /p:PublishDir="$newPublishDir\"
  Restart-WebAppPool $appPool
  Start-WebSite $SiteName | Out-Null
}

# 6) Smoke test
try {
  $url = "http://localhost:{0}/members" -f $Port
  Write-Host "Smoke test -> $url" -ForegroundColor Cyan
  $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
  Write-Host "[OK] HTTP $($r.StatusCode) $($r.StatusDescription)" -ForegroundColor Green
} catch {
  Write-Warning "Smoke test failed: $($_.Exception.Message)"
  Write-Warning "Check $newPublishDir\logs (if present) and Event Viewer > Windows Logs > Application"
}

Write-Host "DEBUG SiteName='$SiteName'  Port=$Port  PublishDir='$newPublishDir'" -ForegroundColor DarkCyan
Write-Host "Migration complete. IIS now points to: $newPublishDir" -ForegroundColor Green
Write-Host "Original left in place at: $OldRoot  (safe to archive/delete later)" -ForegroundColor Yellow
