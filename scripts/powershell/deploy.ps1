# ===== ChurchApp - Mini PC Web Setup (idempotent, non-destructive) =====
# Deploys to D:\ (change only the variables below if you must).
# - Creates/updates App Pool + Site
# - Adds HTTP :8080, HTTPS :444 with self-signed cert (does NOT touch :443)
# - Enables WebSockets
# - Sets ACLs
# - Adds Windows Firewall rules for 8080/444
# - Auto "parks" the site with index.html until EXE/DLL is present; then writes a correct web.config

# ---------------- Vars ----------------
$RootPath     = 'D:\ChurchApp\App'
$PublishPath  = Join-Path $RootPath 'publish'
$SiteName     = 'ChurchApp'
$AppPoolName  = 'ChurchApp'
$HttpPort     = 8080
$HttpsPort    = 444
$HttpBinding  = '*:{0}:' -f $HttpPort    # <-- FIX: avoid "$var:" parser bug
$HttpsBinding = '*:{0}:' -f $HttpsPort   # <-- FIX
$CertFriendly = 'ChurchApp Dev 444 (localhost)'
$AppIdGuid    = '{A1B2C3D4-E5F6-47D8-A9B0-123456789444}'   # stable for netsh idempotency
$LogsPath     = Join-Path $PublishPath 'logs'

Write-Host "==> Setting up $SiteName on IIS (root=$RootPath, publish=$PublishPath) ..." -ForegroundColor Cyan

# ---------------- Safety ----------------
If (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Please run in an elevated PowerShell session."
}

# Ensure folders
New-Item -ItemType Directory -Path $PublishPath -Force | Out-Null
New-Item -ItemType Directory -Path $LogsPath    -Force | Out-Null

# ---------------- IIS Features + WebSockets ----------------
function Enable-FeatureSafe {
  param([string]$ClientFeature,[string]$ServerFeature)
  try {
    $f = Get-WindowsOptionalFeature -Online -FeatureName $ClientFeature -ErrorAction Stop
    if ($f.State -ne 'Enabled') {
      Write-Host "Enabling Windows feature: $ClientFeature ..." -ForegroundColor Yellow
      Enable-WindowsOptionalFeature -Online -FeatureName $ClientFeature -All | Out-Null
    } else { Write-Host "$ClientFeature already enabled." -ForegroundColor Green }
  } catch {
    try {
      $wf = Get-WindowsFeature $ServerFeature -ErrorAction Stop
      if ($wf.InstallState -ne 'Installed') {
        Write-Host "Installing Windows feature (Server): $ServerFeature ..." -ForegroundColor Yellow
        Install-WindowsFeature $ServerFeature | Out-Null
      } else { Write-Host "$ServerFeature already installed." -ForegroundColor Green }
    } catch { Write-Warning "Could not verify/enable $ClientFeature/$ServerFeature. Ensure IIS is installed." }
  }
}

# Core web server + management + WebSockets
Enable-FeatureSafe -ClientFeature 'IIS-WebServer'         -ServerFeature 'Web-Server'
Enable-FeatureSafe -ClientFeature 'IIS-ManagementConsole' -ServerFeature 'Web-Mgmt-Console'
Enable-FeatureSafe -ClientFeature 'IIS-WebSockets'         -ServerFeature 'Web-WebSockets'

Import-Module WebAdministration -ErrorAction Stop

# ---------------- App Pool ----------------
$poolPath = "IIS:\AppPools\$AppPoolName"
if (-not (Test-Path $poolPath)) {
  Write-Host "Creating App Pool '$AppPoolName'..." -ForegroundColor Yellow
  New-WebAppPool -Name $AppPoolName | Out-Null
} else {
  Write-Host "App Pool '$AppPoolName' exists.  Ensuring settings..." -ForegroundColor Green
}
Set-ItemProperty $poolPath -Name managedRuntimeVersion -Value ""           # No Managed Code
Set-ItemProperty $poolPath -Name startMode -Value "AlwaysRunning"
Set-ItemProperty $poolPath -Name autoStart -Value $true
Set-ItemProperty $poolPath -Name enable32BitAppOnWin64 -Value $false -ErrorAction SilentlyContinue | Out-Null  # x64

