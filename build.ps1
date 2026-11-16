# Builds f1int on Windows.
#   .\build.ps1          build only
#   .\build.ps1 -Run     build, then start the browser
#   .\build.ps1 -Test    build, then run the unit tests
#   .\build.ps1 -Package build, then make the installer (needs NSIS; -Zip makes a .zip instead)
# If Windows refuses to run scripts:  powershell -ExecutionPolicy Bypass -File .\build.ps1 -Run
param([switch]$Run, [switch]$Test, [switch]$Package, [switch]$Zip, [string]$Config = 'Release')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\tools\qtenv.ps1"

$build = "$PSScriptRoot\build"
# Ninja runs the compiler that tools\qtenv.ps1 set up (the newest Visual Studio found).
cmake -S $PSScriptRoot -B $build -G Ninja "-DCMAKE_BUILD_TYPE=$Config" "-DCMAKE_PREFIX_PATH=$($QtPrefixes -join ';')"
if ($LASTEXITCODE) { exit $LASTEXITCODE }
cmake --build $build
if ($LASTEXITCODE) { exit $LASTEXITCODE }

if ($Test) {
    ctest --test-dir $build --output-on-failure
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
}
if ($Package -or $Zip) {
    # cpack runs the install step (which copies in Qt via windeployqt), then wraps it up.
    $generator = if ($Zip) { 'ZIP' } else { 'NSIS' }
    cpack -G $generator --config "$build\CPackConfig.cmake" -B "$build\package"
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
}
if ($Run) { & "$build\f1int.exe" }
