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
$taskBuild = Join-Path $taskRoot 'build\selection-native'
New-Item -ItemType Directory -Force -Path $taskBuild | Out-Null
$taskCommand = @"
@echo off
chcp 65001 >nul
call "$taskVcVars" >nul
cl /nologo /c /std:c++17 /EHsc /W4 /WX /wd4100 /DUNICODE /D_UNICODE /DNOMINMAX "$taskRoot\windows\runner\windows_selection_monitor.cpp" /I"$taskWrapper\include" /I"$taskEngine" /Fo"$taskBuild\monitor.obj"
if errorlevel 1 exit /b %errorlevel%
cl /nologo /c /std:c++17 /EHsc /W4 /WX /wd4100 /DUNICODE /D_UNICODE /DNOMINMAX "$taskRoot\windows\runner\flutter_window.cpp" /I"$taskWrapper\include" /I"$taskEngine" /I"$taskRoot\windows" /I"$taskRoot\packages\desktop_multi_window\windows\include" /Fo"$taskBuild\flutter_window.obj"
if errorlevel 1 exit /b %errorlevel%
cl /nologo /std:c++17 /EHsc /W4 /WX /wd4100 /DUNICODE /D_UNICODE /DNOMINMAX "$taskRoot\windows\tests\windows_selection_monitor_test.cpp" "$taskRoot\third_party\selection-hook\engine.cc" /Fo"$taskBuild\\" /Fe"$taskBuild\selection_test.exe" /link user32.lib ole32.lib oleaut32.lib oleacc.lib uiautomationcore.lib
if errorlevel 1 exit /b %errorlevel%
"$taskBuild\selection_test.exe"
"@
$taskCommandFile = Join-Path $taskBuild 'test-generated.cmd'
[IO.File]::WriteAllText($taskCommandFile, $taskCommand, [Text.UTF8Encoding]::new($false))
& $env:ComSpec /d /c $taskCommandFile
if ($LASTEXITCODE -ne 0) { throw "Native selection tests failed ($LASTEXITCODE)." }
