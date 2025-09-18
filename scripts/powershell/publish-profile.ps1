# D:\ChurchApp\App\src\ChurchApp.Web\Properties\PublishProfiles\FolderProfile.pubxml
New-Item -Type Directory -Force D:\ChurchApp\App\src\ChurchApp.Web\Properties\PublishProfiles | Out-Null
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
    <PublishDir>D:\ChurchApp\App\publish\</PublishDir>
  </PropertyGroup>
</Project>
"@
$pubxml | Out-File D:\ChurchApp\App\src\ChurchApp.Web\Properties\PublishProfiles\FolderProfile.pubxml -Encoding UTF8
