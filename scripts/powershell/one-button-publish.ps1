# D:\ChurchApp\ops\publish-and-recycle.ps1

param(
  [string]$ProjectPath = "D:\ChurchApp\App\src\ChurchApp.Web\ChurchApp.Web.csproj",
  [string]$PublishProfile = "FolderProfile",
  [string]$SiteName = "ChurchApp"
)

Write-Host "Publishing..." -ForegroundColor Cyan
dotnet publish $ProjectPath /p:PublishProfile=$PublishProfile -c Release

Write-Host "Recycling IIS app pool..." -ForegroundColor Cyan
Import-Module WebAdministration
$appPool = (Get-Item "IIS:\Sites\$SiteName").applicationPool
Restart-WebAppPool $appPool

Write-Host "Done.  Browse: http://localhost:8080" -ForegroundColor Green
