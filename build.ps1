# Builds icon.ico and ClaudMonWidget.exe.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1
#
# Both outputs are committed, so this only needs running when the icon or the
# launcher changes. It uses the C# compiler that ships with the .NET Framework
# on every Windows install - nothing to download.
#
# The exe is a launcher, not a repackaged widget: it starts widget.ps1 from its
# own folder with no console window. The widget stays plain PowerShell you can
# read and edit.

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$icoPath = Join-Path $PSScriptRoot 'icon.ico'
$exePath = Join-Path $PSScriptRoot 'ClaudMonWidget.exe'

# --- icon -------------------------------------------------------------------
# A ring gauge on a dark rounded square: the same shape language as the widget,
# and the only motif that still reads at 16px. No text - glyphs turn to mud.
function New-IconBitmap {
    param([int]$Size)

    $bmp = New-Object System.Drawing.Bitmap $Size, $Size,
              ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)

    # At 16px there is no room to spend on padding, so it shrinks to nothing
    # and the ring gets the pixels instead.
    $pad    = $(if ($Size -le 24) { 0 } else { [int]($Size * 0.03) })
    $side   = $Size - 2 * $pad
    $radius = [math]::Max(2, [int]($Size * 0.22))

    # rounded square background
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    $path.AddArc($pad, $pad, $d, $d, 180, 90)
    $path.AddArc($pad + $side - $d, $pad, $d, $d, 270, 90)
    $path.AddArc($pad + $side - $d, $pad + $side - $d, $d, $d, 0, 90)
    $path.AddArc($pad, $pad + $side - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $bg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 18, 20, 23))
    $g.FillPath($bg, $path)

    # ring: dim full circle, then a bright arc for the "used" portion
    $stroke = [math]::Max(2, [int]($Size * 0.13))
    $inset  = [math]::Max(2, [int]($Size * 0.21))
    $box    = New-Object System.Drawing.Rectangle $inset, $inset,
                  ($Size - 2 * $inset), ($Size - 2 * $inset)

    $track = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(64, 255, 255, 255)), $stroke
    $track.StartCap = 'Round'; $track.EndCap = 'Round'
    $g.DrawArc($track, $box, 0, 360)

    $fill = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 74, 222, 128)), $stroke
    $fill.StartCap = 'Round'; $fill.EndCap = 'Round'
    $g.DrawArc($fill, $box, -90, 230)   # ~64%, enough to read as a gauge

    $g.Dispose()
    return $bmp
}