# ---------------- Site ----------------
$sitePath = "IIS:\Sites\$SiteName"
if (-not (Test-Path $sitePath)) {
  Write-Host "Creating IIS Site '$SiteName'..." -ForegroundColor Yellow
  New-Website -Name $SiteName -PhysicalPath $PublishPath -ApplicationPool $AppPoolName -Port $HttpPort -IPAddress '*' | Out-Null
} else {
  Write-Host "Site '$SiteName' exists.  Ensuring physical path and app pool..." -ForegroundColor Green
  Set-ItemProperty $sitePath -Name physicalPath -Value $PublishPath
}
# Ensure root app uses our pool
$appcmd = Join-Path $env:SystemRoot 'System32\inetsrv\appcmd.exe'
& $appcmd set app "$SiteName/" /applicationPool:"$AppPoolName" | Out-Null

# Enable WebSockets at site level
Set-WebConfigurationProperty -PSPath $sitePath -Filter "system.webServer/webSocket" -Name enabled -Value True -ErrorAction SilentlyContinue

# ---------------- Bindings ----------------
# HTTP :8080
$hasHttp = Get-WebBinding -Name $SiteName -ErrorAction SilentlyContinue | Where-Object { $_.protocol -eq 'http' -and $_.bindingInformation -eq $HttpBinding }
if (-not $hasHttp) {
  Write-Host "Adding HTTP binding $HttpBinding ..." -ForegroundColor Yellow
  New-WebBinding -Name $SiteName -Protocol http -Port $HttpPort -IPAddress '*' | Out-Null
} else {
  Write-Host "HTTP binding $HttpBinding already present." -ForegroundColor Green
}

# HTTPS :444
$hasHttps = Get-WebBinding -Name $SiteName -ErrorAction SilentlyContinue | Where-Object { $_.protocol -eq 'https' -and $_.bindingInformation -eq $HttpsBinding }
if (-not $hasHttps) {
  Write-Host "Adding HTTPS binding $HttpsBinding ..." -ForegroundColor Yellow
  New-WebBinding -Name $SiteName -Protocol https -Port $HttpsPort -IPAddress '*' | Out-Null
} else {
  Write-Host "HTTPS binding $HttpsBinding already present." -ForegroundColor Green
}

# ---------------- Cert + HTTP.SYS mapping (only :444) ----------------
$cert = Get-ChildItem Cert:\LocalMachine\My |
        Where-Object { $_.FriendlyName -eq $CertFriendly } |
        Select-Object -First 1   # <-- FIX: ensure single cert
if (-not $cert) {
  Write-Host "Creating self-signed certificate: $CertFriendly (CN=localhost) ..." -ForegroundColor Yellow
  $cert = New-SelfSignedCertificate -DnsName 'localhost' -FriendlyName $CertFriendly `
          -CertStoreLocation 'Cert:\LocalMachine\My' -KeyExportPolicy Exportable -KeyLength 2048 `
          -NotAfter (Get-Date).AddYears(2)
} else {
  Write-Host "Using existing certificate: $($cert.Thumbprint)" -ForegroundColor Green
}
$thumb = $cert.Thumbprint

# Attach cert to IIS binding
try {
  $httpsBindingObj = Get-WebBinding -Name $SiteName -Protocol https | Where-Object { $_.bindingInformation -eq $HttpsBinding }
  if ($httpsBindingObj) {
    Push-Location IIS:\ ; ($httpsBindingObj).AddSslCertificate($thumb, 'My') ; Pop-Location
    Write-Host "IIS https binding now references cert thumbprint: $thumb" -ForegroundColor Green
  }
} catch { Write-Warning "Could not attach cert to IIS binding via API.  You can set it in IIS Manager if needed." }

