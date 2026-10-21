# OneDrive via the sync client's local folders, and how Office presents OneDrive (as of October 2026)

Scope: what a third-party desktop app (Aegean Office: Rust/egui on Windows, macOS, Linux) can do with folders the OneDrive sync client already mirrors locally, and where that path falls short of Microsoft Office's own OneDrive experience. Research date: 2026-10-19. Items marked **[older]** or **[unverified]** should be re-checked on a test machine before being built on.

Source quality note: Microsoft documents the *generic* Cloud Files / sync-root platform well. It does **not** publicly document OneDrive's own registry layout (`HKCU\Software\Microsoft\OneDrive\Accounts\*`, `HKCU\Software\SyncEngines\Providers\OneDrive\*`) or its environment variables. What is known about those comes from forums, admin tooling and security tooling, and should be treated as observed, undocumented behaviour that can change without notice.

---

## 1. Windows: discovering OneDrive sync roots (personal, business, multiple accounts, synced SharePoint libraries)

### Takeaway
The only *documented, supported* way to enumerate sync roots is the Windows Cloud Files platform: `StorageProviderSyncRootManager.GetCurrentSyncRoots()` (WinRT), or the `SyncRootManager` registry keys it is built on, plus `CfGetSyncRootInfoByPath` for testing whether a path sits inside a sync root. The OneDrive environment variables and the `HKCU\Software\Microsoft\OneDrive\Accounts\*` registry keys are widely used and give friendlier data (account type, display name, tenant), but they are undocumented. A sound design uses the platform API as the source of truth, filtered to provider ID "OneDrive", and adds the OneDrive-specific registry or environment data only for labels.

