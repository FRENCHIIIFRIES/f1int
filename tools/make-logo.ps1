# Draws the f1int logo, a red flint stone, and writes:
#   resources/logo/f1int.svg      window/taskbar icon (built into the app)
#   resources/logo/f1int-<n>.png  PNGs (also used for the Mac icon)
#   resources/logo/f1int.ico      Windows .exe icon
# The shapes are defined once below and used for both the SVG and the PNGs.
#   powershell -ExecutionPolicy Bypass -File tools\make-logo.ps1
$ErrorActionPreference = 'Stop'
$out = Join-Path $PSScriptRoot '..\resources\logo' | Resolve-Path

$Light = '#E8434F'    # lit faces
$Dark = '#A61B2A'     # faces in shade
$Ink = '#2B0B10'      # outline
$Box = @(32, 30, 1110, 1110)   # the square the stone sits in: x, y, size (drawing units)

# Paths: 'M x y' move, 'L x y' line, 'Q cx cy x y' curve; 'Z' closes.
$Outline = 'M 790 78 Q 830 145 858 228 L 807 370 Q 875 480 880 578 Q 845 690 858 800 Q 790 840 784 910 Q 790 970 830 1020 Q 800 1075 757 1095 Q 560 1060 370 985 Q 350 900 295 800 Q 390 560 402 312 Q 540 260 620 128 Q 710 125 790 78 Z'
$Shade = 'M 708 222 Q 760 212 858 228 L 807 370 Q 875 480 880 578 Q 845 690 858 800 Q 790 840 784 910 Q 790 970 830 1020 Q 800 1075 757 1095 Q 660 960 556 895 Q 510 840 490 757 Q 565 580 577 405 L 708 222 Z'
$Edges = @(   # the ridges between faces
    'M 630 140 Q 660 185 708 222', 'M 708 222 Q 760 212 836 228', 'M 708 222 L 577 405',
    'M 420 322 Q 500 385 577 405', 'M 577 405 Q 700 395 807 370', 'M 577 405 Q 565 580 490 757',
    'M 310 800 Q 400 760 490 757', 'M 490 757 Q 510 840 556 895', 'M 556 895 Q 680 730 858 578',
    'M 380 975 Q 460 920 556 895', 'M 556 895 Q 660 960 757 1085')

# ---- SVG ----
$svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="' + ($Box[0], $Box[1], $Box[2], $Box[2] -join ' ') + '">' +
       '<path d="' + $Outline + '" fill="' + $Light + '"/>' +
       '<path d="' + $Shade + '" fill="' + $Dark + '"/>' +
       '<path d="' + ($Edges -join ' ') + '" fill="none" stroke="' + $Ink + '" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>' +
       '<path d="' + $Outline + '" fill="none" stroke="' + $Ink + '" stroke-width="30" stroke-linejoin="round"/></svg>'
[IO.File]::WriteAllText("$out\f1int.svg", $svg)

# ---- PNGs: the same paths through System.Drawing (curves become cubic Béziers) ----
Add-Type -AssemblyName System.Drawing
function ToPath([string]$d, [double]$scale, [double]$dx, [double]$dy) {
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $t = $d.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
    $i = 0; $cx = 0.0; $cy = 0.0
    $P = { param($v, $o) [single](([double]$v - $o) * $scale) }
    while ($i -lt $t.Count) {
        switch ($t[$i]) {
            'M' { $gp.StartFigure(); $cx = [double]$t[$i + 1]; $cy = [double]$t[$i + 2]; $i += 3 }
            'L' { $nx = [double]$t[$i + 1]; $ny = [double]$t[$i + 2]
                  $gp.AddLine((& $P $cx $dx), (& $P $cy $dy), (& $P $nx $dx), (& $P $ny $dy)); $cx = $nx; $cy = $ny; $i += 3 }
            'Q' { $qx = [double]$t[$i + 1]; $qy = [double]$t[$i + 2]; $nx = [double]$t[$i + 3]; $ny = [double]$t[$i + 4]
                  $c1x = $cx + 2 / 3 * ($qx - $cx); $c1y = $cy + 2 / 3 * ($qy - $cy)
                  $c2x = $nx + 2 / 3 * ($qx - $nx); $c2y = $ny + 2 / 3 * ($qy - $ny)
                  $gp.AddBezier((& $P $cx $dx), (& $P $cy $dy), (& $P $c1x $dx), (& $P $c1y $dy),
                                (& $P $c2x $dx), (& $P $c2y $dy), (& $P $nx $dx), (& $P $ny $dy))
                  $cx = $nx; $cy = $ny; $i += 5 }
            'Z' { $gp.CloseFigure(); $i += 1 }
            default { throw "bad path token $($t[$i])" }
        }
    }
    return $gp
}
$pngs = @{}
foreach ($size in 16, 32, 48, 64, 128, 256, 512) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $s = $size / $Box[2]
    $brushLight = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($Light))
    $brushDark = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($Dark))
    $inkColour = [System.Drawing.ColorTranslator]::FromHtml($Ink)
    $g.FillPath($brushLight, (ToPath $Outline $s $Box[0] $Box[1]))
    $g.FillPath($brushDark, (ToPath $Shade $s $Box[0] $Box[1]))
    if ($size -ge 48) {   # ridges only where there's room for them
        $pen = New-Object System.Drawing.Pen $inkColour, ([single](13 * $s))
        $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
        foreach ($e in $Edges) { $g.DrawPath($pen, (ToPath $e $s $Box[0] $Box[1])) }
    }
    $outlinePen = New-Object System.Drawing.Pen $inkColour, ([single][math]::Max(30 * $s, 1))
    $outlinePen.LineJoin = 'Round'
    $g.DrawPath($outlinePen, (ToPath $Outline $s $Box[0] $Box[1]))
    $g.Dispose()
    $file = "$out\f1int-$size.png"
    $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    $pngs[$size] = [IO.File]::ReadAllBytes($file)
}

# ---- ICO: a small header, one entry per size, then the PNG data ----
$icoSizes = 16, 32, 48, 64, 128, 256
$ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$icoSizes.Count)
$offset = 6 + 16 * $icoSizes.Count
foreach ($size in $icoSizes) {
    $b = if ($size -ge 256) { 0 } else { $size }
    $w.Write([byte]$b); $w.Write([byte]$b); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$pngs[$size].Length); $w.Write([uint32]$offset)
    $offset += $pngs[$size].Length
}
foreach ($size in $icoSizes) { $w.Write($pngs[$size]) }
[IO.File]::WriteAllBytes("$out\f1int.ico", $ms.ToArray())
Write-Output "logo written to $out"
