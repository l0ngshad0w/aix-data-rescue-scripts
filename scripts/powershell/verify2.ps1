<#  verify.ps1  — ChurchApp IIS health check (read-only)

What it checks:
  • Site + pool state, path, pool settings (AlwaysRunning, No Managed Code, x64)
  • Bindings on :8080 (http) and :444 (https)
  • Cert attached to IIS binding and HTTP.SYS sslcert mapping for 0.0.0.0:444
  • WebSockets feature + site-level <webSocket enabled="true" />
  • Default Document (index.html) present in the list
  • ACLs for publish + logs folders
  • ANCM presence (aspnetcorev2.dll/module)
  • Detects “parked” vs “app payload” (EXE/DLL) and shows web.config mode
  • HTTP/HTTPS probes (tolerates the self-signed cert in this PS session)

Usage:
  Run in an **elevated** Windows PowerShell 5.1 prompt:
    .\verify.ps1
#>

param(
  [string]$SiteName    = 'ChurchApp',
  [string]$AppPoolName = 'ChurchApp',
  [string]$RootPath    = 'D:\ChurchApp\App',
  [int]   $HttpPort    = 8080,
  [int]   $HttpsPort   = 444
)

$ErrorActionPreference = 'Stop'
$PublishPath = Join-Path $RootPath 'publish'
$LogsPath    = Join-Path $PublishPath 'logs'
$HttpUrl     = "http://localhost:$HttpPort/"
$HttpsUrl    = "https://localhost:$HttpsPort/"
$appcmd      = Join-Path $env:SystemRoot 'System32\inetsrv\appcmd.exe'

function Say($msg, $color='Gray') { Write-Host $msg -ForegroundColor $color }
function Pass($msg) { Say ("[PASS] " + $msg) 'Green' }
function Warn($msg) { Say ("[WARN] " + $msg) 'Yellow' }
function Fail($msg) { Say ("[FAIL] " + $msg) 'Red' }

Say "== ChurchApp Verify ==" 'Cyan'
Import-Module WebAdministration -ErrorAction Stop

# --- Site & Pool ---
try {
  $site = Get-Website -Name $SiteName -ErrorAction Stop
  Pass "Site '$SiteName' exists (State=$($site.state), Path=$($site.physicalPath))"
} catch { Fail "Site '$SiteName' not found"; return }

try {
  $poolPath = "IIS:\AppPools\$AppPoolName"
  $pool = Get-ItemProperty $poolPath -ErrorAction Stop
  $okMode  = ($pool.startMode -eq 'AlwaysRunning')
  $okClr   = ([string]::IsNullOrEmpty($pool.managedRuntimeVersion))
  $okBit   = (-not $pool.enable32BitAppOnWin64)
  if ($okMode -and $okClr -and $okBit) {
    Pass "App Pool '$AppPoolName' (AlwaysRunning, NoManagedCode, x64)"
  } else {
    Warn "App Pool settings: startMode=$($pool.startMode), managedRuntimeVersion=$($pool.managedRuntimeVersion), 32bit=$($pool.enable32BitAppOnWin64)"
  }
} catch { Fail "App Pool '$AppPoolName' not found"; }

# --- Bindings ---
$bindings = Get-WebBinding -Name $SiteName -ErrorAction SilentlyContinue
if ($bindings | Where-Object { $_.protocol -eq 'http' -and $_.bindingInformation -eq ("*:{0}:" -f $HttpPort) }) {
  Pass "HTTP binding *:$HttpPort: present"
} else { Fail "HTTP binding *:$HttpPort: missing" }

if ($bindings | Where-Object { $_.protocol -eq 'https' -and $_.bindingInformation -eq ("*:{0}:" -f $HttpsPort) }) {
  Pass "HTTPS binding *:$HttpsPort: present"
} else { Fail "HTTPS binding *:$HttpsPort: missing" }

# --- Certs: IIS binding + HTTP.SYS ---
try {
  $httpsBinding = $bindings | Where-Object { $_.protocol -eq 'https' -and $_.bindingInformation -eq ("*:{0}:" -f $HttpsPort) }
  if ($httpsBinding) {
    Push-Location IIS:\ ; $certRef = $httpsBinding.certificateHash ; Pop-Location
    if ($certRef) { Pass "IIS https binding has a cert (thumbprint: $certRef)" } else { Warn "IIS https binding has no cert attached" }
  }
} catch { Warn "Could not read IIS cert from binding" }

$ipport = "0.0.0.0:{0}" -f $HttpsPort
$ssl = (netsh http show sslcert ipport=$ipport) 2>$null
if ($LASTEXITCODE -eq 0 -and ($ssl -join "`n") -match 'Certificate Hash') {
  Pass "HTTP.SYS sslcert mapping exists for $ipport"
} else {
  Warn "No HTTP.SYS sslcert mapping for $ipport"
}

# --- Features: WebSockets + default document ---
# WebSockets feature
$wsOk = $false
try {
  $ws = Get-WindowsOptionalFeature -Online -FeatureName IIS-WebSockets -ErrorAction Stop
  $wsOk = ($ws.State -eq 'Enabled')
} catch {
  try { $wsOk = ((Get-WindowsFeature Web-WebSockets).InstallState -eq 'Installed') } catch {}
}
if ($wsOk) { Pass "WebSockets feature enabled" } else { Warn "WebSockets feature not enabled" }

