<#
.SYNOPSIS
  Build Aegean Office Setup: one .exe that installs GridLogic, WordLogic, SlideLogic and TeamsLogic.

.DESCRIPTION
  Builds each app's MSI with its own packaging/windows/package.ps1 (unless -SkipApps), then chains
  the four into a WiX bundle, written to dist/ at the top of Aegean Office:
    AegeanOffice-<version>-windows-<arch>-setup.exe

  Needs what the apps' packaging needs (Rust, the Windows SDK, WiX v5; Node 24 and npm 11 for
  TeamsLogic), plus WiX's bootstrapper and firewall extensions:
    wix extension add -g WixToolset.BootstrapperApplications.wixext/5.0.2
    wix extension add -g WixToolset.Firewall.wixext/5.0.2
  TeamsLogic has no x86 build, so -Arch x86 stops at TeamsLogic.

  The version defaults to the build date (2026.10.19), so a newer Setup replaces an older one.

  Signing: with the AZURE_* (or WINDOWS_CERTIFICATE) settings that sign.ps1 lists, each app's
  packaging signs its exe and MSI, and this script signs the bundle's engine (`wix burn detach` /
  `reattach`) and then the bundle. Without them everything is built unsigned, with warnings. Reused
  MSIs (-SkipApps, -Only) keep whatever signature they were built with.

.EXAMPLE
  pwsh installer/windows/build.ps1
  pwsh installer/windows/build.ps1 -SkipApps            # reuse the MSIs already in each app's dist/release
  pwsh installer/windows/build.ps1 -Only TeamsLogic     # rebuild TeamsLogic, reuse the others' MSIs
  pwsh installer/windows/build.ps1 -Version 2026.11.1
#>
param(
  [ValidateSet('x64', 'x86', 'arm64')] [string] $Arch = 'x64',
  [string] $Version = (Get-Date).ToString('yyyy.M.d'),
  [switch] $SkipApps,
  # Rebuild only these apps' MSIs; the others' are reused
  [ValidateSet('GridLogic', 'WordLogic', 'SlideLogic', 'TeamsLogic')] [string[]] $Only = @()
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = (Resolve-Path (Join-Path $here '..\..')).Path
$apps = [ordered]@{ GridLogic = 'gridcraft'; WordLogic = 'wordcraft'; SlideLogic = 'deckcraft'; TeamsLogic = 'teamslogic' }

$msis = @{}
foreach ($app in $apps.Keys) {
  $dir = Join-Path $root $apps[$app]
  if (-not (Test-Path (Join-Path $dir 'packaging\windows\package.ps1'))) {
    throw "$app isn't checked out at $dir (git submodule update --init)"
  }
  if (-not $SkipApps -and ($Only.Count -eq 0 -or $Only -contains $app)) {
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
  # A reused MSI older than the app's last commit leaves that commit out of the Setup
  $committed = [DateTimeOffset]::FromUnixTimeSeconds([long](git -C $dir log -1 --format=%ct)).LocalDateTime
  if ($msi.LastWriteTime -lt $committed) {
    Write-Warning "$app`: the MSI predates its last commit ($committed); rebuild it with -Only $app"
  }
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
    -d "GridLogicMsi=$($msis.GridLogic)" -d "WordLogicMsi=$($msis.WordLogic)" -d "SlideLogicMsi=$($msis.SlideLogic)" -d "TeamsLogicMsi=$($msis.TeamsLogic)" `
    -o $out
  if ($LASTEXITCODE -ne 0) { throw "wix build failed with exit code $LASTEXITCODE" }
} finally { Pop-Location }
Remove-Item -Force ([IO.Path]::ChangeExtension($out, '.wixpdb')) -ErrorAction SilentlyContinue

# Sign the Burn engine inside the bundle first (it's what runs and unpacks the MSIs), then the
# bundle as a whole. sign.ps1 leaves both unsigned, with a warning, when no signing secrets are set.
Write-Output "==> sign ($out)"
$engine = Join-Path ([IO.Path]::GetTempPath()) "aegean-office-engine-$PID.exe"
try {
  wix burn detach $out -engine $engine
  if ($LASTEXITCODE -ne 0) { throw "wix burn detach failed with exit code $LASTEXITCODE" }
  pwsh -NoProfile -File (Join-Path $here 'sign.ps1') $engine
  if ($LASTEXITCODE -ne 0) { throw "signing the bundle engine failed with exit code $LASTEXITCODE" }
  wix burn reattach $out -engine $engine -o "$out.reattached"
  if ($LASTEXITCODE -ne 0) { throw "wix burn reattach failed with exit code $LASTEXITCODE" }
  Move-Item -Force "$out.reattached" $out
  pwsh -NoProfile -File (Join-Path $here 'sign.ps1') $out
  if ($LASTEXITCODE -ne 0) { throw "signing the bundle failed with exit code $LASTEXITCODE" }
} finally { Remove-Item -Force $engine, "$out.reattached" -ErrorAction SilentlyContinue }
Get-Item $out | Select-Object Name, Length
