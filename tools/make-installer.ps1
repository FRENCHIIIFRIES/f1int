# Makes one f1int-<version>-windows-x64.exe from the release zip: double-click it and f1int
# installs for that user (no admin), with Start menu and desktop shortcuts and an uninstaller.
# It's a small C# program (compiled with the C# compiler that comes with Windows) with
# setup.ps1, uninstall.ps1 and the zip appended after it.
#   powershell -ExecutionPolicy Bypass -File tools\make-installer.ps1 build\package\f1int-0.2.4-windows-x64.zip
param([Parameter(Mandatory)][string]$Zip)
$ErrorActionPreference = 'Stop'
$Zip = (Resolve-Path $Zip).Path
$version = [regex]::Match((Split-Path $Zip -Leaf), '\d+\.\d+\.\d+').Value
$target = Join-Path (Split-Path $Zip) "f1int-$version-windows-x64.exe"
$csc = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
$icon = Resolve-Path "$PSScriptRoot\..\resources\logo\f1int.ico"
& $csc /nologo /target:winexe /optimize "/win32icon:$icon" "/out:$target" "$PSScriptRoot\installer\stub.cs"
if ($LASTEXITCODE -ne 0) { throw 'The installer program did not compile' }

$parts = @("$PSScriptRoot\installer\setup.ps1", "$PSScriptRoot\installer\uninstall.ps1", $Zip)
$out = [IO.File]::Open($target, 'Append')
try {
    foreach ($p in $parts) { $in = [IO.File]::OpenRead($p); $in.CopyTo($out); $in.Dispose() }
    $w = New-Object IO.BinaryWriter($out)
    foreach ($p in $parts) { $w.Write([long](Get-Item $p).Length) }
    $w.Write([uint64]'0x31544E4931463146')   # the end marker the installer looks for
    $w.Flush()
} finally { $out.Dispose() }
Get-Item $target | Select-Object FullName, Length
