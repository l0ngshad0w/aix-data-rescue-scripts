# D:\ChurchApp\ops\provision-iis.ps1

Import-Module WebAdministration

$SiteName     = "ChurchApp"
$AppPoolName  = "ChurchAppPool"
$PhysicalPath = "D:\ChurchApp\App\publish"
$Port         = 8080

# App Pool (No Managed Code for ASP.NET Core)
if (-not (Test-Path IIS:\AppPools\$AppPoolName)) {
  New-Item IIS:\AppPools\$AppPoolName | Out-Null
}
Set-ItemProperty IIS:\AppPools\$AppPoolName managedRuntimeVersion ""   # No Managed Code
Set-ItemProperty IIS:\AppPools\$AppPoolName startMode "AlwaysRunning"
Set-ItemProperty IIS:\AppPools\$AppPoolName processModel.identityType "ApplicationPoolIdentity"

# Site
if (-not (Test-Path IIS:\Sites\$SiteName)) {
  New-Item IIS:\Sites\$SiteName -bindings @{protocol="http";bindingInformation="*:${Port}:"} -physicalPath $PhysicalPath | Out-Null
}
Set-ItemProperty IIS:\Sites\$SiteName applicationPool $AppPoolName

# Folder permissions for IIS AppPool identity
$acl = Get-Acl $PhysicalPath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS AppPool\$AppPoolName","Modify","ContainerInherit, ObjectInherit","None","Allow")
$acl.SetAccessRule($rule)
Set-Acl $PhysicalPath $acl

iisreset
Write-Host "IIS site $SiteName on http://localhost:$Port provisioned." -ForegroundColor Green
