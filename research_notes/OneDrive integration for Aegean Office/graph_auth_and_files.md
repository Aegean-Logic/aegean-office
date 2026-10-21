# Microsoft Graph sign-in and OneDrive file APIs for a third-party native desktop office suite (state as of 19 October 2026)

Scope: what Microsoft Graph and the Microsoft identity platform offer a Rust/egui desktop app (plus WASM web editors) that wants the same operations as the existing Nextcloud backend: sign in/out, list folder, open (download to cache), save as/upload, conflict detection, recent files, shared with me. Most sources are Microsoft Learn pages. Their `updated_at` dates (2025-2026) are given where they matter. Anything older or possibly superseded is marked.

---

## Q1. App registration and sign-in for a public-client desktop app (PKCE + loopback vs device code, "common" authority, scopes, refresh tokens, Rust libraries, WAM)

### Takeaway
Register one Entra app as "Mobile and desktop applications" with a loopback redirect (`http://localhost` or, as Microsoft prefers, `http://127.0.0.1`). Use auth code + PKCE in the system browser, and offer device code as a fallback. Set the sign-in audience to work/school plus personal accounts and use the `/common` authority. Refresh tokens default to 90 days for non-SPA clients. Microsoft ships no MSAL for Rust, and the official `azure_identity` crate (v1.0.0) has no interactive or device-code user credential. Rust apps must either implement the OAuth protocol themselves (for example with the `oauth2` crate) or use a community crate. WAM is optional: it is a Windows-only broker reached through MSAL, and it needs a different redirect URI.