# One icon entry as a DIB: BITMAPINFOHEADER, 32bpp BGRA rows bottom-up, then a
# 1bpp AND mask left all-zero because the alpha channel already carries the
# transparency.
#
# Not PNG entries. The shell reads those since Vista, but GDI+ does not - a
# PNG-entry .ico throws "Requested range extends past the end of the array"
# the moment anything loads it through System.Drawing.Icon, which is exactly
# how a build check or a future tray icon would touch it.
function ConvertTo-IconDib {
    param([System.Drawing.Bitmap]$Bitmap)

    $w = $Bitmap.Width
    $h = $Bitmap.Height

    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $data = $Bitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
                             [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $pixels = New-Object byte[] ($data.Stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $pixels, 0, $pixels.Length)
    $Bitmap.UnlockBits($data)

    $maskStride = [int]([math]::Floor((($w + 31) / 32)) * 4)
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $ms

    $bw.Write([uint32]40)                # biSize
    $bw.Write([int32]$w)                 # biWidth
    $bw.Write([int32]($h * 2))           # biHeight: colour rows + mask rows
    $bw.Write([uint16]1)                 # biPlanes
    $bw.Write([uint16]32)                # biBitCount
    $bw.Write([uint32]0)                 # biCompression: BI_RGB
    $bw.Write([uint32]($w * $h * 4 + $maskStride * $h))
    $bw.Write([int32]0); $bw.Write([int32]0)    # pixels-per-metre
    $bw.Write([uint32]0); $bw.Write([uint32]0)  # palette counts

    # Bottom-up, which is what makes a DIB a DIB.
    for ($y = $h - 1; $y -ge 0; $y--) {
        $bw.Write($pixels, $y * $data.Stride, $w * 4)
    }
    $bw.Write((New-Object byte[] ($maskStride * $h)))

    $bw.Flush()
    # Leading comma, or PowerShell unrolls the byte[] into the pipeline and the
    # caller gets an object[] of boxed bytes. Length still reads right, so the
    # icon directory looks correct while BinaryWriter.Write picks a different
    # overload and emits one byte per entry: a 108-byte .ico with a perfect
    # header and no images.
    return , $ms.ToArray()
}

function Write-Ico {
    param([string]$Path, [int[]]$Sizes)

    # DIB for the sizes anything might load through GDI+, PNG above that: a
    # 256x256 DIB alone is 270KB and it all ends up embedded in the exe.
    $images = @()
    foreach ($s in $Sizes) {
        $bmp = New-IconBitmap -Size $s
        if ($s -le 64) {
            $images += , (ConvertTo-IconDib -Bitmap $bmp)
        } else {
            $ms = New-Object System.IO.MemoryStream
            $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            $images += , $ms.ToArray()
        }
        $bmp.Dispose()
    }

    $fs = [System.IO.File]::Create($Path)
    $bw = New-Object System.IO.BinaryWriter $fs
    $bw.Write([uint16]0)                 # reserved
    $bw.Write([uint16]1)                 # type: icon
    $bw.Write([uint16]$Sizes.Count)

    $offset = 6 + 16 * $Sizes.Count
    for ($i = 0; $i -lt $Sizes.Count; $i++) {
        # 0 means 256 in this field, which is why it is a single byte.
        $dim = $(if ($Sizes[$i] -ge 256) { 0 } else { $Sizes[$i] })
        $bw.Write([byte]$dim)            # width
        $bw.Write([byte]$dim)            # height
        $bw.Write([byte]0)               # palette size
        $bw.Write([byte]0)               # reserved
        $bw.Write([uint16]1)             # colour planes
        $bw.Write([uint16]32)            # bits per pixel
        $bw.Write([uint32]$images[$i].Length)
        $bw.Write([uint32]$offset)
        $offset += $images[$i].Length
    }
    foreach ($p in $images) { $bw.Write([byte[]]$p, 0, $p.Length) }
    $bw.Close()
    $fs.Close()

    $written = (Get-Item -LiteralPath $Path).Length
    if ($written -ne $offset) { throw "icon truncated: wrote $written bytes, expected $offset" }
}

Write-Ico -Path $icoPath -Sizes @(16, 32, 48, 64, 128, 256)

# Load it back the strict way. A broken .ico is invisible until something
# refuses to draw it, and by then it is in a commit.
$probe = New-Object System.Drawing.Icon $icoPath, 16, 16
if ($probe.Width -ne 16) { throw "icon check failed: got $($probe.Width)px for a 16px request" }
$probe.Dispose()
Write-Host ("icon : {0} ({1} bytes)" -f $icoPath, (Get-Item $icoPath).Length)

# --- launcher ---------------------------------------------------------------
$source = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;

static class Launcher
{
    static int Main(string[] args)
    {
        string dir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        string script = Path.Combine(dir, "widget.ps1");

        if (!File.Exists(script))
        {
            // No console to print to, so say it where it will be seen.
            System.Windows.Forms.MessageBox.Show(
                "widget.ps1 not found next to this program:\n" + dir,
                "ClaudMonWidget", System.Windows.Forms.MessageBoxButtons.OK,
                System.Windows.Forms.MessageBoxIcon.Error);
            return 1;
        }

        StringBuilder a = new StringBuilder();
        a.Append("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"");
        a.Append(script).Append("\"");
        foreach (string arg in args) { a.Append(" \"").Append(arg).Append("\""); }

        ProcessStartInfo psi = new ProcessStartInfo("powershell.exe", a.ToString());
        psi.WorkingDirectory = dir;
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        Process.Start(psi);
        return 0;
    }
}
'@

$srcFile = Join-Path $env:TEMP 'ClaudMonLauncher.cs'
Set-Content -LiteralPath $srcFile -Value $source -Encoding UTF8

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "csc.exe not found: $csc" }

# /target:winexe, not exe: an exe subsystem binary flashes a console window,
# which is the whole thing start-hidden.vbs exists to avoid.
& $csc /nologo /target:winexe /optimize+ /platform:anycpu `
       "/win32icon:$icoPath" "/out:$exePath" `
       /reference:System.dll /reference:System.Windows.Forms.dll `
       $srcFile

Remove-Item $srcFile -Force
Write-Host ("exe  : {0} ({1} bytes)" -f $exePath, (Get-Item $exePath).Length)
