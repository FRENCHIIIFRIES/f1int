# Compares RAM use: f1int (with and without our Chromium flags) vs Chrome,
# all showing the same page. Chrome gets a fresh temporary profile, so your own
# Chrome windows and data are not touched.
#   powershell -ExecutionPolicy Bypass -File tools\measure-ram.ps1 [-Url https://example.com] [-Wait 20]
# The number matches Task Manager's "Memory" column (private working set), added up over
# the app and all its helper processes (renderer, GPU, network, ...).
param([string]$Url = 'https://example.com', [int]$Wait = 20)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\qtenv.ps1"

# The app's process plus all its children, grandchildren, ...
function Get-TreeIds([int]$root) {
    $all = Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId
    $ids = [System.Collections.Generic.HashSet[int]]::new()
    [void]$ids.Add($root)
    do {
        $before = $ids.Count
        foreach ($p in $all) { if ($ids.Contains([int]$p.ParentProcessId)) { [void]$ids.Add([int]$p.ProcessId) } }
    } while ($ids.Count -ne $before)
    , $ids
}

function Measure-App([string]$name, [string]$exe, [string[]]$arguments) {
    $p = Start-Process $exe -ArgumentList $arguments -PassThru
    Start-Sleep -Seconds $Wait   # let the page load and the app settle
    $ids = Get-TreeIds $p.Id
    # Two views of memory:
    #  - private working set: what Task Manager shows; apps can make it look small by
    #    trimming (Chrome does this a lot), so it flatters them.
    #  - private bytes: all memory the app has claimed for itself, in RAM or not. The fairer number.
    $ws = (Get-CimInstance Win32_PerfFormattedData_PerfProc_Process |
        Where-Object { $ids.Contains([int]$_.IDProcess) } | Measure-Object WorkingSetPrivate -Sum).Sum
    $priv = (Get-Process -Id @($ids) -ErrorAction SilentlyContinue | Measure-Object PrivateMemorySize64 -Sum).Sum
    foreach ($id in $ids) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
    [pscustomobject]@{ App = $name; 'Private bytes (MB)' = [math]::Round($priv / 1MB)
                       'Task Manager (MB)' = [math]::Round($ws / 1MB); Processes = $ids.Count }
}

$f1int = "$PSScriptRoot\..\build\f1int.exe"
$chrome = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1

$results = @()
$results += Measure-App 'f1int (with flags)' $f1int @($Url)
$env:F1INT_NO_FLAGS = '1'
$results += Measure-App 'f1int (no flags)' $f1int @($Url)
Remove-Item Env:\F1INT_NO_FLAGS

if ($chrome) {
    $tmp = Join-Path $env:TEMP "f1int-chrome-measure-$(Get-Random)"
    $results += Measure-App 'Chrome (1 tab)' $chrome @("--user-data-dir=`"$tmp`"", '--no-first-run', '--no-default-browser-check', $Url)
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Warning 'Chrome not found, skipping it.'
}

"Page: $Url   (waited $Wait s each)"
$results | Format-Table -AutoSize