### Cited Findings
- **Platform API, documented.** `StorageProviderSyncRootManager.GetCurrentSyncRoots()` "Gets all of the currently registered sync roots" and returns `StorageProviderSyncRootInfo` objects. The collection "can include both legacy sync roots and sync roots registered with StorageProviderSyncRootManager.Register". The docs list it for every WinRT version from 16299 (Win10 1709) to 28000 and Insider. The page was updated 2025-11-21. — [Microsoft Learn: GetCurrentSyncRoots](https://learn.microsoft.com/en-us/uwp/api/windows.storage.provider.storageprovidersyncrootmanager.getcurrentsyncroots)
- **Sync-root registry layout, documented.** Providers register under `HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\SyncRootManager\[storage provider ID]![Windows SID]![Account ID]`, with `DisplayNameResource`, `IconResource` and `UserSyncRoots\[SID]` (the on-disk location). The docs give "OneDrive" as the example provider ID. The Account ID exists so that one user can have several roots, "One example of this is a work and a personal account." Other apps "can then use StorageFile.Provider to get the DisplayName and Id" of the provider. — [Microsoft Learn: Integrate a Cloud Storage Provider](https://learn.microsoft.com/en-us/windows/win32/shell/integrate-cloud-storage)
- **Testing whether a path is in a sync root.** `CfGetSyncRootInfoByPath(FilePath, InfoClass, ...)` (CldApi.dll, Windows 10 1709+, desktop apps) "Gets various sync root information given a file under the sync root". It fails if the file is not under a cloud-files sync root. The info classes are `CF_SYNC_ROOT_INFO_BASIC`, `_STANDARD` and `_PROVIDER`. — [Microsoft Learn: CfGetSyncRootInfoByPath](https://learn.microsoft.com/en-us/windows/win32/api/cfapi/nf-cfapi-cfgetsyncrootinfobypath)
- **Cloud Files platform scope.** It was introduced in Windows 10 1709. The cldflt.sys minifilter "currently only supports NTFS volumes". — [Microsoft Learn: Build a Cloud Sync Engine](https://learn.microsoft.com/en-us/windows/win32/cfapi/build-a-cloud-file-sync-engine)
- **OneDrive account registry, undocumented [unverified].** Forum users report subkeys `Personal` and `Business1` (Business2 and so on for further accounts) under `HKCU\Software\Microsoft\OneDrive\Accounts`, each holding a `UserFolder` value with that account's local root. — [XYplorer forum](https://www.xyplorer.com/xyfc2/viewtopic.php?p=207358); the BigFix forum reads `Accounts\Business1\UserFolder` the same way, e.g. "c:\users\username - tomjerry inc" — [BigFix forum](https://forum.bigfix.com/t/need-help-with-analysis-look-for-a-folder-in-ondrive-by-garbing-a-registry-value/35035). No Microsoft page documenting `DisplayName` or `ServiceEndpointUri` in these keys turned up.
- **Stale entries.** Accounts entries can outlive the actual folder. Forum advice is to unlink the account or remove the stale key. — [Microsoft Tech Community discussion](https://techcommunity.microsoft.com/discussions/onedriveforbusiness/local-onedrive-does-not-seem-to-be-syncing/4563240/replies/4563280)
- **Policy can relocate the root.** Admin policies under `HKLM\SOFTWARE\Policies\Microsoft\OneDrive` include `DefaultRootDir` (default folder location) and `DisableCustomRoot`. — [Microsoft Learn: Use Group Policy (OneDrive)](https://learn.microsoft.com/sv-se/sharepoint/use-group-policy)
- **Environment variables, undocumented and inconsistent [unverified].** University IT guidance says `%OneDriveCommercial%` holds the work/school root and `%OneDriveConsumer%` the personal root. — [University of Waterloo IT](https://uwaterloo.atlassian.net/wiki/x/doRPHgo). A Multi Commander forum report found `%OneDrive%` and `%OneDriveCommercial%` both pointing at the company folder, and argued that Windows does not use these variables to locate OneDrive. — [Multi Commander forum](https://forum.multicommander.com/forum/index.php/topic,3860.0/wap2.html). These variables also only carry one root per type, so they cannot represent Business2 and later accounts or synced SharePoint libraries (inference from the variable model).
- **Shell known folder.** `FOLDERID_SkyDrive` = `{A52BBA46-E9E1-435F-B3D9-28DAA648C0F6}`, display name "OneDrive", is listed for Windows 8.1 through Windows 11. — [winshl-kb known-folder entry](https://winshl-kb.readthedocs.io/en/latest/_sources/sources/known-folders/a52bba46-e9e1-435f-b3d9-28daa648c0f6.md.txt). One forum reply says `SHGetKnownFolderPath` with this GUID returned the correct path on Windows Server 2022. — [XYplorer forum](https://www.xyplorer.com/xyfc/viewtopic.php?p=206270). It resolves to a single "primary" OneDrive folder, not every account.
- **Synced SharePoint libraries [unverified].** Each library synced with the Sync button gets its own GUID subkey under `HKCU\Software\SyncEngines\Providers\OneDrive`, with `MountPoint` (local folder) and `UrlNamespace` (library URL). — [Microsoft Q&A: OneDrive Registry Sync Engine duplicate keys](https://learn.microsoft.com/en-us/answers/questions/5063782/onedrive-registry-sync-engine-duplicate-keys). The security tool Seatbelt's `CloudSyncProviders` command enumerates "all configured Office 365 endpoints (tenants and teamsites) that are synchronized by OneDrive" from these keys. — [SpecterOps Seatbelt docs](https://docs.specterops.io/ghostpack-docs/Seatbelt-mdx/commands/cloudsyncproviders)
- **Shortcuts vs Sync button.** Microsoft now recommends "Add shortcut to My files" over the library Sync button. Shortcuts sync only the chosen folder and live inside the user's OneDrive, so they appear under the OneDrive - <Company> root rather than as separate roots. Admins can hide the Sync button (`Set-SPOTenant -HideSyncButtonOnTeamSite $true`). — [Microsoft Learn: Recommended sync app configuration](https://learn.microsoft.com/en-us/sharepoint/ideal-state-configuration) (updated 2026-03-27)
- **Update cadence.** The sync app ships to the Production ring every 1-2 weeks and to Deferred every 2-3 months, and updates itself outside Office's update channel. Undocumented internals can therefore change frequently. — [Microsoft Learn: OneDrive sync app update process](https://learn.microsoft.com/en-us/sharepoint/sync-client-update-process) (ms.date 2026-07-27)

### Inferences
- **Recommended approach:**
  1. Call `GetCurrentSyncRoots()` through the `windows` crate. Keep roots whose `Id` begins with `OneDrive!`, take `Path` and `DisplayNameResource` for the label (for example "OneDrive - Personal", "OneDrive - Contoso"), and dedupe.
  2. Fall back to reading `HKLM\...\SyncRootManager\OneDrive!*\UserSyncRoots\<SID>` if WinRT activation fails.
  3. Use `HKCU\Software\Microsoft\OneDrive\Accounts\*` only as best-effort enrichment (Personal vs Business label, email).
  4. Treat the environment variables as a last-ditch fallback.
  5. Re-enumerate when a dialog opens, not at app start, because accounts can be added or unlinked while the app runs.
- Synced SharePoint libraries register as separate sync roots (each Sync-button library shows as its own Explorer node). The enumeration should therefore surface them too, and Aegean Office could group them under the tenant name the way Explorer does. This needs confirming on a machine with a synced library.
- Being purely local, this approach needs no Microsoft identity platform app registration or tenant admin consent. That is a big practical advantage for enterprise customers.

### Gaps
- No official Microsoft documentation of `Accounts\*` values (`DisplayName`, `ServiceEndpointUri`, `UserEmail`, `cid`) was found. Their existence and meaning are not confirmed by a primary source.
- No source confirmed the exact `Id` format OneDrive uses for its sync roots (e.g. `OneDrive!S-1-5-...!Business1|<guid>`). This needs inspection on a test machine.
- No source confirmed whether the WinRT `GetCurrentSyncRoots` works from an unpackaged (non-MSIX) desktop app without package identity. It is a static method and is generally expected to work, but this is unverified.

---

## 2. Mapping a local synced path back to its cloud URL / driveItem ("Share", "Open in browser")

### Takeaway
There is no documented public API that maps a OneDrive local path to its web URL or driveItem ID. The undocumented sources are the `SyncEngines\Providers\OneDrive\<guid>` registry keys (`MountPoint` paired with `UrlNamespace`) and, reportedly, the OneDrive settings ini files. Both are fragile; one Q&A report shows `MountPoint` pointing at the wrong library. The robust route to a share link or version history is Microsoft Graph, using the path relative to the root, and that needs sign-in. Office itself does not reverse-map paths: it knows the cloud identity of the document because it opens Office files through its own co-authoring integration with the sync client (section 6).

### Cited Findings
- `HKCU\Software\SyncEngines\Providers\OneDrive\<GUID>` keys hold `MountPoint` (local) and `UrlNamespace` (SharePoint library URL). A poster reports that "some of the MountPoints point to the incorrect namespace", with the registry wrong while the correct files synced. The thread is unanswered. — [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/5063782/onedrive-registry-sync-engine-duplicate-keys)
- Seatbelt enumerates tenant URLs and the sync folder locations behind them, confirming the data is locally readable. — [SpecterOps Seatbelt CloudSyncProviders](https://docs.specterops.io/ghostpack-docs/Seatbelt-mdx/commands/cloudsyncproviders)
- The Cloud Files platform supports a provider-registered **share handler**: "Cloud storage providers can register a share handler that will be invoked when the user selects the 'Share' command on a cloud file under their sync root". It is registered via a `ShareHandler` value (a CLSID of an `IExplorerCommand` COM local server) under the sync-root key, on Windows 11 21H2 and later. — [Microsoft Learn: Build a Cloud Sync Engine](https://learn.microsoft.com/en-us/windows/win32/cfapi/build-a-cloud-file-sync-engine)
- The `odopen://` URI scheme can make the OneDrive client *start syncing* a library, given siteId, webId, listId, userEmail and webUrl. This is community-documented, not the reverse mapping. — [undocumented-features.com](https://www.undocumented-features.com/2022/04/12/scripting-a-sharepoint-onedrive-or-teams-library-to-sync-with-the-onedrive-for-business-client/) **[older: 2022]**

### Inferences
- **Practical "Open in browser" without Graph:**
  1. Find the sync root containing the file (section 1).
  2. Look up that root's `UrlNamespace` in `SyncEngines\Providers\OneDrive`.
  3. Append the relative path, URL-encoded.

  This should work for SharePoint and OneDrive for Business (`https://<tenant>-my.sharepoint.com/personal/<user>/Documents/...`). Consumer OneDrive URLs are ID-based and probably cannot be built from a path. It is best-effort and must handle mismatches (verify `MountPoint` equals the root) and shortcut folders, whose cloud location belongs to a different site from the user's OneDrive root.
- **The share handler.** Because Windows 11 exposes a provider "Share" command for files under a sync root, invoking the shell's Share verb on the file may route to OneDrive's own share dialog. This would be the cheapest way to get the real OneDrive sharing UI from a third-party app. Whether it can be invoked programmatically (IContextMenu or IExplorerCommand enumeration on the item) is unverified; see section 6.
- For anything authoritative (driveItem ID, a sharing link created in-app, version list), plan on Graph: `GET /me/drive/root:/relative/path` for the user's own drive, or the site drive for libraries.

### Gaps
- No primary source on the `ClientPolicy*.ini` / `<account>.ini` files in `%LOCALAPPDATA%\Microsoft\OneDrive\settings` was found this session, so their contents are **[unverified]**.
- No source on how consumer OneDrive (personal) paths can be mapped to a web URL locally.

---

## 3. Files On-Demand / Cloud Files API behaviour for an app that opens and saves files

### Takeaway
On Windows, placeholders are transparent to normal apps. Opening a cloud-only file hydrates it automatically, through the cldflt.sys minifilter, with shell progress and toast UI, and apps need no code changes. The risks are in *how the app saves*. An atomic replace (`ReplaceFileW`, or `MoveFileExW` with `MOVEFILE_REPLACE_EXISTING`) is safe. A delete-then-rename save can be seen by OneDrive as a user delete and propagated. Conflicting edits produce duplicate copies with the computer name appended. Background enumeration or thumbnailing that reads file contents triggers hydration and a "this app is downloading files" toast that users can use to block the app.

### Cited Findings
- **Placeholders are transparent.** Placeholders "consume only 1 KB of storage for the filesystem header, and ... automatically hydrate into full files under normal use conditions". "Whether you use file system APIs, the Command Prompt, or a desktop or a UWP app to access a placeholder file, the file will hydrate without additional code changes". — [Microsoft Learn: Build a Cloud Sync Engine](https://learn.microsoft.com/en-us/windows/win32/cfapi/build-a-cloud-file-sync-engine)
- **Three file states.** Placeholder (online-only), Full (hydrated implicitly; can be dehydrated by the system), and Pinned full ("guaranteed to be available offline"). — [Microsoft Learn: Build a Cloud Sync Engine](https://learn.microsoft.com/en-us/windows/win32/cfapi/build-a-cloud-file-sync-engine)
- **Hydration policy.** At open time, policy = max(app hydration policy, provider hydration policy). Both sides default to progressive, and the policy cannot change after open. — [Microsoft Learn: Build a Cloud Sync Engine](https://learn.microsoft.com/en-us/windows/win32/cfapi/build-a-cloud-file-sync-engine)
- **Background hydration is user-controllable.** If a placeholder is opened not "at the user's specific instruction", a toast lets the user control it. "If a user blocks an app from hydrating files through an interactive toast, they can unblock the app in the Automatic file downloads page in Settings." — [Microsoft Learn: Build a Cloud Sync Engine](https://learn.microsoft.com/en-us/windows/win32/cfapi/build-a-cloud-file-sync-engine)
- **Reparse points are hidden from normal apps.** "The cloud files API always hides its reparse points from all applications except for sync engines and processes whose main image resides under %systemroot%". Apps can opt in to seeing them with `RtlSetProcessPlaceholderCompatibilityMode`. — [Microsoft Learn: Build a Cloud Sync Engine](https://learn.microsoft.com/en-us/windows/win32/cfapi/build-a-cloud-file-sync-engine)
- **Online-only state is visible through attributes.** Files expose `FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS` (0x400000), `FILE_ATTRIBUTE_RECALL_ON_OPEN` (0x40000), `FILE_ATTRIBUTE_PINNED` (0x80000), `FILE_ATTRIBUTE_UNPINNED` (0x100000) and `FILE_ATTRIBUTE_OFFLINE`. The values are from the Win32 file-attribute constants; that page was not re-fetched this session. — [Microsoft Learn: File Attribute Constants](https://learn.microsoft.com/en-us/windows/win32/fileio/file-attribute-constants)
- **Unsafe save pattern.** A bug report against an AI coding tool describes OneDrive-synced files being destroyed by a delete-then-rename save. OneDrive "sees the explicit delete event before the rename completes", "treats the operation as a user-initiated delete, propagates the delete to the cloud, and deletes the new local file to match the cloud state". The report recommends an atomic replace (`MoveFileEx` / `ReplaceFile`). This is a community report, not Microsoft documentation. — [claudeissues.com #65229](https://claudeissues.com/issue/65229-bug-edit-tool-silently-destroys-some-files-in-onedrive-synced-folders-via-non-de)
- **Conflict copies.** OneDrive keeps both versions and appends a suffix such as "-Copy", "(1)" or the device name, e.g. `Filename-DESKTOP-AB12.docx`. A common trigger is editing offline or before the latest cloud version has downloaded. This is a third-party/community explanation. — [Melbits KB](https://melbits.com.au/kb/why-does-onedrive-keep-duplicating-files); [Microsoft Q&A answer](https://learn.microsoft.com/en-us/answers/a/12388040)
- **Non-Office files get "keep both", not merge.** Microsoft's ideal-state doc says that when Office file collaboration is off, "when file conflicts occur, both versions of the file are kept". By implication, files not handled by Office's integration (which includes any third-party app's .xlsx/.docx/.pptx) get keep-both conflict handling. — [Microsoft Learn: Recommended sync app configuration](https://learn.microsoft.com/en-us/sharepoint/ideal-state-configuration)
- **Shell copy hooks.** Providers can register a shell copy hook (`IStorageProviderCopyHook`) to monitor file operations in their sync root (Build 19624+). This affects Explorer copy-engine operations, not an app's own CreateFile/WriteFile calls. — [Microsoft Learn: Build a Cloud Sync Engine](https://learn.microsoft.com/en-us/windows/win32/cfapi/build-a-cloud-file-sync-engine)

### Inferences
- **Save strategy for Aegean Office on Windows.** Write `name.~tmp` in the same folder, flush, then `ReplaceFileW(target, tmp, backup=NULL, REPLACE_FILE_IGNORE_MERGE_ERRORS)`. `ReplaceFileW` preserves the target's identity, ACLs and some attributes, which helps the sync engine treat the save as an *update* to the same item and keep version history continuous. Never delete the original first. Rust's `std::fs::rename` maps to `MoveFileExW(MOVEFILE_REPLACE_EXISTING)` on Windows, which is atomic but does not preserve file identity. Temp files should use a name OneDrive will not upload (OneDrive is known to skip `~$*` and `.tmp`, but no source for its exact exclusion list was found this session), or be created outside the root.
- **Placeholder etiquette.**
  - Do not read file contents for thumbnails or previews in Open dialogs and recent lists unless the file is hydrated; check `FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS` first. Otherwise Aegean Office risks the "app is downloading files" toast and being blocked by the user.
  - Show a cloud or "online-only" badge in the custom Open dialog based on these attributes.
  - Opening a cloud-only file may block for seconds. Do the read off the UI thread with a progress indicator.
- **Conflict detection.** Before saving, compare the file's mtime and size with what was read at open. If they changed (another device synced a newer version), prompt the user rather than silently overwriting; otherwise OneDrive will make a "-COMPUTERNAME" copy or silently overwrite. Also watch the folder for `name-<COMPUTERNAME>.ext` siblings appearing after save and tell the user.
- **Locking.** Keep files open only briefly (read fully, then close; on save, write the temp file and replace). A long-held exclusive handle on the document can block OneDrive uploads. Inferred from general sync-engine behaviour; no primary source found.

### Gaps
- No official Microsoft statement found on how the OneDrive engine treats `ReplaceFile` vs `MoveFileEx` saves, or on its temp-file exclusion list.
- No primary source on whether OneDrive holds locks on files while uploading on Windows, or whether a third-party app's write can fail with sharing violations during upload.

---

## 4. macOS: File Provider, ~/Library/CloudStorage, dataless files, sandbox

### Takeaway
On macOS 12.1 and later, OneDrive Files On-Demand runs on Apple's File Provider framework. The root moved from `~/OneDrive` to `~/Library/CloudStorage/...`, with an alias left at the old path, and Files On-Demand cannot be turned off. Online-only items are "dataless" files that the system materialises when read. A non-sandboxed, Developer ID-signed app can usually enumerate `~/Library/CloudStorage` and open files normally. Some sandboxed or restricted processes see `EDEADLK` ("Resource deadlock avoided") on dataless files. Microsoft is rolling out a redesigned **Native Sync Engine** for macOS (September to late November 2026) that changes how synced SharePoint libraries appear in the Finder sidebar.

### Cited Findings
- **Built-in Files On-Demand.** "Files On-Demand is built into macOS 12.1 and later and can't be turned off." Users can mark items "Always Keep on This Device". Only APFS is supported. — [Microsoft Support: Fix OneDrive Files On-Demand issues on macOS 12.1 or later](https://support.microsoft.com/onedrive/fix-onedrive-files-on-demand-issues-on-macos-12-1-or-later)
- **Path change.** OneDrive's location "moved to a new folder in the Library" (Library > Cloud Storage > OneDrive), and an alias was left in the old place. Pinned and Recent files may break, and "Office apps will not be able to AutoSave correctly" until the user re-saves to the new location. — [Microsoft Support: Missing files and autosave issues with OneDrive on macOS](https://support.microsoft.com/en-US/onedrive/missing-files-and-autosave-issues-with-onedrive-on-macos)
- **Dataless files.** File Provider uses "dataless files and folders" that hold only attributes. Data is downloaded when needed and the file is "materialised". Nonreplicated providers can evict local copies, and some providers offer pinning. — [Eclectic Light: Explainer: File Provider and cloud services (2026-05-09)](https://eclecticlight.co/2026/05/09/explainer-file-provider-and-cloud-services/)
- **Third-party read failures.** A sandboxed process could list FileProvider-backed folders (including OneDrive) and read metadata, but content reads failed with `EDEADLK` (errno 35, "Resource deadlock avoided"). "Blocks: 0 is a telltale sign of a dataless/dehydrated FileProvider file." — [claudeissues.com #40783](https://claudeissues.com/issue/40783-bug-file-read-failure-on-macos-fileprovider-backed-paths-google-drive-icloud-etc). Backup vendors report the same error on CloudStorage paths. — [Redstor helpdesk](https://helpdesk.redstor.com/support/solutions/articles/4000220036-1561-ese-error-on-macos-resource-deadlock-avoided-)
- **Discovery API caveat.** A sandboxed app found `NSFileProviderManager.getUserVisibleURL` returning nil for another provider's domain. The workaround was a security-scoped bookmark obtained via NSOpenPanel. — [Apple Developer Forums thread 719294](https://developer.apple.com/forums/thread/719294)
- **macOS Native Sync Engine (MC1458483).** Microsoft is shipping a redesigned "Native Sync Engine" for OneDrive on macOS. Rollout began in early September 2026 and is expected to complete by late November 2026; devices upgrade automatically.
  - Files On-Demand behaviour is unchanged.
  - "Each synced SharePoint library now appears as its own Finder sidebar location, rather than grouped under one organization entry."
  - Files are browsable immediately, and support for eligible external drives is better.
  - The new engine is recognisable by an alphabetic suffix on the version (e.g. "(26K)").
  - Microsoft recommends "Add shortcut to OneDrive" over Sync for shared content.
  - The notice does not describe any change to local paths.
  - [Microsoft 365 Message Center MC1458483 (via mc.merill.net)](https://mc.merill.net/message/MC1458483); [HANDS ON tek summary](https://m365admin.handsontek.net/onedrive-macos-native-sync-engine/)
- **Domain removal.** On macOS, removing a File Provider domain can keep downloaded files or files with unsynced changes if the provider chooses a removal mode. — [Apple: NSFileProviderManager](https://developer.apple.com/documentation/fileprovider/nsfileprovidermanager)

### Inferences
- **Discovery on macOS for a non-App-Store app.**
  1. List `~/Library/CloudStorage/` and take entries whose names begin with `OneDrive`. Commonly observed names are `OneDrive-Personal` and `OneDrive-<TenantName>`; no Microsoft page stating the naming scheme was found this session.
  2. Optionally confirm with `NSFileProviderManager.getDomainsWithCompletionHandler`. That only lists the calling app's own domains, so for a third-party app the directory listing is the practical method.
  3. Re-scan after the Native Sync Engine rollout, since SharePoint libraries may surface differently. Whether the on-disk folder names change is unknown.
- **Non-sandboxed Developer ID app.** Normal `open()`/`read()` on a dataless file should trigger materialisation. Ship Aegean Office outside the App Store, non-sandboxed, to avoid EDEADLK and bookmark complications. Still handle EDEADLK/EAGAIN gracefully with a "downloading from OneDrive..." retry, and do not read contents just to build thumbnails.
- **Safe save on macOS.** Use the same-volume temp file plus `rename()` (atomic), or `NSFileManager replaceItemAtURL`. File Provider sees a replace of the item, and the `-<ComputerName>` conflict copy behaviour presumably applies as on Windows. Unverified for OneDrive on macOS.
- **macOS privacy prompts.** Since macOS 14/15, apps may get a privacy prompt the first time they access another app's CloudStorage data. Unverified; no source found this session.

### Gaps
- No Apple or Microsoft source found confirming the exact folder naming in `~/Library/CloudStorage` for OneDrive personal vs business vs SharePoint libraries.
- No source found on whether the macOS 15/26 "access data from other apps" privacy prompt applies to `~/Library/CloudStorage/OneDrive-*` for non-sandboxed apps.
- No primary Microsoft documentation found for third-party save behaviour or conflict naming on macOS File Provider.

---

## 5. Linux: what a user can expect

### Takeaway
Microsoft ships no OneDrive client for Linux. Users rely on third parties: abraunegg/onedrive (open source, actively maintained; v2.5.x supports Business shared folders and SharePoint), rclone (sync or FUSE mount), Insync (commercial), or GNOME 46+ Online Accounts, which gives Nautilus a GVfs OneDrive backend with no sync and no offline access. None of these provides Files On-Demand-style placeholders through a standard OS API, or any machine-readable registry of "OneDrive roots". Detection on Linux is therefore heuristic.

### Cited Findings
- **abraunegg/onedrive.**
  - v2.5.10 is archived as of 30 January 2026. — [Fossies onedrive archive](https://fossies.org/onedrive/)
  - In v2.5.0, "OneDrive Business Shared Folder Sync has been 100% re-written", and v2.5.0 "is not backwards compatible". — [GitHub releases: abraunegg/onedrive](https://github.com/abraunegg/onedrive/releases)
  - Its usage docs are mirrored at [Fossies usage.md](https://fossies.org/linux/onedrive/docs/usage.md).
- **GNOME 46 (March 2024).** OneDrive support arrived via GNOME Online Accounts: choose the "Microsoft 365" account type in Settings > Online Accounts and OneDrive "will appear in the Files sidebar". It is a GVfs backend like Google Drive. Coverage notes there is no sync or offline support. — [OMG! Ubuntu: How to enable OneDrive in Ubuntu 24.04](https://www.omgubuntu.co.uk/2024/04/set-up-onedrive-file-access-in-ubuntu); [OMG! Ubuntu: OneDrive support planned in GVfs/GNOME 46](https://www.omgubuntu.co.uk/2024/02/onedrive-support-planned-gvfs-gnome-46); [AlternativeTo: GNOME 46 released](https://alternativeto.net/news/2024/3/gnome-46-kathmandu-released-wth-improved-search-files-app-and-online-accounts) **[older: 2024]**
- Coverage at launch did not say whether the GNOME integration works with work or school (Microsoft 365) accounts or only personal ones. — [Thurrott: OneDrive, Nautilus, and GNOME 46](https://www.thurrott.com/?p=297535) **[older: 2024]**

### Inferences
- **For Aegean Office on Linux:**
  - Offer a user-configurable "OneDrive folder" place, pre-filled heuristically: `~/OneDrive`, the abraunegg default `sync_dir`, the `sync_dir` from `~/.config/onedrive/config` if present, and rclone mounts parsed from `/proc/mounts` with fuse.rclone type and an onedrive remote.
  - GVfs OneDrive locations appear under `/run/user/$UID/gvfs/onedrive:*` and are reachable via a GIO-aware file dialog (the xdg-desktop-portal FileChooser). GVfs FUSE paths are slow and do not support atomic rename reliably. Treat them as remote and save via copy rather than rename. Unverified; no source.
  - Linux users get none of the conflict, hydration or co-authoring integration. Native Graph support would be most valuable on this platform.

### Gaps
- No 2026 source found on Insync's current OneDrive or SharePoint support, or on rclone's latest OneDrive backend changes.
- No source confirming whether GNOME's OneDrive backend gained business-account support or write and rename semantics after GNOME 46.
- No source found on KDE (KIO) OneDrive support status in 2026.

---

## 6. How Microsoft Office presents OneDrive, how AutoSave and co-authoring work from a synced folder, and what a third-party app cannot match

### Takeaway
Office's Backstage is backed by Microsoft cloud services, not by the sync folder:
- **Open** shows "Recent" files across all devices, "Shared with Me" (OneDrive/SharePoint only, Microsoft 365 subscription required), and cloud places added via "Add a Place" with sign-in.
- **AutoSave and co-authoring** for a file in a synced folder work because Office and the OneDrive sync app cooperate through the "Office file collaboration" / "Use Office applications to sync Office files that I open" integration. Office opens the file *as the cloud document*, saves differential changes directly, and merges co-authors' edits. The sync client then stands aside for that file. This setting has been on by default for all tenants since May 2025.

A third-party app editing the same file through the sync folder gets whole-file upload with "keep both" conflict copies, and no co-authoring, presence, AutoSave-to-cloud, in-app version history or in-app share dialog. On Windows 11 it can probably reach OneDrive's own Share UI through the shell's provider share handler, but that is unverified.

### Cited Findings
- **Backstage Open.** "The Open tab on the File menu shows your Recent files across devices and includes links to common locations you use to store files." — [Microsoft Support: Open files from the File menu](https://support.microsoft.com/en-us/office/collab-files/open-files-from-the-file-menu)
- **Shared with Me.**
  - "The Shared with Me list shows only documents saved to OneDrive or SharePoint Online." — [Microsoft Support: See files others have shared with you](https://support.microsoft.com/en-us/office/collab-files/excelexp/see-files-others-have-shared-with-you)
  - "This list is available if you have a Microsoft 365 subscription." — [Microsoft Support: See files shared with you](https://support.microsoft.com/en-us/office/see-files-shared-with-you-in-onedrive-2c14e8e6-4e52-4c61-9778-7155d33534a1)
- **Add a Place.** "If you don't see OneDrive - Personal in the list: Select Add a Place, then select OneDrive and sign into your Microsoft account." Office's places are therefore account-based connected services, not discovered folders. — [Microsoft Support: Upload and save files and folders to OneDrive](https://support.microsoft.com/en-us/onedrive/upload-and-save-files-and-folders-to-onedrive)
- **Bypassing Backstage.** Backstage can be skipped for Ctrl+O/Ctrl+S via File > Options > Save > "Don't show the Backstage when opening or saving files with keyboard shortcuts". — [Microsoft Support: Customize the save experience in Office](https://support.microsoft.com/en-us/office/customize-the-save-experience-in-office-786200a7-f5f2-4d26-a3ae-b78c60dd5d3b)
- **Office integration in the sync app.** Microsoft's guidance is "Keep Office file collaboration enabled. Office uses differential sync to sync only changes instead of the entire file each time." "As of May 2025, the coauthoring and in-app sharing of Office files setting is enabled by default for all tenants. If this setting is disabled, Office file collaboration is turned off, and when file conflicts occur, both versions of the file are kept." — [Microsoft Learn: Recommended sync app configuration](https://learn.microsoft.com/en-us/sharepoint/ideal-state-configuration)
- **User-side setting.** The setting is "Use Office applications to sync Office files that I open", on the Office tab of OneDrive Settings (Windows) or Preferences (Mac). — [SFU IT KB: OneDrive Fixing Sync Conflict Issues](https://sfu.teamdynamix.com/TDClient/255/ITServices/KB/ArticleDet?ID=3817). Disabling it "breaks all the collaboration features and live editing" (community claim). — [Microsoft Tech Community reply](https://techcommunity.microsoft.com/discussions/onedriveforbusiness/onedrive-date-modified-without-changing-the-file/367066/replies/715491)
- **Tenant setting and AutoSave.** Co-authoring from synced files can also fail if the tenant setting "Coauthor and share in Office desktop apps" is disabled, or if AutoSave is off. These are Microsoft Q&A moderator and community answers. — [Microsoft Q&A: Is Sync to OneDrive causing our Office collaboration features not to work correctly?](https://learn.microsoft.com/en-us/answers/questions/5111956/is-sync-to-onedrive-causing-our-office-collaborati); [Microsoft Q&A: OneDrive merge conflicts when collaborating on the desktop Office apps](https://learn.microsoft.com/en-us/answers/questions/5180613/onedrive-merge-conflicts-when-collaborating-on-the)
- **AutoSave depends on Office recognising the cloud location.** When the macOS root moved to Library/CloudStorage, Office could not AutoSave until the user re-saved to the new location. — [Microsoft Support: Missing files and autosave issues with OneDrive on macOS](https://support.microsoft.com/en-US/onedrive/missing-files-and-autosave-issues-with-onedrive-on-macos)
- **Known failure modes of the Office path.** "Upload blocked" and merge conflicts are known failure modes even for Office itself. Typical remedies are resetting OneDrive and clearing the Office file cache. — [Microsoft Q&A: Coauthoring in Excel random sync issues](https://learn.microsoft.com/en-us/answers/questions/5233441/coauthoring-in-excel-random-sync-issues-(upload-bl)
- **Programmatic access to OneDrive's context-menu verbs.** Shell context-menu items can be invoked programmatically by *canonical verb* via `IContextMenu::GetCommandString`/`InvokeCommand`. If a handler supplies no canonical verb, matching by display text is fragile and localised. — [The Old New Thing: canonical verb names](https://devblogs.microsoft.com/oldnewthing/?p=95635); [Microsoft Learn: IContextMenu::InvokeCommand](https://learn.microsoft.com/el-gr/windows/win32/api/shobjidl_core/nf-shobjidl_core-icontextmenu-invokecommand). Windows 11's modern context menu uses `IExplorerCommand`. — [Microsoft Learn: Integrate a packaged app with File Explorer](https://learn.microsoft.com/en-my/WINDOWS/APPS/desktop/modernize/integrate-packaged-app-with-file-explorer)
- **Provider share handler.** Sync-root providers can register a share handler (`ShareHandler` CLSID implementing `IExplorerCommand`) that is "invoked when the user selects the 'Share' command on a cloud file under their sync root" (Windows 11 21H2+). — [Microsoft Learn: Build a Cloud Sync Engine](https://learn.microsoft.com/en-us/windows/win32/cfapi/build-a-cloud-file-sync-engine)

### Inferences
- **Office vs the sync folder.** Office talks to the cloud document directly for Office files, and the sync client defers to it. This is consistent with Microsoft describing the feature as Office doing "differential sync" and with "in-app sharing". No Microsoft page found this session describes the protocol, believed to be FSSHTTP/MS-FSSHTTP cell storage with WOPI-style locks; treat that as **[unverified]**. A third-party app cannot join this integration: it is private between Office and OneDrive.
- **What Aegean Office cannot match via the sync folder alone:**
  - Real-time co-authoring and presence.
  - Differential cloud saves and server-side merge; Aegean Office gets whole-file upload and keep-both conflict copies instead.
  - AutoSave semantics. Aegean Office can autosave locally and let OneDrive upload, but conflicts become duplicate files.
  - Cloud "Recent across devices" and "Shared with Me".
  - Not-yet-synced libraries: browsing them, or adding a SharePoint site as a place.
  - In-app version history and restore.
  - An in-app share dialog with link settings.
  - Sensitivity labels and their enforcement.
  - Check-in/check-out, and required metadata columns in SharePoint libraries.

  Every one of these needs Microsoft Graph, and some (co-authoring) cannot be done with Graph either.
- **What Aegean Office can match cheaply:**
  - "OneDrive - Personal" and "OneDrive - <Company>" places in Open and Save As, using sync-root enumeration and display names.
  - Cloud-state badges from file attributes.
  - Local recent files.
  - Graceful hydration.
  - Safe atomic save.
  - Conflict-copy detection.
  - "Open in browser" via the `UrlNamespace` heuristic (business accounts).
  - Possibly OneDrive's own Share and Version history UI, by invoking OneDrive's Explorer verbs on the file. That would need enumerating `IContextMenu`/`IExplorerCommand` for the item and matching a canonical verb. No source documents OneDrive's verb names, so it would need empirical testing, with a fallback to "Show in Explorer" (`SHOpenFolderAndSelectItems`) so users can right-click the file there themselves.
- **Positioning.** The sync-folder approach is reliable for *file access* (and safe if the save pattern is right) but delivers "Dropbox-like" OneDrive support, not "Office-like". It is a good phase 1. Graph (Recent, Shared, share links, versions) is phase 2. True co-authoring is out of reach for a non-Microsoft editor on .docx/.xlsx/.pptx in the desktop app. That last point is an inference: no public API for desktop co-authoring participation was found this session.

### Gaps
- No Microsoft primary source found that explicitly documents the mechanism by which Office bypasses the sync client for open Office files.
- No documentation found of OneDrive's shell verb canonical names ("Share", "View online", "Version history", "Manage access"), or of whether they can be invoked from another process. This needs empirical testing on Windows 11.
- No source found on whether OneDrive's "Version history" dialog can be launched for a path via a command-line switch or URI. `OneDrive.exe /url` is unverified; only `odopen://` for starting library sync is community-documented.
- No source found comparing Office for Mac's behaviour with the new macOS Native Sync Engine (autumn 2026) for AutoSave.