### Cited Findings
**Redirect URIs and platform**
- For desktop apps using system browsers, Microsoft says to add the "Mobile and desktop applications" platform with the exact value `http://localhost`. Embedded browsers use `https://login.microsoftonline.com/common/oauth2/nativeclient`. Per that page, WAM apps need no redirect URI in MSAL — [Microsoft Learn: Configure desktop apps](https://learn.microsoft.com/en-us/entra/identity-platform/scenario-desktop-app-registration)
- Device code flow, integrated Windows auth and ROPC need **"Allow public client flows" = Yes** under Authentication > Advanced settings — [Microsoft Learn: Configure desktop apps](https://learn.microsoft.com/en-us/entra/identity-platform/scenario-desktop-app-registration)
- Loopback rules (RFC 8252):
  - `http` is allowed only for localhost.
  - **The port is ignored when matching localhost redirect URIs**, so an ephemeral port is fine.
  - Don't register several localhost URIs that differ only in port.
  - IPv6 `[::1]` "isn't currently supported".
  - Microsoft says to "Prefer 127.0.0.1 over localhost" to avoid firewall/interface problems. An `http://127.0.0.1` URI can't be typed into the portal box; it has to be added through the app manifest `replyUrlsWithType`.
  - Source: [Microsoft Learn: Redirect URI best practices](https://learn.microsoft.com/en-us/entra/identity-platform/reply-url) (page updated 2026-06-15)
- Apps whose audience includes personal Microsoft accounts (`AzureADandPersonalMicrosoftAccount`):
  - Limited to **100 redirect URIs**, versus 256 for work/school only.
  - **No query parameters** allowed in redirect URIs.
  - **No wildcard redirect URIs**.
  - Source: [Microsoft Learn: Redirect URI best practices](https://learn.microsoft.com/en-us/entra/identity-platform/reply-url)

**Device code**
- Endpoint: `POST https://login.microsoftonline.com/{tenant}/oauth2/v2.0/devicecode`. `tenant` can be `/common`, `/consumers`, `/organizations` or a tenant ID.
- The default `expires_in` is 15 minutes. The client polls `/token` every `interval` seconds.
- A refresh token is issued only when `offline_access` is in the scope.
- Personal-account users signing in via `/common` or `/consumers` are asked to sign in again to transfer state.
- `verification_uri_complete` is not supported.
- Source: [Microsoft Learn: OAuth 2.0 device authorization grant](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code)

**Refresh tokens**
- Default refresh token lifetime: **24 hours** for SPAs and for email-OTP flows, **90 days for all other scenarios**.
- Refresh tokens "replace themselves with a fresh token upon every use". The old one isn't revoked, so the app should delete it securely.
- Refresh tokens are bound to user and client, not to a resource or tenant.
- The server can revoke them early: password change for password-based tokens, a user or admin revoking all tokens, and so on. Apps must fall back to interactive sign-in.
- Source: [Microsoft Learn: Refresh tokens](https://learn.microsoft.com/en-us/entra/identity-platform/refresh-tokens) (updated 2026-06-15)
- Refresh tokens sent to a redirect URI of type `spa` expire after 24 hours, and so do any refresh tokens acquired from them. A WASM browser editor registered as SPA must redo an interactive or silent top-level auth every 24 hours — [Microsoft Learn: Refresh tokens](https://learn.microsoft.com/en-us/entra/identity-platform/refresh-tokens)

**Scopes** (delegated; "AdminConsentRequired" values from the permissions reference)
| Scope | Meaning | Admin consent required |
| --- | --- | --- |
| Files.Read | read signed-in user's files | No |
| Files.ReadWrite | read, create, update and delete the signed-in user's files | No |
| Files.Read.All | read all files the user can access | No |
| Files.ReadWrite.All | read/write all files the user can access | No |
| Files.ReadWrite.AppFolder | (Preview) app's own folder only | No |
| Files.SelectedOperations.Selected | only files explicitly permissioned to the app in SPO/OneDrive | Yes |

Source: [Microsoft Learn: Graph permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference). "Admin consent required = No" is the static flag. The Microsoft-managed user-consent policy now blocks user consent to Files.Read.All and Files.ReadWrite.All by default; see Q2.

- Least-privileged scope per operation:
  - Upload: Files.ReadWrite — [Upload small files](https://learn.microsoft.com/en-us/graph/api/driveitem-put-content?view=graph-rest-1.0)
  - Upload session: Files.ReadWrite — [createUploadSession](https://learn.microsoft.com/en-us/graph/api/driveitem-createuploadsession?view=graph-rest-1.0)
  - Delta: Files.Read — [delta](https://learn.microsoft.com/en-us/graph/api/driveitem-delta?view=graph-rest-1.0)
  - Thumbnails: Files.Read — [thumbnails](https://learn.microsoft.com/en-us/graph/api/driveitem-list-thumbnails?view=graph-rest-1.0)
  - These apply to both work/school and personal accounts.
- `sharedWithMe` "succeeds with `Files.Read` or `Files.ReadWrite` permissions; however, some properties might be missing". Also: "You can't access shared items returned from this API if the request doesn't contain one of the `*.All` permissions." — [drive: sharedWithMe](https://learn.microsoft.com/en-us/graph/api/drive-sharedwithme?view=graph-rest-1.0)

**Libraries / Rust**
- Microsoft lists desktop MSAL libraries for .NET, Java, macOS (Obj-C/Swift), Node/Electron (public preview) and Python. **No Rust library is listed** — [Microsoft Learn: Configure desktop apps](https://learn.microsoft.com/en-us/entra/identity-platform/scenario-desktop-app-registration)
- The official `azure_identity` crate is at **v1.0.0** and exports only:
  - `AzureCliCredential`, `AzureDeveloperCliCredential`, `AzurePipelinesCredential`
  - `ClientAssertionCredential`, `ClientCertificateCredential`, `ClientSecretCredential`
  - `DeveloperToolsCredential`, `ManagedIdentityCredential`, `WorkloadIdentityCredential`

  It has **no InteractiveBrowserCredential or DeviceCodeCredential**, so it isn't usable for end-user sign-in in a shipped desktop app — [docs.rs azure_identity](https://docs.rs/azure_identity/latest/azure_identity/)
- Community Rust options:
  - **`graph-rs-sdk` / `graph-oauth`** (v3.0.x): supports auth code, client credentials and device code flows, plus an optional `interactive-auth` feature that uses a wry webview. The docs.rs build for graph-oauth 3.0.0 failed, so treat it as unverified — [docs.rs graph-oauth](https://docs.rs/graph-oauth); [docs.rs graph-rs-sdk](https://docs.rs/graph-rs-sdk)
  - **`msal` crate**: a stub pointing to **libhimmelblau**, which implements MSAL-like PublicClientApplication APIs and MS-OAPXBC PRT flows. It is aimed at Linux Entra device join, not desktop apps — [docs.rs msal](https://docs.rs/msal); [libhimmelblau](https://github.com/himmelblau-idm/libhimmelblau)
  - **`msal-rs`** v0.1.2: about 800 days since the last release, likely unmaintained — [crates.io msal-rs](https://crates.io/crates/msal-rs)

**WAM (Windows broker)**
- WAM ships with Windows 10 1703+ and Windows Server 2019+. MSAL "will automatically fallback to a browser if WAM cannot be used". WAM "supports only Microsoft Entra ID" and has no third-party IdPs.
- On Mac, Linux and older Windows, MSAL falls back to the browser.
- The WAM redirect URI is `ms-appx-web://microsoft.aad.brokerplugin/{client_id}`, registered under Mobile and desktop applications.
- With an authority that includes personal accounts, WAM shows the Windows system account picker.
- Benefits: Windows Hello/FIDO, Conditional Access support, and **Token Protection** (device-bound refresh tokens, PoP tokens).
- Requires an interactive user session with a parent window handle.
- Source: [Microsoft Learn: MSAL.NET with WAM](https://learn.microsoft.com/en-us/entra/msal/dotnet/acquiring-tokens/desktop-mobile/wam) (updated 2025-08-08)

### Inferences
- **Recommended registration:**
  - One multi-tenant + personal-account registration (`signInAudience = AzureADandPersonalMicrosoftAccount`) with the `/common` authority.
  - Redirect `http://127.0.0.1` via the manifest, or `http://localhost`, on the Mobile and desktop platform.
  - "Allow public client flows" = Yes so device code works too.
  - No client secret, since it's a public client.
  - Scopes: `openid profile offline_access User.Read Files.ReadWrite`. Request `Files.ReadWrite.All` incrementally only when the user opens Shared with me or another drive (see Q2).
- **Rust:** the most maintainable path is a hand-written auth code + PKCE loopback flow using the general-purpose `oauth2` crate (or plain `reqwest`), with refresh tokens kept in the OS keychain (e.g. the `keyring` crate). Microsoft publishes the protocol docs for programming directly against it. This mirrors how the Nextcloud login flow is presumably already done. I did not verify the `oauth2` crate's current version or feature list in this research.
- **WAM is not required.** Microsoft gives no direct WAM API for non-MSAL apps in these docs, so using WAM from Rust would mean FFI to MSAL's native runtime or the WinRT `WebAuthenticationCoreManager`. That is high effort. The main thing lost without WAM is Token Protection: tenants that enforce Token Protection Conditional Access would block a browser-flow app. That is an inference from the WAM page and was not verified against current CA docs.
- **WASM editors:** an SPA registration means a 24-hour refresh token cap. A token broker served by the desktop app or a server-side component would avoid that, but it changes the public-client model.

### Gaps
- No primary source confirmed whether Microsoft recommends tenants block the device code flow by default. Tenant admins can block it with Conditional Access "authentication flows" policies (not fetched). Device code should be treated as a fallback that may be blocked in some tenants.
- I did not fetch the `oauth2` crate docs. Its PKCE/device-code support is from general knowledge and should be confirmed.
- The refresh token lifetime for personal Microsoft accounts is not separately documented on the page fetched; it lists 90 days for "all other scenarios".

---

## Q2. Admin consent, default user-consent settings after 2025 changes, publisher verification

### Takeaway
Since mid-2025, Microsoft-managed default consent no longer lets ordinary users in work tenants consent to **Files.Read.All / Files.ReadWrite.All / Sites.*.All**. Later rounds (Nov 2025, Jun-Jul 2026) added mail, calendar, chat, contacts, tasks and People permissions. **Files.Read / Files.ReadWrite (own files) are not on the excluded list**, so users can still self-consent to own-drive access in default tenants. Publisher verification is free but needs a verified Microsoft AI Cloud Partner Program (formerly MPN) Partner Global Account and a custom-domain Entra tenant. Without it, unverified multi-tenant apps get warnings and are blocked from user consent in tenants that enable risk-based step-up consent or the "verified publishers only" policy. A multi-tenant app can still be registered and used without verification.

### Cited Findings
**Microsoft-managed policy (`microsoft-user-default-recommended`)**
- This policy, labelled "Let Microsoft manage your consent settings", is "**the default for a new tenant**" and "will update with Microsoft's latest recommended default consent settings". Its conditions "are automatically updated" — [Microsoft Learn: Manage app consent policies](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/manage-app-consent-policies) (updated 2026-08-28)
- Current rules: end users can consent to any user-consentable delegated permission EXCEPT, for Microsoft Graph:
  - Files/Sites: `Files.Read.All`, `Files.ReadWrite.All`, `Sites.Read.All`, `Sites.ReadWrite.All`
  - Mail: `Mail.Read`, `Mail.ReadWrite`, `Mail.ReadBasic`, `Mail.Read.Shared`, `Mail.ReadBasic.Shared`, `Mail.ReadWrite.Shared`, `MailboxItem.Read`
  - Calendars: `Calendars.Read`, `Calendars.ReadBasic`, `Calendars.ReadWrite`, `Calendars.Read.Shared`, `Calendars.ReadWrite.Shared`
  - Chat and meetings: `Chat.Read`, `Chat.ReadWrite`, `OnlineMeetings.Read`, `OnlineMeetings.ReadWrite`
  - Mailbox: `MailBoxFolder.Read`, `MailBoxFolder.ReadWrite`, `MailBoxSettings.Read`, `MailBoxSettings.ReadWrite`
  - Contacts: `Contacts.ReadWrite`, `Contacts.Read.Shared`, `Contacts.ReadWrite.Shared`
  - Tasks: `Tasks.Read`, `Tasks.Read.Shared`, `Tasks.ReadWrite`, `Tasks.ReadWrite.Shared`
  - `People.Read`

  For Exchange Online, the exceptions are EAS/EWS/IMAP/POP `AccessAsUser.All` — [Microsoft Learn: Manage app consent policies](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/manage-app-consent-policies)
- Timeline:
  - **MC1097272** announced the Files/Sites block. Rollout started mid-July 2025, with all tenants expected by August 2025. Tenants with custom consent settings were not affected, and existing grants remain — [AppGovScore on MC1097272](https://www.appgovscore.com/blog/microsoft-disables-user-consent-by-default-are-you-ready-for-mc1097272); [Office365ITPros, 2025-06-19](https://office365itpros.com/2025/06/19/app-consent-policy-user-app-consent/); [mattchatt (16 July start)](https://mattchatt.co.za/upcoming-change-to-entra-app-consent-defaults-what-admins-need-to-know-before-july-16/)
  - Topedia gives these dates: Files/Sites exclusions "August 2025"; mail/calendar/chat/Exchange "November 2025"; then Contacts.ReadWrite, Contacts.Read.Shared, Contacts.ReadWrite.Shared, People.Read and the four Tasks.* scopes "June 2026", with rollout "completed by July 2026" — [Topedia, 2026-05](https://blog.topedia.com/2026/05/microsoft-managed-default-app-consent-policy-will-block-8-additional-permissions/); [Topedia, 2025-11](https://blog-en.topedia.com/2025/11/microsoft-managed-default-app-consent-policy-now-blocks-20-additional-permissions/). These are secondary blogs; the excluded list itself is confirmed on Microsoft Learn above.
  - Microsoft's docs say updates to the managed policy get at least 30 days' notice. This was seen only via a search summary of the Azure China mirror — [docs.azure.cn mirror](https://docs.azure.cn/en-us/entra/identity/enterprise-apps/manage-app-consent-policies)
- Other built-in policies:
  - `microsoft-user-default-low`: "Allow user consent for apps from **verified publishers**, for selected permissions" (low-impact classified only).
  - `microsoft-user-default-legacy`: allow consent to any non-admin permission for any app.
  - Changes to consent settings affect only future consents. Admins can enable an **admin consent workflow** so users can request approval.
  - Source: [Microsoft Learn: Configure user consent](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/configure-user-consent) (updated 2026-08-04)
- Apps that require user assignment always need admin consent — [Microsoft Learn: Configure user consent](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/configure-user-consent)
- A Mail client policy (`microsoft-user-default-allow-consent-apps`) lets users consent to mail scopes for Apple Mail, Spark, eM Client, Samsung/Android Mail and Thunderbird. Microsoft keeps an allow-list of popular third-party clients for mail, but nothing comparable for Files is documented — [Microsoft Learn: Manage app consent policies](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/manage-app-consent-policies)

**Publisher verification**
- A verified app gets a blue "verified" badge in the consent prompt. It requires:
  - A **Partner One ID** for a verified **Microsoft AI Cloud Partner Program** (formerly MPN) account. It must be the Partner Global Account (PGA); location IDs aren't supported.
  - The app registered with a work/school account (apps registered with an MSA can't be verified) in a tenant linked to the PGA.
  - A **publisher domain** that is not `*.onmicrosoft.com` and matches the partner email domain or a DNS-verified custom domain.
  - The person verifying holds Application Admin or Cloud App Admin plus a Partner Center role, and signs in with MFA.
  - Acceptance of the identity platform Terms of Use.
  - Source: [Microsoft Learn: Publisher verification overview](https://learn.microsoft.com/en-us/entra/identity-platform/publisher-verification-overview) (updated 2026-06-15)
- Cost: "Microsoft doesn't charge developers for publisher verification. No license is required." — [Microsoft Learn: Publisher verification overview](https://learn.microsoft.com/en-us/entra/identity-platform/publisher-verification-overview)
- Without verification: "Beginning November 2020, if risk-based step-up consent is enabled, users can't consent to most newly registered multitenant apps that aren't publisher verified". This covers apps registered after **8 Nov 2020** that ask for more than basic sign-in/profile in other tenants. A warning says the app is from an unverified publisher and "is risky" — [Microsoft Learn: Publisher verification overview](https://learn.microsoft.com/en-us/entra/identity-platform/publisher-verification-overview)
- Publisher verification is **not supported in national clouds** — [Microsoft Learn: Publisher verification overview](https://learn.microsoft.com/en-us/entra/identity-platform/publisher-verification-overview)
- Microsoft 365 App Certification and Publisher Attestation are separate, complementary programs built on top of verification — [Microsoft Learn: Publisher verification overview](https://learn.microsoft.com/en-us/entra/identity-platform/publisher-verification-overview)

### Inferences
- **Practical consent picture for Aegean Office in a default work tenant (Oct 2026):**
  - `User.Read` + `Files.ReadWrite` + `offline_access` remains user-consentable. That is enough for sign-in, browse, open and save in the user's own OneDrive.
  - `Files.ReadWrite.All` (needed to open or save files shared from other users' drives or SharePoint libraries) now needs an admin, either through tenant-wide consent or the admin consent workflow.
  - Design around incremental consent: ask for `.All` only when the user first opens "Shared with me" or another person's file, and show clear text explaining that an IT admin may need to approve.
- **Publisher verification is strongly advisable** for Aegean Logic. Without it, tenants on `microsoft-user-default-low` or with risk-based step-up consent will block even `Files.ReadWrite`, and users see an "unverified" warning. Aegean Logic needs a Partner Center (AI Cloud Partner Program) account verified for the company (free) and the app registered in a tenant whose custom domain is aegeanlogic.co.uk.
- Personal Microsoft accounts are not subject to Entra tenant consent policies, so personal OneDrive users can consent to `Files.ReadWrite.All` themselves. This is inferred from the policies being tenant-scoped and was not explicitly documented in the sources fetched.

### Gaps
- I could not fetch the Message Center post MC1097272 itself, only secondary summaries. The exact July vs August 2025 dates differ between secondary sources.
- I found no Microsoft statement on whether Microsoft might later add `Files.ReadWrite` (non-.All) to the managed exclusion list. The 30-day notice rule means it could change.
- What a personal-account user sees for an unverified app (any warning text) wasn't confirmed.

---

## Q3. Files APIs: list, download, upload (small vs session), conflictBehavior, eTag/cTag, If-Match, delta, thumbnails; personal vs business differences

### Takeaway
Graph v1.0 covers every needed file operation:
- List: `children`.
- Download: `/content` or the pre-authenticated `@microsoft.graph.downloadUrl`, valid about 1 hour.
- Small upload: `PUT .../content`, now documented up to **250 MB**.
- Resumable upload: `createUploadSession`, with fragments that are multiples of **320 KiB**, under **60 MiB** per request, 5-10 MiB recommended.
- Optimistic concurrency: `if-match` with the eTag/cTag returns **412 Precondition Failed** on mismatch.
- Change tracking: `delta`, with 410 resync semantics.
- Thumbnails: `thumbnails`, including `$expand`, which doesn't work on business drives.

There are several OneDrive Personal vs Business differences.

### Cited Findings
**Item model**
- Items are addressed by ID (`/drives/{drive-id}/items/{item-id}`) or path (`/drive/root:/path/to/file`) — [driveItem resource](https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-1.0) (updated 2026-10-08)
- **eTag** = "eTag for the entire item (metadata + content)". **cTag** = "An eTag for the content of the item. This eTag isn't changed if only the metadata is changed." cTag isn't returned for folders, and in OneDrive for Business/SharePoint cTag isn't returned for any item with a folder facet. On folders, cTag changes when any descendant changes, and eTag changes only when the folder's own properties change — [driveItem resource](https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-1.0)
- `@microsoft.graph.downloadUrl`: "Authentication isn't required with this URL". It is short-lived, "can't be cached" and is invalidated after about **1 hour**. Removing permissions may not immediately invalidate it — [driveItem resource](https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-1.0)
- `@microsoft.graph.conflictBehavior`: `fail`, `replace` or `rename`. "The default for PUT is *replace*". It "should be included in the URL instead of the body" — [driveItem resource](https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-1.0)
- Personal-only properties: `audio`, `description`. `@microsoft.graph.sourceUrl` upload isn't supported on OneDrive for Business/SharePoint — [driveItem resource](https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-1.0)
- The method list includes List versions, Copy (async, long-running), Search, Track changes (delta), Get WebSocket channel (socket.io change notifications), Preview, **Check in / Check out / Discard checkout**, sensitivity labels and retention labels — [driveItem resource](https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-1.0)

**Small upload**
- `PUT /drives/{drive-id}/items/{item-id}/content` replaces a file. `PUT /drives/{drive-id}/items/{parent-id}:/{filename}:/content` creates one. "This method only supports files up to **250 MB** in size." Least privilege is Files.ReadWrite — [Upload small files](https://learn.microsoft.com/en-us/graph/api/driveitem-put-content?view=graph-rest-1.0) (updated 2026-08-11)
- The current small-upload page doesn't document `if-match` or `conflictBehavior` request options. Those are documented on the driveItem resource and the upload-session page instead — [Upload small files](https://learn.microsoft.com/en-us/graph/api/driveitem-put-content?view=graph-rest-1.0)
- Replacing a file protected by a sensitivity label isn't supported with app-only auth. Delegated auth works — [Upload small files](https://learn.microsoft.com/en-us/graph/api/driveitem-put-content?view=graph-rest-1.0)

**Upload session** — all from [createUploadSession](https://learn.microsoft.com/en-us/graph/api/driveitem-createuploadsession?view=graph-rest-1.0) (updated 2026-08-11) unless noted
- Endpoints:
  - New file: `POST /drives/{driveId}/items/{parentItemId}:/{fileName}:/createUploadSession`
  - Existing file: `POST /drives/{driveId}/items/{itemId}/createUploadSession`
- Request headers: **`if-match: <etag or ctag>` returns `412 Precondition Failed` if the item's current eTag doesn't match**. `if-none-match` does the reverse.
- Body:
  - `item.@microsoft.graph.conflictBehavior` = `fail` (default) | `replace` | `rename`
  - `deferCommit` (bool)
  - `fileSize` and `description` work only on OneDrive Personal. If `fileSize` exceeds quota, the response is `507 Insufficient Storage`.
- Fragments:
  - PUT to `uploadUrl` with `Content-Range`. Each request must be under **60 MiB**.
  - Every fragment except the last "**MUST** be a multiple of 320 KiB (327,680 bytes)".
  - Upload sequentially. Use the session expiry `expirationDateTime`, which each fragment extends. Resume with `nextExpectedRanges` (GET on `uploadUrl`). Cancel with DELETE.
  - **Don't send the Authorization header on the PUT** to `uploadUrl`; it may cause a 401.
- `deferCommit` completion differs by service: OneDrive for Business/SharePoint completes with a zero-length POST, OneDrive Personal with a final PUT.
- Best practice:
  - Use sessions for files over **10 MiB**, with fragments of 5-10 MiB.
  - Use exponential back-off on 5xx. On 404, restart the upload.
  - A name conflict at commit returns `409 nameAlreadyExists`. Recover by PUT with `@microsoft.graph.sourceUrl` = session URL, plus `if-match` and conflictBehavior.

**Delta** — all from [driveItem: delta](https://learn.microsoft.com/en-us/graph/api/driveitem-delta?view=graph-rest-1.0) (updated 2026-06-06)
- `GET /drives/{drive-id}/root/delta`. Follow `@odata.nextLink` until `@odata.deltaLink` appears.
- `?token=latest` returns only a fresh deltaLink.
- Timestamp tokens (`?token=2021-09-29T20%3A00%3A00Z`) work "only on OneDrive for Business and SharePoint".
- `410 Gone` comes with `resyncChangesApplyDifferences` or `resyncChangesUploadDifferences` plus a `Location` header that starts a fresh enumeration.
- The feed shows latest state, not every change, and items can repeat. `parentReference.path` is not returned, so "always track items by id".
- Omitted properties:
  - OneDrive for Business: `ctag` on create/modify; `ctag` and `name` on delete.
  - Consumer: `ctag` and `size` on delete.
- The `deltaExcludeParent` header and `Prefer: hierarchicalsharing` are available. `deltashowsharingchanges` is for business only and needs Sites.FullControl.All.
- "Using delta is the only way to guarantee" a full enumeration; paging `children` may miss items during writes.

**Thumbnails** — all from [List thumbnails](https://learn.microsoft.com/en-us/graph/api/driveitem-list-thumbnails?view=graph-rest-1.0)
- Endpoints: `GET /drives/{id}/items/{id}/thumbnails`, `.../thumbnails/{thumb-id}/{size}` and `.../content`, which redirects (302) to the image.
- Sizes:
  - `small` 96, `medium` 176, `large` 800
  - `smallSquare`, `mediumSquare`, `largeSquare`
  - Custom `c300x400` or `c300x400_crop`
- Thumbnail URLs "are cache-safe" and change when the item changes.
- `children?$expand=thumbnails` and `expand=children(expand=thumbnails)` **"will not work" in OneDrive for Business and SharePoint**. `originalOrientation=true` works only on OneDrive Personal.

**Other**
- Graph has a "Get WebSocket channel" (socket.io) for near-real-time drive change notifications. Subscriptions are "Only supported on the root of a drive" — [driveItem resource](https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-1.0)

### Inferences
- **Mapping to Aegean Office's Nextcloud operations:**
  - List folder: `GET /me/drive/items/{id}/children?$select=id,name,size,eTag,cTag,file,folder,lastModifiedDateTime,lastModifiedBy,parentReference`.
  - Open: `GET .../content`, or the downloadUrl. Cache it with the item ID + cTag/eTag.
  - AutoSave / Save: `PUT .../items/{id}/content` with `If-Match: <cached eTag>` (the If-Match behaviour on small PUT is only documented on the upload-session page; test it). Use an upload session with `if-match` for files over about 10 MiB.
  - Save As: `PUT .../{parent-id}:/{name}:/content?@microsoft.graph.conflictBehavior=fail`.
  - On 412, apply the existing "keep both / mine / theirs" dialog, using `rename` or a new name for "keep both" and dropping If-Match for "mine". This lines up well with how the existing Nextcloud ETag/If-Match logic presumably works over WebDAV.
- Use **cTag** rather than eTag for "has the content changed?" checks, so that metadata changes such as a rename don't raise false conflicts. Since delta omits cTag on business drives, refetch the item after a delta hit.
- Office-format files (.xlsx/.docx/.pptx) are small, so the 250 MB single-PUT limit covers nearly all saves.

### Gaps
- I did not confirm whether `If-Match` is honoured on simple `PUT /content` in October 2026. Older docs listed it; the current page doesn't. Test it on both Personal and Business.
- Older Microsoft docs gave a lower small-upload limit (4 MB per memory; not re-verified here). Treat 250 MB as current per the 2026-08-11 page.
- The maximum overall file size for upload sessions (the "maximum file size") is not stated numerically on the page fetched.

---

## Q4. `/me/drive/recent`, `/me/drive/sharedWithMe` and other deprecations (2026-2027)

### Takeaway
Both `drive: recent` and `drive: sharedWithMe` are officially **deprecated, running degraded, and stop returning data after November 2026**, roughly 2-6 weeks from 19 Oct 2026. `/me/insights/shared` (work accounts only) has the same November 2026 end date. Microsoft has announced **no 1:1 replacement**. The community and moderator guidance points to the Microsoft Search API for work/school accounts, and there is nothing for personal accounts. Live SDK, Live Connect and the old OneDrive REST API were retired in 2018 and are irrelevant except as history.

### Cited Findings
- `GET /me/drive/sharedWithMe`: "The **sharedWithMe** API is deprecated and will operate in a degraded state until November, 2026, after which it will stop returning data." It returns items with a `remoteItem` facet. Least privilege is Files.Read.All for both work and personal accounts. `?allowexternal=true` includes cross-tenant shares — [drive: sharedWithMe (deprecated)](https://learn.microsoft.com/en-us/graph/api/drive-sharedwithme?view=graph-rest-1.0) (page updated 2026-03-21)
- `GET /me/drive/recent`: "The **recent** API is deprecated and will operate in a degraded state until November, 2026, after which it stops returning data." Least privilege is Files.Read — [drive: recent (deprecated)](https://learn.microsoft.com/en-us/graph/api/drive-recent?view=graph-rest-1.0) (page updated 2026-03-21)
- `GET /me/insights/shared`: "deprecated and will stop returning data after November 2026". It needs Sites.Read.All and is **not supported for personal Microsoft accounts**. It is global service only, with no US Gov or China — [List shared (deprecated)](https://learn.microsoft.com/en-us/graph/api/insights-list-shared?view=graph-rest-1.0) (updated 2026-05-06)
- Some early forum posts gave November 2027. The current Learn pages, and a July 2026 moderator reply, say November 2026 — [WebSearch summary of Microsoft Q&A threads](https://learn.microsoft.com/en-au/answers/questions/5942212/microsoft-graph-sharedwithme-endpoint-alternative). Rely on the Learn pages: **Nov 2026**.
- No official replacement:
  - A Microsoft Q&A thread from **12 Aug 2026** got an answer from an independent advisor, not Microsoft staff. The advisor found no documented 1:1 replacement and said Graph Search is "the closest supported approach for work or school accounts" but doesn't reproduce Shared-with-me behaviour — [Microsoft Q&A 5973045](https://learn.microsoft.com/en-us/answers/questions/5973045/what-is-the-supported-microsoft-graph-api-alternat)
  - A July 2026 Q&A reply about personal accounts likewise says no replacement has been announced — [Microsoft Q&A 5942212](https://learn.microsoft.com/en-au/answers/questions/5942212/microsoft-graph-sharedwithme-endpoint-alternative)
  - A Tech Community reply (community contributor) says to redesign around the Search API and/or the underlying OneDrive/SharePoint APIs — [Tech Community thread](https://techcommunity.microsoft.com/discussions/skills-hub-discussions/what-is-the-microsoft-graph-api-replacement-for-deprecated-recent-sharedwithme-a/4551294)
- Degraded behaviour already seen: `sharedWithMe` returning only one item (Nov 2025 reports) — [Microsoft Q&A 5615839](https://learn.microsoft.com/en-us/answers/questions/5615839/the-shared-with-me-api-does-not-work-why); [Microsoft Q&A 5617592](https://learn.microsoft.com/en-us/answers/questions/5617592/graph-api-me-drive-sharedwithme-endpoint-returns-j); [msgraph-sdk-dotnet #3040](https://github.com/microsoftgraph/msgraph-sdk-dotnet/issues/3040)
- Downstream projects are reacting:
  - The abraunegg/onedrive Linux client filed an issue that `sharedWithMe` deprecation breaks `--sync-shared-files` — [abraunegg/onedrive #3728](https://github.com/abraunegg/onedrive/issues/3728)
  - Keboola added a Graph Search fallback — [keboola/ex-onedrive PR #45](https://github.com/keboola/ex-onedrive/pull/45)
- A related insights change: `previewImageUrl` for file-attachment insights is deprecated, with removal on **1 Nov 2027** (Microsoft 365 Dev Blog, 29 Oct 2025) — [M365 Dev Blog](https://devblogs.microsoft.com/microsoft365dev/deprecation-of-the-previewimageurl-property-for-insights-items-that-reference-file-attachments/)
- Graph Search throttling: SharePoint/OneDrive delegated search is throttled above **10 requests per second per user**, across all apps — [Avoid getting throttled in SharePoint Online](https://learn.microsoft.com/en-us/sharepoint/dev/general-development/how-to-avoid-getting-throttled-or-blocked-in-sharepoint-online)
- Historical retirements (all long done):
  - Live Connect APIs (`apis.live.net/v5.0`) and the OneDrive REST API ended **1 Nov 2018**; profile/contacts stopped 1 Dec 2017. Graph is the replacement and needs new tokens/consent — [OneDrive docs: Migrating from Live SDK](https://github.com/OneDrive/onedrive-api-docs/blob/live/docs/rest-api/concepts/migrating-from-live-sdk.md); [M365 Dev Blog: Live Connect deprecation](https://devblogs.microsoft.com/microsoft365dev/outlook-rest-api-v1-0-office-365-discovery-and-live-connect-api-deprecation/)
  - The OneDrive SDK for iOS was deprecated from 10 March 2022 — [WebSearch summary](https://github-redirect.dependabot.com/OneDrive/onedrive-sdk-ios)

### Inferences
- **Recent:** Aegean Office should keep its own client-side MRU list (as Office itself does locally), storing drive ID + item ID per account and refreshing metadata with `GET /drives/{d}/items/{i}`. It shouldn't depend on any server "recent" API. For business accounts, the Search API (`POST /search/query`, entityType `driveItem`) can add "recently modified by me" queries.
- **Shared with me:**
  - Work/school: use `POST /search/query` over driveItems (Search API; not fetched in detail here), or ask users to "Add shortcut to My files", which then show up in normal browsing.
  - Personal OneDrive: there is effectively **no supported API after Nov 2026**. The UI should degrade gracefully, e.g. let users open shared items via a sharing link with `GET /shares/{encoded-url}/driveItem`. That endpoint was not verified in this research.
- Any design that mirrors Office's "Shared with me" view exactly is at risk. Treat it as best-effort.

### Gaps
- No Microsoft blog post or Message Center ID announcing the `recent`/`sharedWithMe` deprecation was found. The only primary evidence is the caution banners on the Learn pages; their original announcement date wasn't established.
- `/me/insights/used` and `/me/insights/trending` status was not checked directly.
- Whether the Search API returns items shared with a personal (MSA) account was not established. The Q&A evidence suggests it does not.
- The `/shares/{shareId}` (sharing-link resolution) endpoint status was not fetched.

---

## Q5. Throttling limits and best practice; national/sovereign clouds (brief)

### Takeaway
OneDrive/SharePoint throttling is measured in **resource units (RU)** per app per tenant and per user:
- Per user: 3,000 requests per 5 minutes.
- Per app per tenant: 1,250 RU/min and 1.2M RU/24h for tenants with up to 1,000 licences.

Honour `Retry-After` on 429/503, decorate the User-Agent as `ISV|AegeanLogic|AppName/Version`, and prefer delta. National clouds mostly support the file APIs, but publisher verification and `insights/shared` are unavailable there.

### Cited Findings
- Graph's global limit is **130,000 requests per 10 seconds per app across all tenants**. For OneDrive/SharePoint, the Graph page defers to the SharePoint throttling doc — [Microsoft Graph throttling limits](https://learn.microsoft.com/en-us/graph/throttling-limits)
- Resource unit costs:
  - 1 RU: single-item get, **delta with a token**, file download.
  - 2 RU: multi-item query such as list children; create, update, delete and upload.
  - 5 RU: any permission operation, including `$expand=permissions`.
  - Batched requests are evaluated individually.
  - Source: [Avoid getting throttled or blocked in SharePoint Online](https://learn.microsoft.com/en-us/sharepoint/dev/general-development/how-to-avoid-getting-throttled-or-blocked-in-sharepoint-online) (updated 2026-08-10)
- User limits: **3,000 requests / 5 min**; ingress 50 GB/h; egress 100 GB/h; 50 delegation token requests / 5 min — same source.
- Per app per tenant, by tenant licence count:
  | Licences | RU per 24 h | RU per minute |
  | --- | --- | --- |
  | 0-1,000 | 1,200,000 | 1,250 |
  | 1,001-5,000 | 2,400,000 | 2,500 |
  | 5,001-15,000 | 3,600,000 | 3,750 |
  | 15,001-50,000 | 4,800,000 | 5,000 |
  | 50,000+ | 6,000,000 | 6,250 |

  Ingress and egress are 400 GB/h each. Each tenant is a separate bucket for multi-tenant apps. Tenant-wide limits run from 18,750 to 93,750 RU per 5 min. Microsoft "reserve[s] the right to lower limits on Unpaid/Unlicensed usage" — same source.
- Handling:
  - Throttled responses are 429 or 503 with `Retry-After`, and throttled requests still count.
  - Persistent abuse leads to a block, with continuous 503 and a Message Center notice to the tenant.
  - SharePoint "does not return or support IETF RateLimit headers".
  - User-Agent format for ISVs: `ISV|CompanyName|AppName/Version`. Decorated traffic is prioritised.
  - Don't create multiple AppIDs to dodge limits.
  - Source: [Avoid getting throttled or blocked in SharePoint Online](https://learn.microsoft.com/en-us/sharepoint/dev/general-development/how-to-avoid-getting-throttled-or-blocked-in-sharepoint-online)
- Graph-level throttle headers include `x-ms-throttle-limit-percentage` (sent when more than 80% of a limit is consumed), `x-ms-throttle-scope` and `x-ms-throttle-information`. There is also a `x-ms-throttle-priority` request header — [Microsoft Graph throttling limits](https://learn.microsoft.com/en-us/graph/throttling-limits)
- National clouds:
  - `createUploadSession`, small upload, `checkout`, thumbnails, `sharedWithMe` and `recent` are listed as available in Global, US Gov L4, US Gov L5 (DoD) and China (21Vianet) — [createUploadSession](https://learn.microsoft.com/en-us/graph/api/driveitem-createuploadsession?view=graph-rest-1.0); [Upload small files](https://learn.microsoft.com/en-us/graph/api/driveitem-put-content?view=graph-rest-1.0); [checkout](https://learn.microsoft.com/en-us/graph/api/driveitem-checkout?view=graph-rest-1.0)
  - `insights/shared` is Global only — [List shared](https://learn.microsoft.com/en-us/graph/api/insights-list-shared?view=graph-rest-1.0)
  - Publisher verification is not supported in national clouds — [Publisher verification overview](https://learn.microsoft.com/en-us/entra/identity-platform/publisher-verification-overview)

### Inferences
- A desktop office suite with per-user interactive traffic (list, open, save) is several orders of magnitude below these limits. AutoSave should debounce, e.g. not upload more than once every few seconds, and honour `Retry-After`.
- Sovereign clouds need different authority and Graph hosts (e.g. `login.microsoftonline.us` / `graph.microsoft.us`; `login.chinacloudapi.cn` / `microsoftgraph.chinacloudapi.cn`) and in practice separate app registrations. These hostnames are from general knowledge and were not verified here. Treat sovereign clouds as out of scope for v1.

### Gaps
- No OneDrive Personal (consumer)-specific throttling numbers were found. The SharePoint doc covers OneDrive for Business.

---

## Q6. Locking / checkout; avoiding overwriting others' edits

### Takeaway
Graph exposes `checkout` / `checkin` / `discardCheckout` on driveItems, documented for both work/school and personal delegated permissions. Checkout is a SharePoint/OneDrive-for-Business library concept: it hides your changes until check-in and blocks others' edits. It is not a lightweight co-authoring lock and doesn't integrate with Office co-authoring. Graph has no WOPI-style short-term edit lock for third-party desktop clients. The supported pattern is optimistic concurrency with `if-match` on the eTag/cTag, plus conflict UI.

### Cited Findings
- `POST /drives/{driveId}/items/{itemId}/checkout` "prevent[s] others from editing the document, and prevent[s] your changes from being visible until the document is checked in". It returns `204 No content`. Permissions are Files.ReadWrite delegated for both work/school and personal accounts. It is available in all national clouds — [driveItem: checkout](https://learn.microsoft.com/en-us/graph/api/driveitem-checkout?view=graph-rest-1.0) (updated 2025-07-23)
- The driveItem `publication` facet "Provides information about the published or checked-out state of an item, **in locations that support such actions**". It isn't returned by default — [driveItem resource](https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-1.0)
- `createUploadSession` honours `if-match` (412 on mismatch) and `if-none-match`. The commit-after-error PUT also accepts `if-match` and conflictBehavior — [createUploadSession](https://learn.microsoft.com/en-us/graph/api/driveitem-createuploadsession?view=graph-rest-1.0)
- Change detection options: delta (`/root/delta`) and a socket.io "Get WebSocket channel" for near-real-time notifications on a drive — [driveItem resource](https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-1.0); [delta](https://learn.microsoft.com/en-us/graph/api/driveitem-delta?view=graph-rest-1.0)
- Version history (`List versions`) is available for recovery — [driveItem resource](https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-1.0)

### Inferences
- **Recommended approach for Aegean Office:**
  1. On open, record the eTag and cTag.
  2. On each AutoSave or Save, upload with `If-Match: <eTag>`.
  3. On 412, fetch current metadata. If the cTag is unchanged (only metadata changed), retry with the new eTag. If it changed, show the existing keep-both / mine / theirs dialog, and use `conflictBehavior=rename` or a suffixed name for "keep both".
  4. Optionally poll the item, or use delta or the socket.io channel, while a document is open, to warn early that "someone else saved a newer version".
  5. Use version history for "restore".

  This matches Aegean Office's existing Nextcloud conflict model.
- Use `checkout` only as an opt-in for SharePoint libraries that require checkout. Don't use it routinely on OneDrive, because it hides changes until check-in and would confuse Office/Office-for-web users who co-author the same file.
- Real-time co-authoring with Microsoft Office clients is not possible through Graph: Office uses its own protocols (WOPI/MS-FSSHTTP). A Graph-based app can only do whole-file save with conflict detection. This is an inference; Microsoft docs fetched here don't discuss third-party co-authoring.

### Gaps
- The checkout page doesn't state whether checkout works on **OneDrive Personal** drives, although it lists personal-account permissions. Expect errors on consumer drives, and test it.
- No Graph API for a short-lived "file is being edited by X" lock (like SharePoint's exclusive or shared locks) was found.

---

## Q7. Licensing / terms of use / costs

### Takeaway
Graph file APIs are free to call. The only remaining **metered** Graph API is `assignSensitivityLabel` at US$0.00185 per call; Teams APIs stopped being metered on 25 Aug 2025. Use is governed by the **Microsoft APIs Terms of Use** (last updated October 2025). Requirements include a privacy statement with revocation links, minimum data and permissions, no use of API data for advertising, and Microsoft's right to change or discontinue APIs. Open-source distribution of a client that embeds a public-client app ID isn't restricted by the terms read here, but the client ID is the publisher's responsibility.

### Cited Findings
- Metered APIs: Teams APIs are "no longer metered", with no billing configuration required since **August 25, 2025**. The only metered API listed is SharePoint/OneDrive **assignSensitivityLabel at $0.00185 per call**, which needs an Azure subscription linked to the app — [Metered APIs and services in Microsoft Graph](https://learn.microsoft.com/en-us/graph/metered-api-list) (via search summary). Localized copies of the page are older and still list Teams as metered.
- The SharePoint "Assign Sensitivity Label" tenant limit is 100 per 5 min — [Avoid getting throttled in SharePoint Online](https://learn.microsoft.com/en-us/sharepoint/dev/general-development/how-to-avoid-getting-throttled-or-blocked-in-sharepoint-online)
- Microsoft APIs Terms of Use ("Last Updated: October 2025") — [Microsoft APIs Terms of Use](https://learn.microsoft.com/en-us/legal/microsoft-apis/terms-of-use)
  - **Coverage:** Graph and APIs for OneDrive (Office 365 and OneDrive.com) are explicitly covered.
  - **Licence:** a limited, revocable licence to use the APIs in your Application. Registration must be accurate, and Access Credentials are non-transferable.
  - **Prohibited uses relevant here:**
    - Requesting "more than the minimum permissions" needed.
    - Scraping or building databases beyond what the intended scenario needs.
    - Circumventing limits.
    - Using API data for advertising or marketing.
    - Using the APIs to migrate Customers away from a Microsoft Offering "unless approved by Customers".
    - Circumventing the need for users to hold valid Microsoft licences.
    - Redistributing, reselling or sublicensing access to the APIs or data.
  - **OneDrive clause (3e):** for non-work-file access, you may not store "systems data" such as system backups or team/org-level data in OneDrive.
  - **Privacy:**
    - Maintain a privacy statement "as protective as the Microsoft Privacy Statement".
    - When Microsoft doesn't provide the sign-in UI, link to `https://account.live.com/consent/Manage` and/or `https://myapps.microsoft.com` so users can revoke consent.
    - Delete data when users abandon or uninstall.
  - **Security:** report vulnerabilities and breaches to MSRC (secure@microsoft.com). Microsoft may audit (up to two full-feature instances).
  - **Changes:** Microsoft "MAY CHANGE OR DISCONTINUE THE AVAILABILITY OF SOME OR ALL OF THE MICROSOFT APIs AT ANY TIME", including requiring fees. Liability is capped at US$5. Microsoft can terminate at any time.
  - **EU:** EU Commission commitments in case AT.40721 (Microsoft Teams) override parts of the terms, including on throttling and changes.
- Publisher verification is free and needs no licence — [Publisher verification overview](https://learn.microsoft.com/en-us/entra/identity-platform/publisher-verification-overview). Accepting the Microsoft identity platform for developers Terms of Use is a verification prerequisite — same source.
- MSAL libraries in public preview fall under the Universal License Terms for Online Services — [Configure desktop apps](https://learn.microsoft.com/en-us/entra/identity-platform/scenario-desktop-app-registration)

### Inferences
- **Costs:** none for the APIs Aegean Office needs. The only spend is Aegean Logic's own Entra tenant, which is free, and optionally a Microsoft 365 developer/test tenant.
- **Open source:** the client ID of a public client isn't a secret, so shipping it in an open-source repo is normal practice. Forks should register their own app IDs, since Access Credentials are "non-transferable"; that is the conservative reading. The README and privacy policy should include the consent-revocation links required by section 5(e).
- **Branding:** avoid implying Microsoft endorsement. Microsoft Trademark & Brand Guidelines apply to "OneDrive" naming in the UI; the terms reference them for Intune specifically, and general use was not verified.

### Gaps
- The metered-API page was seen only via a search summary, not a direct fetch.
- Microsoft trademark rules for third-party "Open from OneDrive" UI labels and logos weren't researched.
- Microsoft 365 App Certification requirements and costs, if Aegean Logic wants enterprise trust beyond publisher verification, weren't researched.