# HTTP.SYS sslcert mapping for 0.0.0.0:444 (skip if exists)
$ipport = "0.0.0.0:{0}" -f $HttpsPort
$existingSsl = (netsh http show sslcert ipport=$ipport) 2>$null
if ($LASTEXITCODE -ne 0 -or -not ($existingSsl -join "`n") -match 'Certificate Hash') {
  Write-Host "Registering SSL cert mapping at ${ipport} ..." -ForegroundColor Yellow
  & netsh http add sslcert ipport=$ipport certhash=$thumb appid=$AppIdGuid certstorename=MY | Out-Null
} else {
  Write-Host "SSL cert mapping already exists for ${ipport}.  Leaving as-is." -ForegroundColor Green
}

# ---------------- ACLs ----------------
icacls $PublishPath /grant 'IIS_IUSRS:(OI)(CI)(RX)' /T | Out-Null
icacls $LogsPath    /grant 'IIS_IUSRS:(OI)(CI)(RX)' /T | Out-Null
icacls $LogsPath    /grant ("IIS AppPool\{0}:(OI)(CI)(M)" -f $AppPoolName) /T | Out-Null

# ---------------- Default Document + Park/Unpark ----------------
# Unlock sections commonly locked by default (safe for dev boxes)
& $appcmd unlock config -section:system.webServer/handlers    | Out-Null
& $appcmd unlock config -section:system.webServer/modules     | Out-Null
& $appcmd unlock config -section:system.webServer/aspNetCore  | Out-Null
& $appcmd unlock config -section:system.webServer/webSocket   | Out-Null

# Ensure Default Document includes index.html
& $appcmd set config "$SiteName/" /section:defaultDocument /enabled:true | Out-Null
try {
  $hasIndex = (& $appcmd list config "$SiteName/" -section:defaultDocument) -match 'index.html'
  if (-not $hasIndex) { & $appcmd set config "$SiteName/" /section:defaultDocument /+files.[value='index.html'] | Out-Null }
} catch {}

# Detect an app payload (EXE or DLL).  If present → write web.config.  If not → park the site.
$exe = Get-ChildItem -Path $PublishPath -File -Filter *.exe -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'app_offline.exe' } | Select-Object -First 1
$dll = Get-ChildItem -Path $PublishPath -File -Filter *.dll -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -notin @('aspnetcorev2_inprocess.dll','aspnetcorev2_outofprocess.dll') } |
       Sort-Object Length -Descending | Select-Object -First 1
$webConfigPath = Join-Path $PublishPath 'web.config'
$indexPath     = Join-Path $PublishPath 'index.html'

