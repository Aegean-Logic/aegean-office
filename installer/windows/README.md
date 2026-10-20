# Aegean Office Setup (Windows)

One program, `AegeanOffice-<version>-windows-x64-setup.exe`, that installs GridLogic, WordLogic,
SlideLogic and TeamsLogic in one go. It asks for administrator rights once, has a Create desktop
shortcuts box for all four, and shows as one entry, Aegean Office, in Installed apps. Uninstalling
that entry removes all four; Repair puts back anything missing.

It is a [WiX](https://wixtoolset.org) Burn bundle around the apps' own MSIs, so each app installs
exactly as its own Setup would. An app already installed on its own is left as it is, and stays when
Aegean Office is uninstalled.

## Building

```bash
pwsh installer/windows/build.ps1
```

This builds each app's MSI with its `packaging/windows/package.ps1`, then the bundle, into `dist/`
at the top of Aegean Office. `-SkipApps` reuses the MSIs already built; `-Version` sets the suite's
version (the build date by default, so a newer Setup replaces an older one).

Needs what the apps' packaging needs (Rust, the Windows SDK and WiX v5; Node 24 and npm 11 for
TeamsLogic, an Electron app), plus WiX's bootstrapper and firewall extensions (TeamsLogic's MSI adds
a firewall exception for calls):

```bash
wix extension add -g WixToolset.BootstrapperApplications.wixext/5.0.2
wix extension add -g WixToolset.Firewall.wixext/5.0.2
```

TeamsLogic is built for x64 and arm64 only, so `-Arch x86` stops at it.

## Files

| File | What |
|---|---|
| `bundle.wxs` | The bundle: the four MSIs in a chain, the desktop shortcut choice, the fixed UpgradeCode |
| `theme.xml`, `theme.wxl` | The Setup window (WiX standard bootstrapper application) and its strings |
| `branding/` | The banner, app icons and Setup icon; `generate.ps1` renders them from `banner.svg` and `brand/` |
| `build.ps1` | Builds the apps' MSIs and the bundle |

## From the command line

```bash
AegeanOffice-2026.10.19-windows-x64-setup.exe /passive DesktopShortcuts=1
```

`/quiet` installs with no window, `/uninstall` removes all four, and `/help` lists the rest.

The Setup isn't signed yet, so Windows SmartScreen asks before running it.
