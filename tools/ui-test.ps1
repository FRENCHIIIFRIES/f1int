# Runs a UI test script inside f1int and screenshots the window every time the script
# prints "SHOT <name>". Screenshots go to build\ui-shots\<name>.png.
#   powershell -ExecutionPolicy Bypass -File tools\ui-test.ps1 tests\ui\tabbar.qml
param([string]$Script = "$PSScriptRoot\..\tests\ui\tabbar.qml",
      [string[]]$Urls = @('https://www.wikipedia.org', 'https://github.com', 'https://news.ycombinator.com', 'https://www.bbc.co.uk'),
      [int]$Timeout = 90,
      [switch]$Screen)   # capture the screen (shows the frosted glass) instead of the window's own drawing
$ErrorActionPreference = 'Stop'
# "powershell -File" hands a list over as one "a,b,c" string: split it back into URLs.
$Urls = @($Urls | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
. "$PSScriptRoot\qtenv.ps1"
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class Shot {
  [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Ri, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
'@
[void][Shot]::SetProcessDPIAware()

# Start from an empty test profile each time (only the "f1int-test" folders/settings, never the real ones).
Remove-Item "$env:APPDATA\f1int\f1int-test", "$env:LOCALAPPDATA\f1int\f1int-test" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item 'HKCU:\Software\f1int\f1int-test' -Recurse -Force -ErrorAction SilentlyContinue

$out = New-Item -ItemType Directory -Force "$PSScriptRoot\..\build\ui-shots"
$log = Join-Path $out 'app.log'
$env:F1INT_UI_TEST = (Resolve-Path $Script).Path
$env:QT_FORCE_STDERR_LOGGING = '1'
$p = Start-Process "$PSScriptRoot\..\build\f1int.exe" -ArgumentList $Urls -PassThru -RedirectStandardError $log
$seen = 0
$deadline = (Get-Date).AddSeconds($Timeout)
while ((Get-Date) -lt $deadline -and -not $p.HasExited) {
    Start-Sleep -Milliseconds 300
    $lines = @(Get-Content $log -ErrorAction SilentlyContinue)
    if ($lines.Count -le $seen) { continue }   # nothing new (a reversed range would re-read old lines)
    foreach ($line in $lines[$seen..($lines.Count - 1)] | Where-Object { $_ }) {
        if ($line -match 'SHOT (\S+)') {
            $p.Refresh(); $h = $p.MainWindowHandle
            $r = New-Object Shot+R; [void][Shot]::GetWindowRect($h, [ref]$r)
            $bmp = New-Object System.Drawing.Bitmap ($r.Ri - $r.L), ($r.B - $r.T)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            if ($Screen) {
                # What's really on screen, including the frosted-glass backdrop (window must be in front).
                [void][Shot]::SetForegroundWindow($h); Start-Sleep -Milliseconds 300
                $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
            } else {
                $dc = $g.GetHdc(); [void][Shot]::PrintWindow($h, $dc, 2); $g.ReleaseHdc($dc)
            }
            $g.Dispose()
            $file = Join-Path $out "$($Matches[1]).png"; $bmp.Save($file); $bmp.Dispose()
            "shot: $file"
        } elseif ($line -match 'DONE') { $line; $deadline = Get-Date }
    }
    $seen = $lines.Count
}
Stop-Process -Id $p.Id -ErrorAction SilentlyContinue
'--- warnings ---'
Get-Content $log | Where-Object { $_ -notmatch 'SHOT|DONE|WebEngineProfilePrototype' } | Select-Object -First 30
