param(
  [string]$BuildDirectory = (Join-Path $PSScriptRoot '..\build\windows\x64\runner\Release'),
  [switch]$NoStart
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $BuildDirectory).Path
$exe = Join-Path $source 'DingDong.exe'
$info = (Get-Item -LiteralPath $exe).VersionInfo
if ($info.ProductName -ne 'DingDong DEV' -or
    -not (Test-Path -LiteralPath (Join-Path $source 'dingdong-development.marker'))) {
  throw 'Refusing to install a build without both DEV identity and data marker.'
}
$version = $info.ProductVersion
if ($version -notmatch '^\d+\.\d+\.\d+-dev\.[0-9]+(\+[0-9]+)?$') {
  throw "Not a development version: $version"
}
$destination = Join-Path $env:LOCALAPPDATA "DingDong DEV\$version"
if (Test-Path -LiteralPath $destination) {
  throw "Destination already exists. Keep it intact or use a new DEV version: $destination"
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Get-ChildItem -LiteralPath $source | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse
}
$installedExe = Join-Path $destination 'DingDong.exe'
if ((Get-FileHash -LiteralPath $exe).Hash -ne (Get-FileHash -LiteralPath $installedExe).Hash) {
  throw 'Installed executable hash does not match the verified build.'
}
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'DingDong DEV - Windows reminders.lnk'
if (Test-Path -LiteralPath $shortcutPath) {
  $shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "DingDong DEV - $version.lnk"
}
if (Test-Path -LiteralPath $shortcutPath) {
  throw "A shortcut for this version already exists: $shortcutPath"
}
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $installedExe
$shortcut.WorkingDirectory = $destination
$shortcut.Description = 'DingDong DEV: Windows tray buddy and hover reminder counts'
$shortcut.Save()
if (-not $NoStart) {
  Start-Process -FilePath $installedExe -WorkingDirectory $destination -WindowStyle Hidden
}
[PSCustomObject]@{
  Version = $version
  Executable = $installedExe
  Shortcut = $shortcutPath
  DataDirectory = (Join-Path $env:APPDATA 'DingDong DEV')
  PreferencesDirectory = (Join-Path $env:APPDATA 'Jevons\DingDong DEV')
  Started = (-not $NoStart)
} | ConvertTo-Json
