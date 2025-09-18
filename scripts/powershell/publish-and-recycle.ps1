param(
  [string]$ProjectPath      = "D:\ChurchApp\App\src\ChurchApp.Web\ChurchApp.Web.csproj",
  [string]$PublishProfile   = "FolderProfile",
  [string]$PublishDir       = "D:\ChurchApp\App\publish",
  [string]$SiteName         = "ChurchApp",
  [switch]$CheckAspNetCoreModule,
  [switch]$EnableStdoutOnError,
  [switch]$SkipUtf8Fix,
  [switch]$FixPermissions,
  [switch]$FixCsprojWebSdk,         # upgrades Sdk to Microsoft.NET.Sdk.Web if needed
  [switch]$StopSiteDuringPublish,   # avoids file locks during publish
  [string]$SmokeTestUrl             # e.g. "http://localhost:8080/"
)

$ErrorActionPreference = "Stop"

function Require-Admin {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) { throw "Run PowerShell as Administrator." }
}

function Ensure-Module-WebAdministration {
  if (-not (Get-Module -ListAvailable WebAdministration)) {
    throw "WebAdministration module not found. Enable IIS Management Console + Scripts and Tools."
  }
  Import-Module WebAdministration -ErrorAction Stop | Out-Null
}

function Ensure-Dir($path) {
  if (-not (Test-Path $path)) { New-Item -ItemType Directory -Force $path | Out-Null }
}

function Force-WebConfigUtf8($webConfigPath) {
  $raw = Get-Content $webConfigPath -Raw
  [System.IO.File]::WriteAllText($webConfigPath, $raw, (New-Object System.Text.UTF8Encoding($false)))
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

function Check-AspNetCoreModule {
  $appcmd = "$env:windir\system32\inetsrv\appcmd.exe"
  if (-not (Test-Path $appcmd)) { Write-Warning "appcmd.exe not found. Skipping module check."; return }
  $out = & $appcmd list modules 2>$null | Select-String -Pattern "AspNetCoreModuleV2"
  if (-not $out) {
    Write-Warning "AspNetCoreModuleV2 not registered. Install the .NET Hosting Bundle for your SDK, then run: iisreset"
  } else {
    Write-Host "AspNetCoreModuleV2 is registered." -ForegroundColor Green
  }
}

function Get-AssemblyName($ProjectPath) {
  # Prefer <AssemblyName>. Otherwise base name of csproj.
  [xml]$p = Get-Content $ProjectPath -Raw
  $asm = ($p.Project.PropertyGroup | ForEach-Object { $_.AssemblyName } | Where-Object { $_ }) | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($asm)) {
    $asm = [IO.Path]::GetFileNameWithoutExtension($ProjectPath)
  }
  return "$asm.dll"
}

function Ensure-WebSdk($ProjectPath, [switch]$Fix) {
  $csproj = Get-Content $ProjectPath -Raw
  if ($csproj -notmatch 'Microsoft\.NET\.Sdk\.Web') {
    if ($csproj -match 'Microsoft\.NET\.Sdk"') {
      if ($Fix) {
        $patched = $csproj -replace 'Microsoft\.NET\.Sdk"', 'Microsoft.NET.Sdk.Web"'
        Set-Content $ProjectPath $patched -Encoding UTF8
        Write-Host "Updated csproj Sdk -> Microsoft.NET.Sdk.Web" -ForegroundColor Yellow
      } else {
        Write-Warning "Project Sdk is not Microsoft.NET.Sdk.Web. Re-run with -FixCsprojWebSdk to patch before publish."
      }
    } else {
      Write-Warning "Could not detect Project Sdk in csproj; ensure it is a Web SDK."
    }
  }
}

function Write-CanonicalWebConfig($webConfigPath, $dllName) {
@"
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
"@ | Set-Content -Path $webConfigPath -Encoding UTF8
}

