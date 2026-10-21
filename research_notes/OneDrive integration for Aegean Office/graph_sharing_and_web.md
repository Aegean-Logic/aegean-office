# OneDrive sharing via Microsoft Graph and browser-side OneDrive integration (state as of October 2026)

Research date: 2026-10-19. Doc "updated_at" dates are quoted where the page metadata showed them, so readers can judge staleness. Many Graph reference pages carry an old `ms.date` (for example 2017-09-10) but were re-published in 2025-2026; the content is current as published, but the wording of some account-type notes has not changed in years and may lag behind the service.

## 1. What sharing operations Graph supports, and how they differ by account type

### Takeaway
Graph v1.0 covers everything Aegean Office's Share dialog does today: create a link (`createLink`), invite people (`invite`), list, change and remove permissions, and add people to an existing link (`grant`). But the account types differ a lot. OneDrive for Business/SharePoint has organization and specific-people links, blocks-download/review/upload-only link types (beta only), and admin policy. OneDrive personal only has anonymous view/edit/embed links, plus password and expiry, which need a premium (Microsoft 365 Basic/Personal/Family) subscription. `grant` is not supported for personal accounts, and PATCH can only change `roles`.

### Cited Findings

**createLink (POST /drives/{id}/items/{id}/createLink)**
- Delegated permission `Files.ReadWrite` is the least-privileged scope for both work/school and personal accounts. `Files.ReadWrite.All` and `Sites.ReadWrite.All` are higher-privileged options. App-only needs `Files.ReadWrite.All`. — [Graph v1.0 createLink (updated 2026-08-04)](https://learn.microsoft.com/en-us/graph/api/driveitem-createlink?view=graph-rest-1.0)
- In v1.0 the link `type` is `view`, `edit` or `embed`. `embed` is "only available for files in OneDrive personal"; it returns `webHtml` holding an `<iframe>`. — [createLink v1.0](https://learn.microsoft.com/en-us/graph/api/driveitem-createlink?view=graph-rest-1.0)
- In v1.0 the `scope` is `anonymous` ("Anonymous link support may be disabled by an administrator"), `organization` ("Only available in OneDrive for Business and SharePoint") or `users` ("Share only with people you choose inside or outside the organization"). If `scope` is omitted, "the default link type for the organization is created." — [createLink v1.0](https://learn.microsoft.com/en-us/graph/api/driveitem-createlink?view=graph-rest-1.0)
- The v1.0 page describes `password` as "Optional and OneDrive Personal only". `expirationDateTime` (format yyyy-MM-ddTHH:mm:ssZ) has no account restriction on this page. `retainInheritedPermissions` (default true; if false, existing permissions are removed when the item is first shared) is not supported with SharePoint Embedded. — [createLink v1.0](https://learn.microsoft.com/en-us/graph/api/driveitem-createlink?view=graph-rest-1.0)
- The response is `201 Created` for a new link, or `200 OK` if a link of that type "already exists for the calling application" (the existing link is returned). Links "don't expire unless a default expiration policy is enforced for the organization." — [createLink v1.0](https://learn.microsoft.com/en-us/graph/api/driveitem-createlink?view=graph-rest-1.0)
- **Beta** adds more link types:
  - `review` (OneDrive for Business/SharePoint files only)
  - `blocksDownload` ("read-only link that blocks download", OneDrive for Business/SharePoint only)
  - `createOnly` (upload-only, folders only, OneDrive for Business/SharePoint)
  - `addressBar` (the default address-bar link, configured by the admin)
  - `adminDefault` ("the default link ... as determined by the administrator")

  Beta also adds `recipients` (a driveRecipient collection) and `sendNotification` (emails the link; "Applicable to OneDrive for Business or SharePoint", default false). In beta, `users` scope is "Only available in OneDrive for Business and SharePoint". Beta pages warn: "Use of these APIs in production applications is not supported." — [createLink beta (ms.date 2024-04-05, updated 2026-08-04)](https://learn.microsoft.com/en-us/graph/api/driveitem-createlink?view=graph-rest-beta)
- Conflict note: v1.0 describes `users` scope without an account restriction, but beta says OneDrive for Business/SharePoint only. — [v1.0](https://learn.microsoft.com/en-us/graph/api/driveitem-createlink?view=graph-rest-1.0) vs [beta](https://learn.microsoft.com/en-us/graph/api/driveitem-createlink?view=graph-rest-beta)

**invite (POST .../items/{id}/invite)**
- The invite body takes:
  - `recipients` (driveRecipient collection)
  - `message` (plain text, maximum 2,000 characters)
  - `requireSignIn` (Boolean)
  - `sendInvitation` ("If true, a sharing link is sent to the recipient. Otherwise, a permission is granted directly without sending a notification")
  - `roles` (`read` | `write`)
  - `expirationDateTime`
  - `password`
  - `retainInheritedPermissions`

  — [Graph v1.0 invite (ms.date 2025-09-16, updated 2026-08-04)](https://learn.microsoft.com/en-us/graph/api/driveitem-invite?view=graph-rest-1.0)
- `expirationDateTime` on invite: "For OneDrive for work or school and SharePoint, expirationDateTime is only applicable for sharingLink permissions. Available on OneDrive for work or school, SharePoint, and premium personal OneDrive accounts." Invite `password` is "Optional and OneDrive for home only." — [invite v1.0](https://learn.microsoft.com/en-us/graph/api/driveitem-invite?view=graph-rest-1.0)
- Restrictions: "Permissions can't be created or modified on the root driveItem of drives with a driveType of `personal` (OneDrive for home)." Also, "New guests can't be invited using app-only access. Existing guests can be invited using app-only requests." — [invite v1.0](https://learn.microsoft.com/en-us/graph/api/driveitem-invite?view=graph-rest-1.0)
- Multiple recipients can give a partial result: `207 Multi-Status`, with a per-recipient `error` object. Notification errors (innererror codes):
  - `accountVerificationRequired`
  - `hipCheckRequired`
  - `exchangeInvalidUser`
  - `exchangeOutOfMailboxQuota`
  - `exchangeMaxRecipients`

  The sample error shows `code: notAllowed` with a `fixItUrl` and a `localizedMessage`. "The service can add new error codes or stop returning old ones at any time." — [invite v1.0](https://learn.microsoft.com/en-us/graph/api/driveitem-invite?view=graph-rest-1.0)

**List / get / update / delete permissions, grant, revokeGrants**
- The methods on the permission resource are:
  - `GET /drive/items/{id}/permissions` (list)
  - `GET .../permissions/{id}` (get)
  - `POST .../invite` (add)
  - `PATCH .../permissions/{id}` (update)
  - `DELETE .../permissions/{id}` (delete)
  - `POST /shares/{encoded-sharing-url}/permission/grant` (grant)
  - `POST .../permissions/{id}/revokeGrants` (revoke grants)

  — [Permission resource (updated 2026-10-08)](https://learn.microsoft.com/en-us/graph/api/resources/permission?view=graph-rest-1.0)
- Permission roles are `read`, `write` and `owner` (owner applies to SharePoint/OneDrive for Business). `hasPassword` is "For OneDrive Personal only". `grantedTo` and `grantedToIdentities` are deprecated in favour of `grantedToV2` and `grantedToIdentitiesV2`. "OneDrive for Business and SharePoint document libraries don't return the inheritedFrom property." Link scope can also be `existingAccess` (a link that "doesn't grant any extra privileges"). — [Permission resource](https://learn.microsoft.com/en-us/graph/api/resources/permission?view=graph-rest-1.0)
- For an invitation sent to an email address with no matching account, `grantedTo` "may not be set until the invitation is redeemed". — [Permission resource](https://learn.microsoft.com/en-us/graph/api/resources/permission?view=graph-rest-1.0)
- Listing permissions: "For the owner of the item, all sharing permissions will be returned... For a non-owner caller, only the sharing permissions that apply to the caller are returned." Secret properties (`shareId`, `webUrl`) are "only returned for callers that are able to create the sharing permission". Inherited permissions are told apart by `inheritedFrom`. Permissions "cannot be expanded" on a driveItem GET; you must call `/permissions` directly. Least privilege is `Files.Read` (both account types). — [List permissions (updated 2025-07-23)](https://learn.microsoft.com/en-us/graph/api/driveitem-list-permissions?view=graph-rest-1.0)
- PATCH a permission: "Only the roles property can be modified this way" (`read`/`write`/`owner`). Not supported: "Organizational sharing links" and "People sharing links". It supports `if-match` (412 on mismatch). — [Update permission (updated 2026-06-19)](https://learn.microsoft.com/en-us/graph/api/permission-update?view=graph-rest-1.0)
- `grant`: "Grant users access to a link." Delegated personal Microsoft account: "Not supported." Work/school least privilege is `Files.ReadWrite`. The body takes `recipients` and `roles`; for a non-existing-access link, roles "must match the role of the link". "In some cases it may be possible that the updated link has a different URL than the original link." Encoded sharing URL = base64 → unpadded base64url → prefix `u!`. For existing-access links, the response can include invitation-facet entries "that need to be sent to unrecognized external users". — [Grant permission (updated 2026-06-06)](https://learn.microsoft.com/en-us/graph/api/permission-grant?view=graph-rest-1.0)

**Account type / licence for password and expiry (personal)**
- Microsoft support says Microsoft 365 Basic, Personal or Family subscribers get the advanced sharing options (expiration dates, passwords) in OneDrive personal. — [Microsoft Support: OneDrive premium features / sharing](https://support.microsoft.com/office/3fcefa26-1371-401e-8c04-589de81ed5eb); older coverage (around 2017) said this was limited to Office 365 Personal/Home: [Neowin](https://www.neowin.net/news/microsoft-quietly-adds-expiring-links-feature-for-onedrive-users-with-office-365)
- A third-party guide claims that in OneDrive personal, expiry can be set only on "Anyone" links. Unverified against a Microsoft source. — [support.bloomfieldtwpmi.gov guide](https://support.bloomfieldtwpmi.gov/hc/en-us/articles/34323600380813-Share-a-file-using-the-Copy-Link-function-in-OneDrive)

**Admin/tenant policy and how errors surface**
- Anonymous links can be disabled by the admin (from the createLink scope table). Developers report that `scope: anonymous` fails while `organization` succeeds in such tenants. — [createLink v1.0](https://learn.microsoft.com/en-us/graph/api/driveitem-createlink?view=graph-rest-1.0); [Microsoft Q&A 511636](https://learn.microsoft.com/en-us/answers/questions/511636/how-do-i-enable-anonymous-access-to-a-link-created)
- Power Automate's "Create sharing link" reported a misleading "sharing disabled on the site" message when the real cause was anonymous scope being blocked; switching to organization scope fixed it. — [Dynamics community KA-24804](https://community.dynamics.com/article/KA-24804)
- Anonymous sharing must be enabled at both tenant and site-collection level. Group-connected sites may need PowerShell. — [Tech Community thread](https://techcommunity.microsoft.com/discussions/sharepoint_general/trying-to-share-folder-with-guest-but-access-denied-/34963/replies/155635)
- Organization-scoped links can't be used by users from other tenants. — [Microsoft Q&A 1819995](https://learn.microsoft.com/en-us/answers/questions/1819995/how-do-i-create-a-sharing-link-with-the-graph-api)

### Inferences
- A practical capability matrix for the Share dialog:
  - **OneDrive personal (free):** anonymous view/edit (and embed) links; invite by email with read/write; list and remove permissions; change role by PATCH. No organization scope, no `grant`, no blocks-download/review. Password and expiry are documented as personal-only (password) or premium-personal (expiry), so the free tier should hide them or be ready for a failure.
  - **OneDrive personal (Microsoft 365 Basic/Personal/Family):** as free, plus password and expiry.
  - **OneDrive for Business:** anonymous (if the tenant allows it), organization and specific-people links; invite with expiry; `grant` to add people to a link; `blocksDownload`/`review`/`createOnly` only via beta. Link passwords are **not** documented for OneDrive for Business in the v1.0 createLink/invite pages, even though Office's own UI offers passwords on "Anyone" links. That is a gap or doc lag; test before relying on it.
- Because PATCH can only change `roles` (and not on organization or people links), "change link from view to edit" or "change expiry" usually has to be done as delete-and-recreate, which produces a new URL.
- createLink is idempotent per app and type ("returns the existing link"). Aegean Office should expect 200 vs 201 and must not assume a fresh link.
- Tenant-policy failures don't appear to have one documented error code. The client should treat a failed `anonymous` createLink as "policy may forbid", then offer organization or specific-people scopes. Before showing options, it can read the tenant's default by omitting `scope` (beta `adminDefault`).

### Gaps
- I didn't fetch the permission-delete and revokeGrants pages; the methods are only confirmed from the permission resource table.
- I found no official list of the error codes returned when tenant sharing policy blocks a link type (for example anonymous disabled, external sharing off, domain allow/deny lists). This needs empirical testing.
- Whether `password` on createLink works on OneDrive for Business through Graph v1.0 is undocumented (docs say personal only).
- Whether expiry on free (non-premium) personal accounts returns an error or is silently ignored is not documented.

## 2. How closely a third-party app can reproduce Office's Share dialog (people picker, scopes, consent)

### Takeaway
The share actions themselves need only `Files.ReadWrite`, which a user can consent to. For the people picker, `People.Read` (`/me/people?$search=`) works for both work/school and personal accounts and also returns groups. Directory-wide user search needs `User.ReadBasic.All` (user-consentable); group search needs admin-consent scopes. Since mid-2025, Microsoft's default consent policy blocks users from consenting to `Files.Read(Write).All` / `Sites.Read(Write).All`, so asking for those scopes makes admin consent effectively mandatory in many tenants.

### Cited Findings
- `GET /me/people` takes delegated `People.Read` for **both** work/school and personal Microsoft accounts. `$search` "Search[es] for people by name or alias. Supports Fuzzy matching". Results can include groups (`personType.class: "Group", subclass: "UnifiedGroup"`). — [List people (updated 2026-08-15)](https://learn.microsoft.com/en-us/graph/api/user-list-people?view=graph-rest-1.0)
- "The People API is in maintenance mode." Microsoft recommends the Microsoft Search API (`POST /search/query` with `entityTypes: ["person"]`) for new development. — [List people](https://learn.microsoft.com/en-us/graph/api/user-list-people?view=graph-rest-1.0)
- `User.ReadBasic.All` is delegated and doesn't require admin consent. Microsoft described it as the scope that lets you build a people picker that non-admin users can consent to. `User.Read.All` and `Group.Read.All` need admin consent. (Older Azure AD Graph-era sources; the scope semantics carried over to Microsoft Graph.) — [Azure AD Graph permission scopes (previous-versions)](https://learn.microsoft.com/en-us/previous-versions/azure/ad/graph/howto/azure-ad-graph-api-permission-scopes); [AAD Graph team blog (archive)](https://learn.microsoft.com/zh-cn/archive/blogs/aadgraphteam/new-graph-api-consent-permissions)
- `People.Read` is user-consentable; `People.Read.All` needs admin consent. — [graphpermissions.merill.net People.Read](https://graphpermissions.merill.net/permission/People.Read.html); [People.Read.All](https://graphpermissions.merill.net/permission/People.Read.All.html)
- **MC1097272 (announced 17 June 2025):** a Microsoft-managed app consent policy blocks ordinary users from consenting to third-party apps that request `Files.Read.All`, `Files.ReadWrite.All`, `Sites.Read.All` and `Sites.ReadWrite.All`. The rollout was due to "begin rolling out in mid-July and ... be in all tenants sometime in August 2025". It affects only tenants on the default user-consent settings, and existing grants keep working. Admins should run the admin consent workflow. — [Office 365 for IT Pros, 2025-06-19](https://office365itpros.com/2025/06/19/app-consent-policy-user-app-consent/); [MC1097272 mirror](https://mc.merill.net/message/MC1097272)
- One write-up names `Files.Read` (not `.All`) as an example permission. That is inconsistent with the other sources and needs checking in Message Center. — [Office 365 for IT Pros](https://office365itpros.com/2025/06/19/app-consent-policy-user-app-consent/)
- 2026: the Microsoft-managed policy is being extended to block 8 more (Exchange-related, for example Contacts/Tasks) permissions. — [Topedia, May 2026](https://blog-en.topedia.com/2026/05/microsoft-managed-default-app-consent-policy-will-block-8-additional-permissions/)
- invite/createLink/list/update all have least privilege `Files.ReadWrite` (or `Files.Read` for list). That scope is not in the blocked list above. — [invite](https://learn.microsoft.com/en-us/graph/api/driveitem-invite?view=graph-rest-1.0); [createLink](https://learn.microsoft.com/en-us/graph/api/driveitem-createlink?view=graph-rest-1.0)
- The October 2026 Office Share dialog ("Hero Link") offers:
  - Audiences: "Only people added to the file", "People in your organization", "Anyone with the link".
  - Access: Can view / Can edit / Can view without downloading.
  - Advanced: "Remove access" and "Reset link".

  — [Topedia, 2026-10-10](https://blog.topedia.com/2026/10/hero-link-in-onedrive-and-sharepoint-a-new-experience-for-file-sharing/)

### Inferences
- A close replica is feasible with `Files.ReadWrite` + `People.Read` (+ optionally `User.ReadBasic.All` for work/school directory search). All are user-consentable, so in default-policy tenants Aegean Office can avoid admin consent if it stays off `.All` file scopes. The catch: `Files.ReadWrite` only reaches the user's own drive and items shared with them. Items in SharePoint team sites would need `Sites.*`/`Files.*.All`, which now trigger admin consent.
- "Can view without downloading" maps to beta `blocksDownload`. Office-like "Reset link" maps to delete permission and recreate. Office's "Remove access" (strip all except the owner) would mean iterating the permissions list and deleting each non-inherited, non-owner entry.
- Group search for work/school (`/groups?$search`) needs admin-consent scopes. `/me/people` gives a partial, relevance-ranked substitute that includes M365 groups.
- For personal accounts the "picker" can only search the user's own relevant contacts (`/me/people`); there is no directory. Free-text email entry must be the main path.

### Gaps
- I didn't verify the exact current Microsoft Graph permission-reference rows for `User.ReadBasic.All` / `GroupMember.Read.All` (admin consent flags), or whether the Search API person-entity works for personal accounts.
- Whether SharePoint resource scopes used by the File Picker (`MyFiles.Read/Write`, `AllSites.*`) fall under the MC1097272 block isn't stated in the sources found.

## 3. Recent changes (2024-2026): link types, deprecations, Share experience, OneDrive personal

### Takeaway
2026 brings big changes on the **work/school** side:
- the "Hero Link" Share dialog (one updatable primary link per item, default "Only people added"; GA mid-September to November 2026);
- the move of external sharing from SharePoint one-time passcodes to Entra B2B guests (May to August 2026);
- organization-link expiration policies;
- an April 2027 change that removes embedded-token (tempauth) URLs from Graph file APIs.

I found no 2024-2026 announcement that changes the Graph sharing API for OneDrive personal.

### Cited Findings
- **Hero Link:**
  - Rollout: announced May 2025; "The rollout should be completed by November 2026."
  - Behaviour: one primary link per file/folder; default audience "Only people added", so "the link itself does not grant access to anyone"; changing the audience updates the existing link; the first Hero Link breaks inheritance.
  - Admin control: per site with `Set-SPOSite -DefaultMainLinkScope` (OnlyPeopleAdded/Organization/Anyone); "Currently, Microsoft offers no tenant-wide setting".
  - Legacy links: existing links keep working under "Other sharing links"; "Some sharing links do not yet support Hero Links", such as time-limited links.

  The article doesn't cover Graph/createLink implications. — [Topedia, 2026-10-10](https://blog.topedia.com/2026/10/hero-link-in-onedrive-and-sharepoint-a-new-experience-for-file-sharing/)
- Another source puts Hero Link GA "from mid-September 2026 through to late October 2026". — [Andrew Warland, 2026-09-07](https://andrewwarland.wordpress.com/2026/09/07/forthcoming-changes-to-how-share-will-work-in-sharepoint-and-onedrive-from-mid-september-2026/)
- University IT notices report the default link audience changing from "Anyone" to "People you choose". Reports on default expiry for new links conflict (180 days from 18 June 2026 vs a 30-day default for Anyone links with a 180-day maximum); these are tenant-configured. — [allitservices.com.au](https://allitservices.com.au/sharepoint-onedrive-sharing-changes-2026/); [Bath University](https://www.bath.ac.uk/announcements/updates-to-sharing-links-in-sharepoint-and-onedrive/); [UF Engineering IT](https://www.it.eng.ufl.edu/?p=14437)
- **MC1242772:** admins can set expiration policies for "People in your organization" links. — [MC1242772 mirror](https://mc.merill.net/message/MC1242772)
- **OTP retirement:** "May 2026: New external sharing transitions to Entra B2B"; "July 2026: OTP authentication retires"; "By 31 August 2026: Retirement completed". External users without guest accounts "will see access denied on previously shared 'specific people' links". (Consultancy blog, no MC number.) — [DW Results, 2026-04-08](https://dwresults.com/2026/04/08/external-file-sharing-microsoft-365-changes/)
- **MC1492958 (published 9 October 2026):**
  - What changes: "beginning April 1, 2027, selected Microsoft Graph file APIs will no longer return URLs that contain embedded authentication information and will no longer issue HTTP 302 redirects to those URLs"; they "will instead return content directly".
  - Affected APIs: download/content, createUploadSession, copy monitors, preview, thumbnail, version and format-conversion APIs.
  - Timing and controls: rollout early to late April 2027; tenant opt-in test controls "coming soon"; "Requests made directly to SharePoint APIs rather than through Microsoft Graph are not affected."
  - Not addressed: CORS and OneDrive personal.

  — [MC1492958 mirror](https://mc.merill.net/message/MC1492958)
- Graph `grantedTo` / `grantedToIdentities` are deprecated in favour of the V2 properties. — [Permission resource](https://learn.microsoft.com/en-us/graph/api/resources/permission?view=graph-rest-1.0)
- (Older, 2023) Microsoft retired the legacy SharePoint `_api/v2.0`-style file APIs (`_api/beta/files`, `_api/v1.0/files`) in favour of Graph drives/driveItems, with "no guarantees" after April 2024. — [M365 Dev Blog, 2023-10-20](https://devblogs.microsoft.com/microsoft365dev/retirement-of-older-sharepoint-file-services-versions)

### Inferences
- The Hero Link model (one mutable link per item) differs from Graph's createLink model (one link per type/scope per app). Links Aegean Office creates through Graph will likely show as "Other sharing links" in Office's new dialog. That is cosmetic but may confuse users who switch between the two.
- After the B2B switch, inviting external emails on OneDrive for Business will create guest accounts. Expect `invite` behaviour (and failures where B2B is restricted) to follow the Entra external-collaboration settings.
- MC1492958 matters for the browser design (see section 5): the documented CORS workaround depends on pre-authenticated `downloadUrl`/`uploadUrl`, which is exactly what is being retired for work/school tenants from April 2027.

### Gaps
- I found no official Message Center ID for Hero Link or OTP retirement in the sources fetched; the dates come from secondary blogs.
- I found nothing on new link types or API changes for **OneDrive personal** in 2024-2026.
- I couldn't confirm whether MC1492958 covers `@microsoft.graph.downloadUrl` by name, or OneDrive personal.

## 4. Browser: OneDrive File Picker v8

### Takeaway
File Picker v8 is a Microsoft-hosted page (`/_layouts/15/FilePicker.aspx`, or `https://onedrive.live.com/picker` for consumers). You open it in an iframe or popup and drive it over postMessage/MessageChannel. It supports personal and work/school accounts, file or folder mode, and a built-in "save-as" tray prompt with a filename and conflict handling. The host supplies tokens through MSAL from an Entra app with a SPA redirect.

### Cited Findings
- "The File Picker v8 allows you to use the same functionality used within the M365 service... This new 'control' is a page hosted within the Microsoft service which you interact with via post messages. The page can be hosted either embedded in an iframe or as a popup." Docs for the older 7.2 picker remain linked separately. — [File Picker overview (updated 2024-06-17)](https://learn.microsoft.com/en-us/onedrive/developer/controls/file-pickers/?view=odsp-graph-online)
- Setup:
  - Create an Entra app registration with a **Single-page application** redirect (sample: `https://localhost`), with access and ID tokens checked; "optionally configure this application for multitenant".
  - Graph permissions: `Files.Read.All`, `Sites.Read.All`, `User.Read`.
  - SharePoint delegated permissions: `AllSites.Read`, `MyFiles.Read`.
  - Upload/create folder adds `Files.ReadWrite.All`, `Sites.ReadWrite.All`, `AllSites.Write`, `MyFiles.Write`.

  — [File Picker overview](https://learn.microsoft.com/en-us/onedrive/developer/controls/file-pickers/?view=odsp-graph-online)
- Minimum permissions: "At a minimum you must request the SharePoint MyFiles.Read permission". OneDrive read = `SharePoint.MyFiles.Read` or `Graph.Files.Read`; write = `MyFiles.Write` or `Files.ReadWrite`. "The file picker always operates using delegated permissions." — [File Picker overview](https://learn.microsoft.com/en-us/onedrive/developer/controls/file-pickers/?view=odsp-graph-online)
- Consumer configuration: authority `https://login.microsoftonline.com/consumers`; token scope `OneDrive.ReadWrite` or `OneDrive.ReadOnly`; baseUrl `https://onedrive.live.com/picker`. The app registration itself requests `Files.Read`/`Files.ReadWrite`. — [File Picker overview](https://learn.microsoft.com/en-us/onedrive/developer/controls/file-pickers/?view=odsp-graph-online)
- Business: baseUrl is a SharePoint web or the user's OneDrive (for example `https://tenant-my.sharepoint.com`). "Currently the control relies on SharePoint tokens and not Graph, so you will need to ensure your resource is correct and you cannot reuse tokens for Graph calls." The host POSTs a form, with an `access_token` hidden input that is "required when using an iframe". — [File Picker overview](https://learn.microsoft.com/en-us/onedrive/developer/controls/file-pickers/?view=odsp-graph-online)
- Messaging: `messaging.origin` (the host origin, used as the postMessage target) plus a unique `channelId`. The picker sends `initialize` and a MessagePort. Commands such as `authenticate`, `pick` and `close` must be acknowledged and answered. — [File Picker overview](https://learn.microsoft.com/en-us/onedrive/developer/controls/file-pickers/?view=odsp-graph-online)
- Pick results are guaranteed to include `id`, `parentReference.driveId` and `@sharePoint.endpoint`; the client builds `endpoint/drives/{driveId}/items/{id}`. If the app has `Files.ReadWrite.All`, an upload widget appears. — [File Picker overview](https://learn.microsoft.com/en-us/onedrive/developer/controls/file-pickers/?view=odsp-graph-online)
- Schema (sdk "8.0"; ms.date 2024-04-08):
  - Selection and type: `typesAndSources.mode: "files" | "folders" | "all"`; `filters` (for example `.xlsx`, `folder`); `access.mode: "read" | "read-write"`; `selection.mode: "single" | "multiple" | "pick"`.
  - Commands: `commands.pick.action: "select" | "share" | "download" | "move"`, with `select.urls.download` to return download URLs; `upload`, `createFolder`, `browseThisDevice`, `switchAccount`.
  - Tray: `tray.prompt` values include `"save-as"`, with `tray.saveAs.fileName` and `tray.conflicts.mode: "warn" | "block" | "accept" | "none"`.
  - Theme: `theme: "default" | "dark" | "lists"`.
  - Pivots: `photos` is consumer-only; `site` and `myOrganization` are OneDrive for Business only.

  — [v8 schema](https://learn.microsoft.com/en-us/onedrive/developer/controls/file-pickers/v8-schema?view=odsp-graph-online)
- Samples: [aka.ms/OneDrive/samples/file-picking](https://aka.ms/OneDrive/samples/file-picking) (linked from the overview).

### Inferences
- "Save as to OneDrive" from the WASM editors looks achievable with the picker in folder mode plus `tray.prompt: "save-as"` (the user picks a folder and filename), followed by a Graph upload. The docs give only the schema, not a worked save-as walkthrough.
- Each self-hosted install has a different origin. The picker needs the real host origin in `messaging.origin` and a token from an app registered for that origin. That ties into the redirect-URI constraints in section 5.
- The picker docs ask for `Files.Read.All`/`Sites.Read.All`, which MC1097272 now blocks for user consent in default tenants. Using the lower `MyFiles.Read` / `Files.Read` path (OneDrive-only) may avoid admin consent but limits browsing to the user's OneDrive.

### Gaps
- I found no explicit "current version" statement beyond `sdk: "8.0"`; the overview page was last updated 2024-06-17.
- The docs don't describe CORS or third-party-cookie behaviour of the iframe-hosted picker (for example Safari/Firefox storage partitioning).
- I didn't confirm whether the consumer picker supports `tray.prompt: "save-as"` and folder mode the same way as business.

## 5. Browser: SPA (MSAL.js + PKCE) calling Graph for download/upload, CORS, and redirect URIs for self-hosted origins

### Takeaway
A SPA can call Graph JSON endpoints directly with a bearer token. For file bytes, the documented pattern is to avoid `/content` (its 302 breaks CORS preflight) and instead fetch the pre-authenticated `@microsoft.graph.downloadUrl`, and to PUT chunks to the pre-authenticated `uploadUrl` **without** an Authorization header. That pattern depends on embedded-token URLs, which MC1492958 retires for Graph file APIs from April 2027, so the browser download path must be re-validated then. Redirect URIs must be registered exactly; wildcards are not allowed for apps that also sign in personal accounts, and those apps are capped at 100 redirect URIs. Arbitrary customer-hosted origins therefore can't each be registered on one Aegean-owned multi-account app.

### Cited Findings
- `/content` returns "302 Found ... redirecting to a preauthenticated download URL". "Preauthenticated download URLs are valid for a limited time. Use them immediately, as they might expire within minutes. You don't need to include an Authorization header." — [Download driveItem content (updated 2025-08-27)](https://learn.microsoft.com/en-us/graph/api/driveitem-get-content?view=graph-rest-1.0)
- "To download files in a JavaScript app, you can't use the /content API, because this responds with a 302 redirect. A 302 redirect is explicitly prohibited when a CORS preflight is required, such as when providing the Authorization header." Instead select `@microsoft.graph.downloadUrl` (`GET /drive/items/{id}?select=id,@microsoft.graph.downloadUrl`) and fetch it; "Because these URLs are preauthenticated, they can be retrieved without a CORS preflight request." A Range header goes on the downloadUrl itself. — [Download driveItem content](https://learn.microsoft.com/en-us/graph/api/driveitem-get-content?view=graph-rest-1.0)
- Developers hitting missing `Access-Control-Allow-Origin` when following the redirect were advised to use the downloadUrl. — [Microsoft Q&A 1573131](https://learn.microsoft.com/en-us/answers/questions/1573131/cross-origin-request-blocked-javascript-frontend-i)
- Upload sessions:
  - Least privilege is `Files.ReadWrite` for both account types.
  - Fragments must be under 60 MiB and "MUST be a multiple of 320 KiB (327,680 bytes)"; recommended size is 5-10 MiB; resumable upload is recommended above 10 MiB.
  - "If you include the Authorization header when issuing the PUT call, it might result in an HTTP 401 Unauthorized response... Don't include it when issuing the PUT call."
  - Optimistic concurrency: `if-match` with eTag/cTag gives `412`.
  - `@microsoft.graph.conflictBehavior` is fail/replace/rename; name conflicts return `409 nameAlreadyExists`.
  - `deferCommit` completion differs: a zero-length POST works on OneDrive for Business/SharePoint, a PUT on OneDrive Personal.

  — [createUploadSession (updated 2026-08-11)](https://learn.microsoft.com/en-us/graph/api/driveitem-createuploadsession?view=graph-rest-1.0)
- From 1 April 2027, Graph download/content and createUploadSession APIs "will no longer return URLs that contain embedded authentication information and will no longer issue HTTP 302 redirects", and "will instead return content directly". — [MC1492958 mirror](https://mc.merill.net/message/MC1492958)
- Redirect URI rules:
  - Wildcards "are currently unsupported in app registrations configured to sign in personal Microsoft accounts and work or school accounts"; they are allowed only for work/school-only apps (via the manifest) and are discouraged.
  - Limits: 256 redirect URIs for work/school audiences, **100** for `AzureADandPersonalMicrosoftAccount`; 256 characters per URI; "can't be raised for security reasons".
  - Query parameters are not allowed for apps that sign in personal accounts.
  - HTTPS is required except for localhost.
  - Microsoft's suggested workaround for many subdomains is a single "shared" redirect URI plus an integrity-protected `state` parameter (warning: open-redirector risk).
  - SPAs use the "Single-page application (SPA)" platform type.

  — [Redirect URI best practices and limitations (updated 2026-06-15)](https://learn.microsoft.com/en-us/entra/identity-platform/reply-url)
- A Microsoft Q&A answer (2021) says wildcard redirect URIs are not supported by AAD/B2C and suggests listing each subdomain (subject to the limit). — [Microsoft Q&A 652275](https://learn.microsoft.com/en-us/answers/questions/652275/azure-ad-or-azure-ad-b2c-redirection-url-for-multi)

### Inferences
- **Self-hosted installs:** a single Aegean-owned multi-tenant + personal app registration can't list every customer origin (100-URI cap, no wildcards). Realistic options:
  - (a) Each self-hosting customer registers their own Entra app and enters its client ID in Aegean Office configuration. This is the natural fit for work/school tenants and also lets the tenant admin consent.
  - (b) An Aegean-hosted central auth/redirect origin (for example `auth.aegeanlogic...`) that receives the code and hands off to the customer origin, using the protected-`state` pattern. This adds an Aegean-run service in the path and is open-redirect-sensitive.
  - (c) For the desktop app, a "Mobile and desktop" public client with loopback redirect (port ignored for localhost) needs no per-install registration.
- MSAL.js auth-code + PKCE in a SPA should be fine for calling Graph JSON endpoints (Graph returns CORS headers for bearer-token requests; the only documented CORS problem is the 302 on `/content`). This is inferred from the get-content doc; no explicit CORS reference page was fetched.
- **April 2027 risk:** once Graph returns content directly instead of 302 to a tempauth URL, a SPA would download with `fetch(…/content, {headers: {Authorization}})`. That works only if the Graph response then carries CORS headers. The upload-session PUT may need an Authorization header (or a SharePoint-resource token) instead of relying on the pre-authenticated `uploadUrl`. Both need testing against the tenant opt-in controls when they ship.
- Saving back from the browser: use `if-match` with the eTag read at open time to detect concurrent edits (412), similar to Nextcloud ETag handling.

### Gaps
- I didn't fetch MSAL.js (msal-browser) docs. Current version, PKCE defaults and third-party-cookie / silent-renew behaviour across browsers are not covered here.
- I found no source on CORS behaviour of `uploadUrl` PUTs from browsers (it is widely used by Microsoft samples, but no official CORS statement).
- MC1492958's effect on OneDrive personal and on browser/CORS flows isn't stated.

## 6. Can a third-party web app appear in OneDrive web's "Open with" menu (File Handlers)?

### Takeaway
File Handlers (v2.0) are **not** retired as of the April 2026 doc revision. They are still documented as GA for SharePoint Online and OneDrive for Business, and "Not available" for OneDrive personal. They are registered as an `addIns` manifest on the tenant-visible Entra app, so a third-party editor can add "open"/"preview"/custom actions for .xlsx/.docx/.pptx in work/school OneDrive. The user's belief that they were retired is not supported by the sources found.

### Cited Findings
- File Handlers let you add custom file icons, create-new, preview, "Rich view/edit capability (all file extensions)", and "Custom actions that launch into your app (all file extensions)" in OneDrive for Business and SharePoint document libraries. — [Integrate with OneDrive file handlers (updated 2026-04-27)](https://learn.microsoft.com/en-us/onedrive/developer/file-handlers)
- Availability table: SharePoint Online and OneDrive for Business are GA for both File handlers 2.0 and 1.0. **OneDrive personal: "Not available"** for both. Outlook Web App: 1.0 GA, 2.0 not available. — [File handlers](https://learn.microsoft.com/en-us/onedrive/developer/file-handlers)
- Mechanics:
  - The manifest is registered in the `addIns` collection of the Entra application object (version "2").
  - At runtime Office 365 POSTs `application/x-www-form-urlencoded` activation parameters (`cultureName`, `client`, `userId`, `domainHint`, `items` as Graph URLs) to the handler endpoint.
  - "File Handler configurations are aggressively cached... It may take 24-48 hours for any configuration changes to take effect."
  - Item URLs "contain a token embedded in the URL".

  — [File handlers](https://learn.microsoft.com/en-us/onedrive/developer/file-handlers)
- Searches turned up no retirement announcement for File Handlers. The related retirements found were the legacy SharePoint file APIs (2023, after April 2024) and the April 2027 tempauth URL change (MC1492958). — [M365 Dev Blog 2023](https://devblogs.microsoft.com/microsoft365dev/retirement-of-older-sharepoint-file-services-versions); [MC1492958](https://mc.merill.net/message/MC1492958)

### Inferences
- For work/school customers, Aegean Office could register a File Handler with custom "Open in GridLogic/WordLogic/SlideLogic" actions for Office extensions. The tenant must use (consent to) the Aegean app registration that carries the manifest, and the handler endpoint must be one reachable URL. That points toward an Aegean-hosted landing endpoint, or per-tenant registrations pointing at each self-hosted install.
- The activation `items` URLs carry embedded tokens, so MC1492958 (April 2027) could affect File Handler activation as well. Watch for updates.
- No equivalent exists for OneDrive personal.

### Gaps
- I couldn't confirm whether the user's recollection of a retirement refers to something specific (for example the "Open in" integration for Office 365 Outlook Web App add-ins, or a File Handlers change for Teams). No Message Center notice was found. Recommend checking the Microsoft 365 Message Center directly.
- I found no info on whether File Handler custom actions for built-in Office extensions (.docx/.xlsx/.pptx) appear in the main "Open" menu or only in a secondary action menu in the current OneDrive web UI.
