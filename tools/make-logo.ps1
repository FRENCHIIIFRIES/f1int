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
    $dx = $x + 0.5 - 12.5; $dy = $y + 0.5 - 12.0   # the C sits upper left
    $d = [math]::Sqrt($dx * $dx + $dy * $dy)
    $a = [math]::Atan2($dy, $dx) * 180 / [math]::PI          # 0 = right, 90 = down
    if ($d -ge 5.0 -and $d -le 8.6 -and -not ($a -gt -5 -and $a -lt 62)) {   # open towards the flint (lower right)
        $light = -($dx + $dy) / ($d + 0.001)                 # lit from the top left
        $grid[$x, $y] = if ($d -lt 6.2 -or $light -lt -0.55) { 'x' } elseif ($light -gt 0.25) { 'w' } else { 's' }
    }
} }

# ---- flint shard: an angular polygon, shaded with a bright upper-left edge ----
$poly = @(@(17, 21), @(21, 16), @(26, 17), @(29, 22), @(27, 28), @(20, 29), @(16, 26))   # a chunky lump, lower right
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
        $t = ($x + $y - 37) / 18.0                            # 0 = top left ... 1 = bottom right
        $grid[$x, $y] = if ($edge) { 'h' } elseif ($t -lt 0.35) { 'm' } else { 'd' }
    }
} }
# a facet line across the shard
foreach ($p in @(@(21, 20), @(22, 21), @(23, 22), @(24, 22))) { $grid[$p[0], $p[1]] = 'm' }

# ---- sparks where steel meets flint ----
$sparks = @{
    'y' = @(@(18, 17), @(19, 16), @(19, 17))                                     # white-hot core
    'r' = @(@(21, 14), @(17, 15), @(22, 17), @(20, 19), @(16, 18), @(23, 12))   # sparks
    'e' = @(@(25, 13), @(15, 20), @(24, 10), @(14, 16), @(26, 15))               # embers flying off
}
foreach ($c in $sparks.Keys) { foreach ($p in $sparks[$c]) { $grid[$p[0], $p[1]] = [char]$c } }

$out = Join-Path $PSScriptRoot '..\resources\logo'
New-Item -ItemType Directory -Force $out | Out-Null

# ---- SVG: one square per pixel, transparent background ----
$svg = "<svg xmlns=`"http://www.w3.org/2000/svg`" viewBox=`"0 0 $Cells $Cells`" shape-rendering=`"crispEdges`">"
# transparent background: no tile behind the drawing
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
    # (no tile: transparent background)
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