function Ensure-AspNetCoreWebConfig($PublishDir, $dllName) {
  $webConfig = Join-Path $PublishDir "web.config"
  $needsRewrite = $true
  if (Test-Path $webConfig) {
    try {
      [xml]$xml = Get-Content $webConfig -Raw
      $ancm = $xml.configuration.'system.webServer'.aspNetCore
      if ($ancm) {
        $ancmProcessPath  = $ancm.GetAttribute("processPath")
        $ancmArguments    = $ancm.GetAttribute("arguments")
        $ancmHostingModel = $ancm.GetAttribute("hostingModel")
        if (($ancmProcessPath -eq "dotnet") -and ($ancmArguments -eq ".\$dllName") -and ($ancmHostingModel -eq "OutOfProcess")) {
          $needsRewrite = $false
        }
      }
    } catch { $needsRewrite = $true }
  }
  if ($needsRewrite) {
    Write-Host "Repairing/creating canonical web.config for ASP.NET Core..." -ForegroundColor Yellow
    Ensure-Dir (Join-Path $PublishDir "logs")
    Write-CanonicalWebConfig $webConfig $dllName
  }
  return (Join-Path $PublishDir "web.config")
}

function Enable-OneShot-Stdout($webConfigPath) {
  [xml]$x = Get-Content $webConfigPath -Raw
  $ancm = $x.configuration.'system.webServer'.aspNetCore
  if (-not $ancm) { Write-Warning "No <aspNetCore> element found. Skipping stdout toggle."; return }
  $ancm.SetAttribute("stdoutLogEnabled","true")
  $ancm.SetAttribute("stdoutLogFile", (Join-Path ".\logs" ("stdout-" + (Get-Date -Format yyyyMMdd-HHmmss))))
  $x.Save($webConfigPath)
  Write-Host "ANCM stdout logging ENABLED for next start." -ForegroundColor Yellow
}

try {
  Require-Admin
  Ensure-Module-WebAdministration
  if ($CheckAspNetCoreModule) { Check-AspNetCoreModule }

  if ($FixCsprojWebSdk) { Ensure-WebSdk $ProjectPath -Fix }
  else { Ensure-WebSdk $ProjectPath }

  $siteItem = Get-Item "IIS:\Sites\$SiteName" -ErrorAction Stop
  $appPool  = $siteItem.applicationPool
  if (-not $appPool) { throw "Site '$SiteName' has no applicationPool set." }

  $dllName = Get-AssemblyName $ProjectPath

  if ($StopSiteDuringPublish) {
    Write-Host "Stopping site '$SiteName' during publish..." -ForegroundColor Cyan
    Stop-WebSite $SiteName -ErrorAction SilentlyContinue
  }

  Write-Host "Publishing with profile '$PublishProfile'..." -ForegroundColor Cyan
  Ensure-Dir $PublishDir
  dotnet publish $ProjectPath /p:PublishProfile=$PublishProfile -c Release

  $webConfig = Ensure-AspNetCoreWebConfig $PublishDir $dllName

  if (-not $SkipUtf8Fix) {
    Write-Host "Forcing UTF-8 (no BOM) on web.config..." -ForegroundColor Cyan
    Force-WebConfigUtf8 $webConfig
  }

  if ($FixPermissions) {
    Write-Host "Ensuring Modify ACL for IIS AppPool\$appPool on $PublishDir ..." -ForegroundColor Cyan
    Ensure-Modify-Acl $PublishDir $appPool
  }

  if ($EnableStdoutOnError) {
    Enable-OneShot-Stdout $webConfig
  }

  Write-Host "Recycling app pool '$appPool'..." -ForegroundColor Cyan
  Restart-WebAppPool $appPool
  Start-WebSite $SiteName | Out-Null

  if ($SmokeTestUrl) {
    try {
      Write-Host "Smoke test -> $SmokeTestUrl" -ForegroundColor Cyan
      $resp = Invoke-WebRequest -Uri $SmokeTestUrl -UseBasicParsing -TimeoutSec 10
      Write-Host "HTTP $($resp.StatusCode) $($resp.StatusDescription)" -ForegroundColor Green
    } catch {
      Write-Warning "Smoke test failed: $($_.Exception.Message)"
      Write-Warning "If stdout was enabled, check: $PublishDir\logs"
    }
  }

  Write-Host "Done.  Site: $SiteName  AppPool: $appPool  Path: $PublishDir" -ForegroundColor Green
}
catch {
  Write-Error $_.Exception.Message
  exit 1
}
