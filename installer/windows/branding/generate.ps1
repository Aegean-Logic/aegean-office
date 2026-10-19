<#
.SYNOPSIS
  Renders Aegean Office Setup's artwork: banner.svg to banner.png, the three app icons to
  gridlogic.png, wordlogic.png and slidelogic.png, and the Aegean Logic app icon to
  aegean-office.ico (the Setup program's icon).

.DESCRIPTION
  Run after changing banner.svg or the icon masters in brand/; commit the outputs. Needs resvg
  (cargo install resvg). Fonts come from the system (Segoe UI on Windows).

.EXAMPLE
  pwsh installer/windows/branding/generate.ps1
#>
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = (Resolve-Path (Join-Path $here '..\..\..')).Path
if (-not (Get-Command resvg -ErrorAction SilentlyContinue)) { throw 'resvg not found (cargo install resvg)' }

function Render([string] $Svg, [string] $Png, [string[]] $Size) {
  & resvg --resources-dir (Split-Path $Svg) @Size $Svg $Png
  if ($LASTEXITCODE -ne 0) { throw "resvg failed on $Svg" }
}

Render (Join-Path $here 'banner.svg') (Join-Path $here 'banner.png') @()
Write-Output 'wrote banner.png'

# App icons on the Install page: 48 px controls, drawn at 2x.
foreach ($app in 'gridlogic', 'wordlogic', 'slidelogic') {
  Render (Join-Path $root "brand\$app\$app.svg") (Join-Path $here "$app.png") @('-w', '96', '-h', '96')
  Write-Output "wrote $app.png"
}

# The Setup program's icon: PNG images in one .ico (Windows Vista and later read PNG entries).
$sizes = 256, 48, 32, 16
$images = foreach ($s in $sizes) {
  $png = Join-Path ([IO.Path]::GetTempPath()) "aegean-office-$s.png"
  Render (Join-Path $root 'brand\aegean-logic\aegean-logic-appicon.svg') $png @('-w', "$s", '-h', "$s")
  $bytes = [IO.File]::ReadAllBytes($png)
  Remove-Item -Force $png
  , $bytes
}
$out = New-Object IO.MemoryStream
$w = New-Object IO.BinaryWriter $out
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $s = $sizes[$i]; $len = $images[$i].Length
  $w.Write([byte]($s % 256)); $w.Write([byte]($s % 256)); $w.Write([byte]0); $w.Write([byte]0)
  $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$len); $w.Write([uint32]$offset)
  $offset += $len
}
foreach ($img in $images) { $w.Write($img) }
$w.Flush()
[IO.File]::WriteAllBytes((Join-Path $here 'aegean-office.ico'), $out.ToArray())
Write-Output 'wrote aegean-office.ico'
