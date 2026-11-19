# f1int installer: runs from inside f1int-setup.exe (made by tools\make-installer.ps1).
# Installs for this Windows user only (no admin needed), into the folder f1int's updater expects.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$root = if ($env:F1INT_INSTALL_ROOT) { $env:F1INT_INSTALL_ROOT } else { Join-Path $env:LOCALAPPDATA 'Programs\f1int' }   # (override: tests)
$quiet = [bool]$env:F1INT_INSTALL_QUIET
function Say([string]$text, [string]$icon = 'Information') {
    if (-not $quiet) { [void][System.Windows.Forms.MessageBox]::Show($text, 'f1int', 'OK', $icon) } else { Write-Host $text }
}
try {
    # f1int can't be replaced while it's open.
    while (Get-Process f1int -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$root\*" }) {
        if ($quiet) { throw 'f1int is open' }
        $a = [System.Windows.Forms.MessageBox]::Show('Close f1int, then press OK to continue.', 'f1int', 'OKCancel', 'Information')
        if ($a -ne 'OK') { exit 1 }
    }
    Write-Host 'Installing f1int...'
    $tmp = Join-Path $env:TEMP ('f1int-setup-' + [guid]::NewGuid())
    Expand-Archive -LiteralPath (Join-Path $PSScriptRoot 'f1int.zip') -DestinationPath $tmp -Force
    $src = Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1
    if (-not (Test-Path (Join-Path $src.FullName 'bin\f1int.exe'))) { throw 'The package is damaged.' }
    New-Item -ItemType Directory -Force $root | Out-Null
    Copy-Item -Path (Join-Path $src.FullName '*') -Destination $root -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'uninstall.ps1') -Destination $root -Force
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue

    $exe = Join-Path $root 'bin\f1int.exe'
    $version = [regex]::Match($src.Name, '\d+\.\d+\.\d+').Value   # the package folder: f1int-<version>-windows-x64
    $shell = New-Object -ComObject WScript.Shell
    foreach ($dir in @([Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Desktop'))) {
        try {   # (a desktop that OneDrive syncs can refuse briefly: a missing shortcut isn't worth failing for)
            $lnk = $shell.CreateShortcut((Join-Path $dir 'f1int.lnk'))
            $lnk.TargetPath = $exe; $lnk.WorkingDirectory = Join-Path $root 'bin'; $lnk.Description = 'f1int browser'; $lnk.Save()
        } catch { Write-Host "No shortcut in $dir" }
    }
    # "Installed apps" entry, so it can be removed like any other app.
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\f1int'
    New-Item -Path $key -Force | Out-Null
    $uninstall = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $root 'uninstall.ps1') + '"'
    $values = @{ DisplayName = 'f1int'; DisplayVersion = "$version"; Publisher = 'f1int'; DisplayIcon = $exe
                 InstallLocation = $root; UninstallString = $uninstall; NoModify = 1; NoRepair = 1 }
    foreach ($k in $values.Keys) { Set-ItemProperty -Path $key -Name $k -Value $values[$k] }

    if (-not $quiet) { Start-Process $exe }
    Write-Host "Installed f1int $version to $root"
} catch {
    Say ("f1int couldn't be installed: " + $_.Exception.Message) 'Error'
    exit 1
}
