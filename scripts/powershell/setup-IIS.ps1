# D:\ChurchApp\ops\setup-machine.ps1

# --- Safety: must be admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  throw "Run PowerShell as Administrator."
}

# --- Enable IIS (Windows Client uses DISM feature names)
Write-Host "Enabling IIS and common features..."
$features = @(
  "IIS-WebServerRole","IIS-WebServer","IIS-CommonHttpFeatures",
  "IIS-HttpErrors","IIS-HttpRedirect","IIS-ApplicationDevelopment",
  "IIS-NetFxExtensibility45","IIS-ISAPIExtensions","IIS-ISAPIFilter",
  "IIS-RequestFiltering","IIS-Security","IIS-BasicAuthentication",
  "IIS-WindowsAuthentication","IIS-StaticContent","IIS-DefaultDocument",
  "IIS-ManagementConsole","IIS-ManagementService"
)

foreach ($f in $features) {
  dism /Online /Enable-Feature /FeatureName:$f /All /NoRestart | Out-Null
}

# --- Optional but nice to have: WebSockets
dism /Online /Enable-Feature /FeatureName:IIS-WebSockets /All /NoRestart | Out-Null

# --- Make sure the IIS services are running
Get-Service W3SVC,WAS | Start-Service

# --- .NET SDK present?
$sdks = (& dotnet --list-sdks) 2>$null
if (-not $sdks) {
  Write-Warning "No .NET SDK found.  Install .NET 8 SDK (x64) and re-run."
} else {
  Write-Host "Found .NET SDK(s):" -ForegroundColor Green
  $sdks | ForEach-Object { Write-Host "  $_" }
}

# --- Reminder: install matching .NET Hosting Bundle for IIS if not already
Write-Host ""
Write-Host "IMPORTANT: Install the .NET **Hosting Bundle** for your .NET SDK (e.g., .NET 8) so IIS can host ASP.NET Core." -ForegroundColor Yellow
Write-Host "After installing the Hosting Bundle, run:  iisreset" -ForegroundColor Yellow

# --- Firewall for :8080 (idempotent)
if (-not (Get-NetFirewallRule -DisplayName "ChurchApp 8080" -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName "ChurchApp 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow | Out-Null
}

Write-Host "IIS + firewall setup complete." -ForegroundColor Green
