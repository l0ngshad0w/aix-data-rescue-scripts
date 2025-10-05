param(
  [string]$SiteName   = "ChurchApp",
  [string]$PublishDir = "D:\ChurchApp\App\publish",
  [string]$Project    = "D:\ChurchApp\App\src\ChurchApp.Web\ChurchApp.Web.csproj",
  [switch]$AutoRepair,                 # set this to rewrite a clean web.config if needed
  [string]$SmokeUrl  = "http://localhost:8080/"
)

$ErrorActionPreference = "Stop"
Import-Module WebAdministration

function Ok($m){Write-Host "[OK] $m" -ForegroundColor Green}
function Info($m){Write-Host $m -ForegroundColor Cyan}
function Warn($m){Write-Warning $m}
function Fail($m){Write-Host "[FAIL] $m" -ForegroundColor Red}

# 1) Confirm site points at expected folder
$site = Get-Item "IIS:\Sites\$SiteName"
$pool = $site.applicationPool
$phys = $site.physicalPath
Info "Site: $SiteName  AppPool: $pool"
Info "IIS physicalPath: $phys"
if ($phys -ne $PublishDir) {
  Warn "Site physicalPath != PublishDir. Fix: Set-ItemProperty IIS:\Sites\$SiteName -name physicalPath -value $PublishDir"
}

# 2) Check AspNetCoreModuleV2 (installed by .NET Hosting Bundle)
$globalMod = Get-WebGlobalModule -Name AspNetCoreModuleV2 -ErrorAction SilentlyContinue
if ($globalMod) { Ok "AspNetCoreModuleV2 registered." } else {
  Warn "AspNetCoreModuleV2 MISSING. Install Hosting Bundle:"
  Write-Host '  winget install --id Microsoft.DotNet.HostingBundle.8 -e' -ForegroundColor Yellow
}

# 3) Validate web.config XML and <aspNetCore> shape
$web = Join-Path $PublishDir "web.config"
if (-not (Test-Path $web)) { Fail "web.config missing at $web" }

$xmlOk = $false
try { [xml]$x = Get-Content $web -Raw; $xmlOk = $true; Ok "web.config parses as XML." }
catch { Fail "web.config XML invalid: $($_.Exception.Message)" }

function Write-CanonicalWebConfig([string]$path, [string]$dllName) {
  $cfg = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
    </handlers>
    <aspNetCore processPath="dotnet"
                arguments=".\$dllName"
                stdoutLogEnabled="false"
                stdoutLogFile=".\logs\stdout"
                hostingModel="OutOfProcess">
      <environmentVariables>
        <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
      </environmentVariables>
    </aspNetCore>
  </system.webServer>
</configuration>
"@
  [IO.Directory]::CreateDirectory((Split-Path $path)) | Out-Null
  [IO.File]::WriteAllText($path, $cfg, (New-Object System.Text.UTF8Encoding($false)))
  New-Item -Type Directory -Force (Join-Path (Split-Path $path) "logs") | Out-Null
}

# Determine expected DLL (AssemblyName or csproj name)
function Get-DllName([string]$proj) {
  [xml]$p = Get-Content $proj -Raw
  $asm = ($p.Project.PropertyGroup | % { $_.AssemblyName } | ? { $_ }) | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($asm)) { $asm = [IO.Path]::GetFileNameWithoutExtension($proj) }
  return "$asm.dll"
}

$dll = Get-DllName $Project

$needsRewrite = $true
if ($xmlOk) {
  $ancm = $x.configuration.'system.webServer'.aspNetCore
  if ($ancm) {
    $ancmProcessPath  = $ancm.GetAttribute("processPath")
    $ancmArguments    = $ancm.GetAttribute("arguments")
    $ancmHostingModel = $ancm.GetAttribute("hostingModel")
    if ($ancmProcessPath -eq "dotnet" -and $ancmArguments -eq ".\$dll" -and $ancmHostingModel -eq "OutOfProcess") { 
      $needsRewrite = $false 
      Ok "<aspNetCore> looks correct."
    } else {
      Warn "<aspNetCore> present but attributes are off. Will repair if -AutoRepair."
    }
  } else {
    Warn "No <aspNetCore> element found. Will inject if -AutoRepair."
  }
}

if ($AutoRepair) {
  Info "Rewriting canonical web.config for $dll ..."
  Write-CanonicalWebConfig $web $dll
  # Force UTF-8 (no BOM)
  $raw = Get-Content $web -Raw
  [IO.File]::WriteAllText($web, $raw, (New-Object System.Text.UTF8Encoding($false)))
  Ok "web.config replaced and encoded as UTF-8 (no BOM)."
}

# 4) App pool sanity: No Managed Code
Set-ItemProperty "IIS:\AppPools\$pool" managedRuntimeVersion "" | Out-Null

# 5) Try reading effective config via appcmd (pinpoints parse errors + line #)
$appcmd = "$env:windir\system32\inetsrv\appcmd.exe"
if (Test-Path $appcmd) {
  Info "appcmd effective config check (handlers)..."
  try {
    & $appcmd list config "$SiteName/" -section:system.webServer/handlers | Out-Null
    Ok "appcmd read config successfully."
  } catch {
    Fail "appcmd failed reading config. $($_.Exception.Message)"
    Write-Host "If this shows a line/column, fix that spot in web.config." -ForegroundColor Yellow
  }
}

# 6) Recycle and smoke test
Restart-WebAppPool $pool
Start-WebSite $SiteName | Out-Null

try {
  if ($SmokeUrl) {
    Info "Smoke test -> $SmokeUrl"
    $r = Invoke-WebRequest -Uri $SmokeUrl -UseBasicParsing -TimeoutSec 10
    Ok "HTTP $($r.StatusCode) $($r.StatusDescription)"
  }
} catch { Warn "Smoke test failed: $($_.Exception.Message)" }

Info "Done."
