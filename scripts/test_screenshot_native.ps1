param([Parameter(Mandatory = $true)][string]$FlutterRoot)
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskFlutter = (Resolve-Path -LiteralPath $FlutterRoot).Path
$taskEngine = Join-Path $taskFlutter 'bin\cache\artifacts\engine\windows-x64'
$taskWrapper = Join-Path $taskEngine 'cpp_client_wrapper'
$taskVsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$taskVs = & $taskVsWhere -latest -products '*' -property installationPath
if (-not $taskVs) { throw 'Visual Studio C++ build tools were not found.' }
$taskVcVars = Join-Path $taskVs 'VC\Auxiliary\Build\vcvars64.bat'
$taskBuild = Join-Path $taskRoot 'build\screenshot-native'
New-Item -ItemType Directory -Force -Path $taskBuild | Out-Null
$taskCommand = @"
@echo off
chcp 65001 >nul
call "$taskVcVars" >nul
cl /nologo /std:c++17 /EHsc /W4 /WX /wd4100 /DUNICODE /D_UNICODE /DNOMINMAX "$taskRoot\windows\tests\screenshot_plugin_test.cpp" "$taskWrapper\standard_codec.cc" "$taskWrapper\core_implementations.cc" /I"$taskWrapper\include" /I"$taskEngine" /Fo"$taskBuild\\" /Fe"$taskBuild\screenshot_plugin_test.exe" /link "$taskEngine\flutter_windows.dll.lib" user32.lib gdi32.lib gdiplus.lib comdlg32.lib dwmapi.lib
if errorlevel 1 exit /b %errorlevel%
set "PATH=$taskEngine;%PATH%"
"$taskBuild\screenshot_plugin_test.exe" "$taskBuild\native-crop.png"
"@
$taskCommandFile = Join-Path $taskBuild 'test-generated.cmd'
[IO.File]::WriteAllText($taskCommandFile, $taskCommand, [Text.UTF8Encoding]::new($false))
& $env:ComSpec /d /c $taskCommandFile
if ($LASTEXITCODE -ne 0) { throw "Native screenshot tests failed ($LASTEXITCODE)." }
