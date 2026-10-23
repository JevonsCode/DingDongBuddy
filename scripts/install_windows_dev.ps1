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
$shell = New-Object -ComObject WScript.Shell
$replaceOwnedShortcut = $false
if (Test-Path -LiteralPath $shortcutPath) {
  $previousShortcut = $shell.CreateShortcut($shortcutPath)
  $devInstallRoot = [System.IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'DingDong DEV')) + '\'
  $previousTarget = $previousShortcut.TargetPath
  if ($previousTarget -and [System.IO.Path]::GetFullPath($previousTarget).StartsWith($devInstallRoot, [StringComparison]::OrdinalIgnoreCase)) {
    Copy-Item -LiteralPath $shortcutPath -Destination (Join-Path $destination 'previous-shortcut.lnk')
    $replaceOwnedShortcut = $true
  } else {
    $shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "DingDong DEV - $version.lnk"
  }
}
if ((Test-Path -LiteralPath $shortcutPath) -and -not $replaceOwnedShortcut) {
  throw "A shortcut for this version already exists: $shortcutPath"
}
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $installedExe
$shortcut.WorkingDirectory = $destination
$shortcut.Description = 'DingDong DEV: original reminder IP and visual capsule'
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
