# REPAIR web.config for ChurchApp
$PublishDir = "D:\ChurchApp\App\publish"
$Dll        = "ChurchApp.Web.dll"   # change only if your project name differs
$WebConfig  = Join-Path $PublishDir "web.config"

# Canonical ASP.NET Core web.config (OutOfProcess)
$config = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
    </handlers>
    <aspNetCore processPath="dotnet"
                arguments=".\$Dll"
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

# Write as UTF-8 *without* BOM
[System.IO.Directory]::CreateDirectory($PublishDir) | Out-Null
[System.IO.File]::WriteAllText($WebConfig, $config, (New-Object System.Text.UTF8Encoding($false)))

# Make sure logs dir exists
New-Item -ItemType Directory -Force (Join-Path $PublishDir "logs") | Out-Null

# Recycle the site/app pool and smoke test
Import-Module WebAdministration
$site = "ChurchApp"
$appPool = (Get-Item "IIS:\Sites\$site").applicationPool
Restart-WebAppPool $appPool
Start-WebSite $site | Out-Null

try {
  $resp = Invoke-WebRequest "http://localhost:8080/" -UseBasicParsing -TimeoutSec 10
  Write-Host "HTTP $($resp.StatusCode) $($resp.StatusDescription)" -ForegroundColor Green
} catch { Write-Warning $_.Exception.Message }
