<#
.SYNOPSIS
  Build Aegean Office Setup: one .exe that installs GridLogic, WordLogic and SlideLogic.

.DESCRIPTION
  Builds each app's MSI with its own packaging/windows/package.ps1 (unless -SkipApps), then chains
  the three into a WiX bundle, written to dist/ at the top of Aegean Office:
    AegeanOffice-<version>-windows-<arch>-setup.exe

  Needs what the apps' packaging needs (Rust, the Windows SDK, WiX v5), plus WiX's bootstrapper
  extension:
    wix extension add -g WixToolset.BootstrapperApplications.wixext/5.0.2

  The version defaults to the build date (2026.10.19), so a newer Setup replaces an older one. The
  bundle isn't signed; a signed release needs `wix burn detach` / `reattach` around signing the
  engine.

.EXAMPLE
  pwsh installer/windows/build.ps1
  pwsh installer/windows/build.ps1 -SkipApps            # reuse the MSIs already in each app's dist/release
  pwsh installer/windows/build.ps1 -Version 2026.11.1
#>
param(
  [ValidateSet('x64', 'x86', 'arm64')] [string] $Arch = 'x64',
  [string] $Version = (Get-Date).ToString('yyyy.M.d'),
  [switch] $SkipApps
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = (Resolve-Path (Join-Path $here '..\..')).Path
$apps = [ordered]@{ GridLogic = 'gridcraft'; WordLogic = 'wordcraft'; SlideLogic = 'deckcraft' }

$msis = @{}
foreach ($app in $apps.Keys) {
  $dir = Join-Path $root $apps[$app]
  if (-not (Test-Path (Join-Path $dir 'packaging\windows\package.ps1'))) {
    throw "$app isn't checked out at $dir (git submodule update --init)"
  }
  if (-not $SkipApps) {
    Write-Output "==> $app"
    # package.ps1 runs cargo in the current directory: build from inside the app.
    Push-Location $dir
    try {
      pwsh -NoProfile -File (Join-Path $dir 'packaging\windows\package.ps1') -Arch $Arch
      if ($LASTEXITCODE -ne 0) { throw "$app packaging failed with exit code $LASTEXITCODE" }
    } finally { Pop-Location }
  }
  $msi = Get-ChildItem (Join-Path $dir 'dist\release') -Filter "$($apps[$app])-*-windows-$Arch.msi" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $msi) { throw "no $Arch MSI for $app in $dir\dist\release (run without -SkipApps)" }
  Write-Output "$app`: $($msi.Name) ($($msi.LastWriteTime))"
  $msis[$app] = $msi.FullName
}

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$out = Join-Path $dist "AegeanOffice-$Version-windows-$Arch-setup.exe"
Write-Output "==> wix build ($out)"
Push-Location $here
try {
  wix build bundle.wxs -arch $Arch -ext WixToolset.BootstrapperApplications.wixext `
    -d "Version=$Version" `
    -d "GridLogicMsi=$($msis.GridLogic)" -d "WordLogicMsi=$($msis.WordLogic)" -d "SlideLogicMsi=$($msis.SlideLogic)" `
    -o $out
  if ($LASTEXITCODE -ne 0) { throw "wix build failed with exit code $LASTEXITCODE" }
} finally { Pop-Location }
Remove-Item -Force ([IO.Path]::ChangeExtension($out, '.wixpdb')) -ErrorAction SilentlyContinue
Get-Item $out | Select-Object Name, Length
