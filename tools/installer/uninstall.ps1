# Removes f1int (the app, its shortcuts and its "Installed apps" entry).
# Your bookmarks, passwords and settings stay, in case you install it again.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$root = $PSScriptRoot
if ([System.Windows.Forms.MessageBox]::Show('Remove f1int from this computer? Your bookmarks, passwords and settings are kept.', 'f1int', 'OKCancel', 'Question') -ne 'OK') { exit 1 }
while (Get-Process f1int -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$root\*" }) {
    if ([System.Windows.Forms.MessageBox]::Show('Close f1int, then press OK.', 'f1int', 'OKCancel', 'Information') -ne 'OK') { exit 1 }
}
Set-Location $env:TEMP
foreach ($dir in @([Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Desktop'))) {
    Remove-Item -LiteralPath (Join-Path $dir 'f1int.lnk') -Force -ErrorAction SilentlyContinue
}
Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\f1int' -Recurse -Force -ErrorAction SilentlyContinue
if ((Split-Path $root -Leaf) -eq 'f1int' -and (Test-Path (Join-Path $root 'bin\f1int.exe'))) {   # only ever an f1int folder
    Remove-Item -LiteralPath $root -Recurse -Force
}
[void][System.Windows.Forms.MessageBox]::Show('f1int was removed.', 'f1int')