# Site-level <webSocket enabled="true" />
try {
  $wsSite = Get-WebConfigurationProperty -PSPath "IIS:\Sites\$SiteName" -Filter "system.webServer/webSocket" -Name enabled -ErrorAction Stop
  if ($wsSite.Value -eq $true) { Pass "Site webSocket enabled=true" } else { Warn "Site webSocket not enabled" }
} catch { Warn "Could not read site webSocket setting" }

# Default Document contains index.html
try {
  $dd = & $appcmd list config "$SiteName/" -section:defaultDocument
  if ($dd -match 'index.html') { Pass "Default Document includes index.html" } else { Warn "index.html not listed in Default Document" }
} catch { Warn "Could not query Default Document via appcmd" }

# --- Files / ACLs ---
if (Test-Path $PublishPath) { Pass "Publish path exists: $PublishPath" } else { Fail "Publish path missing: $PublishPath" }
if (Test-Path $LogsPath)    { Pass "Logs path exists:    $LogsPath"    } else { Warn "Logs path missing: $LogsPath" }

# Check typical ACLs (lightweight check)
function Test-AclContains([string]$Path,[string]$Identity,[string]$RightsPattern){
  try {
    (Get-Acl $Path).Access | Where-Object { $_.IdentityReference -like $Identity -and $_.FileSystemRights.ToString() -match $RightsPattern } | ForEach-Object { return $true }
    return $false
  } catch { return $false }
}
if (Test-AclContains $PublishPath 'IIS_IUSRS' 'Read|ReadAndExecute') { Pass "IIS_IUSRS has Read/Execute on publish" } else { Warn "IIS_IUSRS missing Read/Execute on publish" }
if (Test-AclContains $LogsPath "IIS AppPool\$AppPoolName" 'Modify|FullControl') { Pass "Pool identity has Modify on logs" } else { Warn "Pool identity missing Modify on logs" }

# --- ANCM presence (aspnetcorev2) ---
$ancmDll = Join-Path ${env:ProgramFiles} 'IIS\Asp.Net Core Module\V2\aspnetcorev2.dll'
if (Test-Path $ancmDll) { Pass "AspNetCoreModuleV2 DLL present" } else { Warn "AspNetCoreModuleV2 DLL missing (install/repair Hosting Bundle)" }
try {
  $mods = & $appcmd list modules
  if ($mods -match 'AspNetCoreModuleV2') { Pass "AspNetCoreModuleV2 registered in IIS" } else { Warn "AspNetCoreModuleV2 not registered" }
} catch { Warn "Could not query IIS modules" }

# --- Parked vs App Payload detection + web.config mode ---
$exe = Get-ChildItem -Path $PublishPath -File -Filter *.exe -ErrorAction SilentlyContinue | Where-Object Name -ne 'app_offline.exe' | Select-Object -First 1
$dll = Get-ChildItem -Path $PublishPath -File -Filter *.dll -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -notin @('aspnetcorev2_inprocess.dll','aspnetcorev2_outofprocess.dll') } |
       Sort-Object Length -Descending | Select-Object -First 1
$wc  = Join-Path $PublishPath 'web.config'
$idx = Join-Path $PublishPath 'index.html'

if (-not $exe -and -not $dll) {
  if (Test-Path $idx -and -not (Test-Path $wc)) {
    Pass "Site is PARKED (static index.html served; no web.config)"
  } else {
    Warn "No app payload found; ensure parked state (index.html) or publish an app"
  }
} else {
  if (Test-Path $wc) {
    $wcText = Get-Content $wc -Raw
    if ($exe -and $wcText -match 'hostingModel="inprocess"') { Pass "web.config inprocess → EXE detected ($($exe.Name))" }
    elseif ($dll -and $wcText -match 'hostingModel="outofprocess"') { Pass "web.config outofprocess → DLL detected ($($dll.Name))" }
    else { Warn "web.config may not match payload (EXE/DLL). Review processPath/arguments/hostingModel." }
  } else {
    Warn "App payload present but web.config missing"
  }
}

# --- HTTP(S) Probes (handle self-signed in this session) ---
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# HTTP: don’t auto-follow redirect so we can see if it upgrades to HTTPS
try {
  $resp = Invoke-WebRequest $HttpUrl -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 10 -ErrorAction Stop
  Pass "HTTP probe returned $($resp.StatusCode)"
} catch {
  if ($_.Exception.Response) {
    $code = $_.Exception.Response.StatusCode.value__
    $loc  = $_.Exception.Response.Headers['Location']
    if ($code -ge 300 -and $code -lt 400) { Pass "HTTP probe got redirect ($code) → $loc" } else { Warn "HTTP probe error: $code" }
  } else { Warn "HTTP probe failed: $($_.Exception.Message)" }
}

# HTTPS: now that cert is bypassed, expect 200 from parked page or your app
try {
  $resp2 = Invoke-WebRequest $HttpsUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
  Pass "HTTPS probe returned $($resp2.StatusCode)"
} catch {
  if ($_.Exception.Response) {
    Warn "HTTPS probe error: $(( $_.Exception.Response.StatusCode.value__ ))"
  } else { Warn "HTTPS probe failed: $($_.Exception.Message)" }
}

# --- Last stdout log (if any) ---
$lastLog = Get-ChildItem $LogsPath -Filter 'stdout*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Desc | Select-Object -First 1
if ($lastLog) {
  Say "`nLast stdout log: $($lastLog.FullName)" 'Cyan'
  Get-Content $lastLog.FullName -Tail 10
} else {
  Say "`nNo stdout logs found (normal if parked or app hasn’t started)." 'DarkGray'
}

Say "`n== Verify complete ==" 'Cyan'