if ($exe -or $dll) {
  # Generate a correct web.config (only if missing OR parked)
  $hostingModel = $null; $processPath = $null; $arguments = $null
  if ($exe) {
    $hostingModel = 'inprocess'
    $processPath  = ".\{0}" -f $exe.Name
    $arguments    = ''
  } else {
    $hostingModel = 'outofprocess'
    $processPath  = 'dotnet'
    $arguments    = ".\{0}" -f $dll.Name
  }

  if ((-not (Test-Path $webConfigPath)) -or (Get-Content $webConfigPath -Raw 2>$null) -match 'ChurchApp is parked') {
    if (Test-Path $webConfigPath) { Copy-Item $webConfigPath "$webConfigPath.parked.bak" -Force }
@"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
    </handlers>
    <webSocket enabled="true" />
    <aspNetCore processPath="$processPath" arguments="$arguments" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="$hostingModel" />
  </system.webServer>
</configuration>
"@ | Out-File -FilePath $webConfigPath -Encoding UTF8 -Force
    Write-Host "web.config created for application payload ($hostingModel → $processPath $arguments)" -ForegroundColor Green
  } else {
    Write-Host "web.config already present; leaving untouched." -ForegroundColor Green
  }
} else {
  # Park the site: remove/backup web.config and ensure index.html exists
  if (Test-Path $webConfigPath) {
    $bak = "$webConfigPath.appcore.bak"
    if (-not (Test-Path $bak)) { Copy-Item $webConfigPath $bak -Force }
    Remove-Item $webConfigPath -Force
    Write-Host "No app payload detected.  Backed up and removed web.config to serve static content." -ForegroundColor Yellow
  }
  if (-not (Test-Path $indexPath)) {
@"
<!doctype html>
<html><head><meta charset="utf-8"><title>ChurchApp (Parked)</title></head>
<body style="font-family:system-ui;margin:2rem;">
  <h1>ChurchApp is parked</h1>
  <p>IIS is running. ASP.NET Core will be enabled automatically when you publish a Blazor app to this folder and rerun the setup script.</p>
  <ul>
    <li>HTTP: <a href="http://localhost:${HttpPort}">http://localhost:${HttpPort}</a></li>
    <li>HTTPS: <a href="https://localhost:${HttpsPort}">https://localhost:${HttpsPort}</a></li>
  </ul>
</body>
</html>
"@ | Out-File -FilePath $indexPath -Encoding UTF8 -Force
    Write-Host "Created parked index.html." -ForegroundColor Green
  } else {
    Write-Host "Site is parked (index.html present)." -ForegroundColor Green
  }
}

# ---------------- Windows Firewall (skip if rules exist) ----------------
$fwHttp = Get-NetFirewallRule -DisplayName 'ChurchApp HTTP 8080' -ErrorAction SilentlyContinue
if (-not $fwHttp) {
  New-NetFirewallRule -DisplayName 'ChurchApp HTTP 8080'  -Direction Inbound -Action Allow -Protocol TCP -LocalPort $HttpPort | Out-Null
  Write-Host "Firewall: opened TCP ${HttpPort} (inbound)." -ForegroundColor Green
} else { Write-Host "Firewall rule for ${HttpPort} already exists." -ForegroundColor Green }

$fwHttps = Get-NetFirewallRule -DisplayName 'ChurchApp HTTPS 444' -ErrorAction SilentlyContinue
if (-not $fwHttps) {
  New-NetFirewallRule -DisplayName 'ChurchApp HTTPS 444' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $HttpsPort | Out-Null
  Write-Host "Firewall: opened TCP ${HttpsPort} (inbound)." -ForegroundColor Green
} else { Write-Host "Firewall rule for ${HttpsPort} already exists." -ForegroundColor Green }

# ---------------- Start + Status ----------------
iisreset | Out-Null
Start-Website -Name $SiteName -ErrorAction SilentlyContinue | Out-Null

Write-Host ""
Write-Host "===== STATUS =====" -ForegroundColor Cyan
Write-Host "Root:        $RootPath"
Write-Host "Publish:     $PublishPath"
Write-Host "Logs:        $LogsPath"
Write-Host "`nApp Pool:" -ForegroundColor Cyan
(Get-ItemProperty $poolPath | Select-Object name, state, startMode, managedRuntimeVersion, enable32BitAppOnWin64) | Format-Table | Out-String | Write-Host
Write-Host "`nSite:" -ForegroundColor Cyan
(Get-Website -Name $SiteName | Select-Object name, state, physicalPath, applicationPool) | Format-Table | Out-String | Write-Host
Write-Host "`nBindings:" -ForegroundColor Cyan
(Get-WebBinding -Name $SiteName | Select-Object protocol,bindingInformation) | Format-Table | Out-String | Write-Host
Write-Host "`nSSL (HTTP.SYS) for ${ipport}:" -ForegroundColor Cyan
netsh http show sslcert ipport=$ipport
Write-Host "`nTest URLs:" -ForegroundColor Cyan
Write-Host "  http://localhost:${HttpPort}"
Write-Host "  https://localhost:${HttpsPort}"
Write-Host "`nDone."
# ===== End =====
