# Sets up this PowerShell session for building f1int: finds Qt, the Microsoft C++
# compiler, CMake and Ninja, and puts them on PATH.
# build.ps1 and tools\measure-ram.ps1 use it; you don't need to run it yourself.
# Qt is found through Windows' list of installed apps; set $env:QT_ROOT to override.

# ---- Microsoft C++ compiler (newest Visual Studio / Build Tools with C++ installed) ----
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsAll = @(& $vswhere -all -products * -property installationPath 2>$null)
# Newest first, and only one whose compiler really starts (a damaged install can have a cl.exe that fails).
$vs = (& $vswhere -all -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json 2>$null | ConvertFrom-Json) |
    Sort-Object { [version]$_.installationVersion } -Descending | ForEach-Object installationPath |
    Where-Object {
        $cl = Get-ChildItem "$_\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1
        $cl -and ((& cmd /c "`"$($cl.FullName)`" 2>&1") -match 'C/C\+\+ Optimizing Compiler')
    } | Select-Object -First 1
if (-not $vs) { throw 'No working Visual Studio C++ compiler found. Install (or repair) Visual Studio Build Tools with "Desktop development with C++".' }
# vcvars64.bat sets the compiler's environment for cmd.exe; copy that environment into PowerShell.
cmd /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" >nul 2>nul && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') { Set-Item "env:$($Matches[1])" $Matches[2] }
}

# ---- Qt ----
$QtRoot = $env:QT_ROOT
if (-not $QtRoot) {
    $QtRoot = Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
                               HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq 'Qt' -and $_.InstallLocation } | Select-Object -First 1 -ExpandProperty InstallLocation
}
if (-not $QtRoot) { $QtRoot = 'C:\Qt' }

# Newest Qt 6 version folder (e.g. C:\Qt\6.12.0), then its 64-bit MSVC kit inside.
$version = Get-ChildItem $QtRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object Name -match '^6\.\d+\.\d+$' | Sort-Object { [version]$_.Name } | Select-Object -Last 1
$kit = if ($version) { Get-ChildItem $version.FullName -Directory -Filter 'msvc*_64' | Select-Object -First 1 }
if (-not $kit) { throw "No Qt 6 MSVC 64-bit kit found in $QtRoot. Install Qt 6.12 (MSVC 2022 64-bit) first." }

# Qt WebEngine is an "Extension" and could live outside the kit folder, so search for it.
# Skip Docs/Examples/Tools: they are huge and make the search take minutes.
$we = Get-ChildItem $QtRoot -Directory | Where-Object Name -notin 'Docs', 'Examples', 'Tools', 'dist', 'installerResources', 'vcredist' |
    ForEach-Object { Get-ChildItem $_.FullName -Recurse -Depth 7 -Filter 'Qt6WebEngineQuickConfig.cmake' -ErrorAction SilentlyContinue } |
    Where-Object FullName -match 'msvc' | Select-Object -First 1
if (-not $we) { throw "Qt WebEngine not found under $QtRoot. In the Qt Maintenance Tool, add Extensions > Qt WebEngine." }
$wePrefix = $we.Directory.Parent.Parent.Parent.FullName   # <prefix>\lib\cmake\Qt6WebEngineQuick\ -> <prefix>
$QtPrefixes = @($kit.FullName, $wePrefix) | Select-Object -Unique

$paths = @($QtPrefixes | ForEach-Object { "$_\bin" })

# ---- CMake and Ninja: already on PATH, else Qt's copies, else the ones inside Visual Studio ----
foreach ($tool in @{ exe = 'cmake.exe'; dirs = @("$QtRoot\Tools\CMake_64\bin") + @($vsAll | ForEach-Object { "$_\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin" }) },
                  @{ exe = 'ninja.exe'; dirs = @("$QtRoot\Tools\Ninja") + @($vsAll | ForEach-Object { "$_\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja" }) }) {
    if (-not (Get-Command $tool.exe -ErrorAction SilentlyContinue)) {
        $dir = $tool.dirs | Where-Object { Test-Path "$_\$($tool.exe)" } | Select-Object -First 1
        if (-not $dir) { throw "$($tool.exe) not found. Install it with the Qt Maintenance Tool (Developer Tools)." }
        $paths += $dir
    }
}

$env:PATH = ($paths -join ';') + ';' + $env:PATH
$env:QML_IMPORT_PATH = ($QtPrefixes | ForEach-Object { "$_\qml" }) -join ';'
