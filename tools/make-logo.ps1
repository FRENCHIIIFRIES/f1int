# Draws the f1int logo: a curled steel striker hitting a flint shard, throwing sparks.
# It is drawn from simple shapes on a 32x32 pixel grid (pixel-art look, original design),
# then written as:
#   resources/logo/f1int.svg      window/taskbar icon (built into the app)
#   resources/logo/f1int-<n>.png  PNGs (also used for the Mac icon)
#   resources/logo/f1int.ico      Windows .exe icon
# Run again after changing it:  powershell -ExecutionPolicy Bypass -File tools\make-logo.ps1
$Cells = 32
$colours = @{
    'k' = '#000000'                                   # tile
    'w' = '#f2f2f2'; 's' = '#a9a9a9'; 'x' = '#5c5c5c' # steel: lit, mid, shadow
    'h' = '#c8c8c8'; 'm' = '#6f6f6f'; 'd' = '#3a3a3a' # flint: edge highlight, mid, dark
    'y' = '#ffffff'; 'r' = '#D71921'; 'e' = '#7a0f14' # sparks: white-hot, red, dim ember
}
$grid = New-Object 'char[,]' $Cells, $Cells
for ($y = 0; $y -lt $Cells; $y++) { for ($x = 0; $x -lt $Cells; $x++) { $grid[$x, $y] = '.' } }

# ---- steel striker: a thick ring (centre 20,11) open towards the bottom left ----
for ($y = 0; $y -lt $Cells; $y++) { for ($x = 0; $x -lt $Cells; $x++) {
    $dx = $x + 0.5 - 20.5; $dy = $y + 0.5 - 11.5
    $d = [math]::Sqrt($dx * $dx + $dy * $dy)
    $a = [math]::Atan2($dy, $dx) * 180 / [math]::PI          # 0 = right, 90 = down
    if ($d -ge 5.2 -and $d -le 8.3 -and -not ($a -gt 105 -and $a -lt 165)) {
        $light = -($dx + $dy) / ($d + 0.001)                 # lit from the top left
        $grid[$x, $y] = if ($d -lt 6.2 -or $light -lt -0.55) { 'x' } elseif ($light -gt 0.25) { 'w' } else { 's' }
    }
} }

# ---- flint shard: an angular polygon, shaded with a bright upper-left edge ----
$poly = @(@(4, 22), @(9, 15), @(14, 17), @(17, 22), @(14, 28), @(7, 29), @(3, 26))
function Inside($px, $py) {
    $in = $false
    $j = $poly.Count - 1
    for ($i = 0; $i -lt $poly.Count; $i++) {   # classic even-odd test against each edge
        $xi = $poly[$i][0]; $yi = $poly[$i][1]; $xj = $poly[$j][0]; $yj = $poly[$j][1]
        if ((($yi -gt $py) -ne ($yj -gt $py)) -and ($px -lt ($xj - $xi) * ($py - $yi) / ($yj - $yi) + $xi)) { $in = -not $in }
        $j = $i
    }
    $in
}
for ($y = 0; $y -lt $Cells; $y++) { for ($x = 0; $x -lt $Cells; $x++) {
    if (Inside ($x + 0.5) ($y + 0.5)) {
        $edge = -not (Inside ($x - 0.5) ($y - 0.5))           # pixel just inside the top-left edge
        $t = ($x + $y - 22) / 18.0                            # 0 = top left ... 1 = bottom right
        $grid[$x, $y] = if ($edge) { 'h' } elseif ($t -lt 0.35) { 'm' } else { 'd' }
    }
} }
# a facet line across the shard
foreach ($p in @(@(9, 18), @(10, 19), @(11, 20), @(12, 21))) { $grid[$p[0], $p[1]] = 'm' }

# ---- sparks where steel meets flint ----
$sparks = @{
    'y' = @(@(14, 15), @(15, 14), @(15, 15))                                     # white-hot core
    'r' = @(@(17, 13), @(13, 12), @(18, 16), @(16, 18), @(11, 14), @(19, 11))   # sparks
    'e' = @(@(21, 18), @(10, 10), @(20, 14), @(13, 9), @(22, 21))               # embers flying off
}
foreach ($c in $sparks.Keys) { foreach ($p in $sparks[$c]) { $grid[$p[0], $p[1]] = [char]$c } }

$out = Join-Path $PSScriptRoot '..\resources\logo'
New-Item -ItemType Directory -Force $out | Out-Null

# ---- SVG: one square per pixel on a rounded black tile ----
$svg = "<svg xmlns=`"http://www.w3.org/2000/svg`" viewBox=`"0 0 $Cells $Cells`" shape-rendering=`"crispEdges`">"
$svg += "<rect width=`"$Cells`" height=`"$Cells`" rx=`"7`" fill=`"$($colours['k'])`"/>"
for ($y = 0; $y -lt $Cells; $y++) { for ($x = 0; $x -lt $Cells; $x++) {
    $c = [string]$grid[$x, $y]
    if ($c -ne '.') { $svg += "<rect x=`"$x`" y=`"$y`" width=`"1`" height=`"1`" fill=`"$($colours[$c])`"/>" }
} }
[IO.File]::WriteAllText("$out\f1int.svg", $svg + '</svg>')

# ---- PNGs: same grid, scaled up with hard pixel edges (16 px is the grid shrunk smoothly) ----
Add-Type -AssemblyName System.Drawing
$pngs = @{}
foreach ($n in 16, 32, 48, 64, 128, 256, 512) {
    $bmp = New-Object System.Drawing.Bitmap $n, $n
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $r = $n * 7 / $Cells; $d = 2 * $r
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath   # rounded tile
    $path.AddArc(0, 0, $d, $d, 180, 90); $path.AddArc($n - $d - 1, 0, $d, $d, 270, 90)
    $path.AddArc($n - $d - 1, $n - $d - 1, $d, $d, 0, 90); $path.AddArc(0, $n - $d - 1, $d, $d, 90, 90); $path.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($colours['k']))), $path)
    $g.SmoothingMode = 'None'
    if ($n -lt $Cells) { $g.InterpolationMode = 'HighQualityBicubic' }
    $px = $n / $Cells
    for ($y = 0; $y -lt $Cells; $y++) { for ($x = 0; $x -lt $Cells; $x++) {
        $c = [string]$grid[$x, $y]
        if ($c -ne '.') {
            $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($colours[$c]))
            $g.FillRectangle($brush, [single]($x * $px), [single]($y * $px), [single][math]::Max($px, 1), [single][math]::Max($px, 1))
        }
    } }
    $g.Dispose()
    $file = "$out\f1int-$n.png"
    $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    $pngs[$n] = [IO.File]::ReadAllBytes($file)
}

# ---- ICO: a small header, one entry per size, then the PNG data ----
$icoSizes = 16, 32, 48, 64, 128, 256
$ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$icoSizes.Count)
$offset = 6 + 16 * $icoSizes.Count
foreach ($n in $icoSizes) {
    $b = if ($n -ge 256) { 0 } else { $n }
    $w.Write([byte]$b); $w.Write([byte]$b); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$pngs[$n].Length); $w.Write([uint32]$offset)
    $offset += $pngs[$n].Length
}
foreach ($n in $icoSizes) { $w.Write($pngs[$n]) }
[IO.File]::WriteAllBytes("$out\f1int.ico", $ms.ToArray())
'logo written'
