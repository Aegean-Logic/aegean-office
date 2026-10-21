# OneDrive co-authoring protocols, third-party access, and precedents from other office suites (state as of October 2026)

Research notes compiled 2026-10-19. Page "updated_at" dates are taken from Microsoft Learn page metadata where available. Items drawn from background knowledge rather than a fetched source are marked "(unverified)" and listed under Inferences or Gaps, not Cited Findings.

## 1. How desktop Office co-authoring with OneDrive/SharePoint works (MS-FSSHTTP / Cell Storage, MS-FSSHTTPB, WOPI, AutoSave), openness, and third-party implementations

### Takeaway
Desktop Office co-authoring against SharePoint/OneDrive runs over MS-FSSHTTP ("Cobalt", File Synchronization via SOAP over HTTP) with its binary payload MS-FSSHTTPB. Both are publicly documented in Microsoft Open Specifications, with a copyright licence to implement, but patent coverage is not automatically granted. In theory a non-Microsoft *server* could speak it. A non-Microsoft *client* co-authoring live with Word/Excel/PowerPoint users would have to reproduce Office's internal partitioned document model on the wire, and no production third-party client that does this was found. Microsoft's own route for third parties into Office co-authoring is server-side only: CSPP / CSPP Plus "WOPI extensions for coauthoring", for storage hosts.

### Cited Findings
- MS-FSSHTTP "enables one or more protocol clients to synchronize changes done on shared files stored on a server". The current published revision is 17.2 (Minor), dated 2/18/2025, preceded by 17.1 (11/12/2024) and 17.0 (Major, 8/20/2024), with revisions back to 0.1 (7/13/2009). Page metadata updated 2025-07-11. — [MS-FSSHTTP, Microsoft Learn Open Specifications](https://learn.microsoft.com/en-us/openspecs/sharepoint_protocols/ms-fsshttp/05fa7efd-48ed-48d5-8d85-77995e17cc81)
- Open Specifications IP notice on that page:
  - Copyright: you may copy the documentation "in order to develop implementations of the technologies that are described".
  - Microsoft "does not claim any trade secret rights".
  - Patents: Microsoft "has patents that might cover your implementations"; the notice "does not grant any licenses under those patents". A given document "might be covered by" the Open Specifications Promise or Community Promise (see the Patent Map); otherwise patent licences are available by contacting iplg@microsoft.com.
  - Trademarks are not licensed.
  — [MS-FSSHTTP IP notice](https://learn.microsoft.com/en-us/openspecs/sharepoint_protocols/ms-fsshttp/05fa7efd-48ed-48d5-8d85-77995e17cc81)
- Microsoft tells CSPP hosts that integrating Office for the web does not require MS-FSSHTTP: "you don't have to implement the [MS-FSSHTTP]: File Synchronization via SOAP over HTTP Protocol (Cobalt)". Office for the web talks to hosts over the plain WOPI REST endpoints. — [Integrate with Microsoft 365 for the web (CSPP), updated 2026-07-10](https://learn.microsoft.com/en-us/microsoft-365/cloud-storage-partner-program/online/overview)
- The CSPP Plus programme documents "changes and additions to the existing Web Application Open Platform Interface (WOPI) protocol to support real-time coauthoring with third-party hosts as part of Cloud Services Partner Program Plus (CSPP Plus)". This is a *host*-side extension that lets Microsoft 365 apps co-author files stored on a partner's storage. Detailed pages assume CSPP membership. — [About WOPI extensions for coauthoring, Microsoft Learn, updated 2026-06-26](https://learn.microsoft.com/en-us/microsoft-365/cloud-storage-partner-program/plus/coauthoring/coauthoring-protocol-about)
- Office for the web co-authoring among users on a partner host: "Microsoft 365 for the web supports multiuser authoring scenarios if all users are using Microsoft 365 for the web. However, you're responsible for managing conflicts that might come from applications other than Microsoft 365 for the web." This confirms that non-Office editors are expected to sit outside the co-authoring session and be handled by locking. — [CSPP online overview](https://learn.microsoft.com/en-us/microsoft-365/cloud-storage-partner-program/online/overview)
- The open-source .NET WopiHost project (petrsvihlik/WopiHost) has a `Wopi:UseCobalt` setting to "toggle whether or not to use [MS-FSSHTTP] for file synchronization". Full MS-FSSHTTP support is on its longer-term roadmap, so it is a partial, *host-side* implementation that relies on Microsoft's Cobalt assemblies. — [WopiHost README (via CodeClimate mirror)](https://codeclimate.com/github/petrsvihlik/WopiHost/README.md/source)
- A sambaXP 2023 talk ("Integrate O365") covered WOPI and the FSSHTTP protocol family for integrating Office co-authoring with third-party document hosts. Only the slide outline was retrievable. — [sambaXP 2023 slides, Xu](https://sambaXP.org/fileadmin/user_upload/sambaxp2023-Slides/Xu_sXP23_Integrate_O365.pdf)

### Inferences
- Known third-party FSSHTTP work is *server-side*: a host that lets Microsoft's Office clients co-author against non-Microsoft storage (WopiHost/Cobalt, the CSPP Plus partners, the samba-ecosystem talk). No evidence was found of a third-party *editor* that joins a live Office co-authoring session as a peer of Word/Excel/PowerPoint.
- Why such a client is impractical (based on spec structure; unverified detail):
  - MS-FSSHTTPB is a generic storage/sync layer for "cell" partitions.
  - The meaning of those partitions for Word/Excel/PowerPoint (paragraph-level locks, revision graphs, Excel's own co-authoring merge model) is Office-internal and not fully specified as an editing protocol.
  - A third party would have to emit changes Office can merge, in Office's native model, without the Office object model.
  - This is a reverse-engineering project, not an integration.
- AutoSave in desktop Office is just the UI face of this cell-storage channel being on continuously when the file is in OneDrive/SharePoint (background knowledge; unverified). No third-party hook into AutoSave exists.
- Patents remain a risk for an MS-FSSHTTP implementation unless the document is confirmed on the Open Specifications Promise patent map.

### Gaps
- Not verified: whether MS-FSSHTTP/FSSHTTPB are specifically listed under the Open Specifications Promise in the Patent Map. That needs a check of https://aka.ms/AA9ufj8.
- Not verified: whether OneDrive *consumer* (not SharePoint/ODB) still exposes the public MS-FSSHTTP endpoint (`_vti_bin/cellstorage.svc`) or uses a different internal path. No 2026 source found.
- No published third-party client (open source or commercial) found that co-authors live with desktop Office. The absence is suggestive, but a search budget limit means it is not proof.
- Not fetched: the MS-FSSHTTPB page itself (separate Open Specs page), so its current revision is not recorded here.

## 2. WOPI and the Cloud Storage Partner Program (CSPP): host vs client, can a third-party editor be the editor for OneDrive files, requirements and costs

### Takeaway
Confirmed: CSPP is for *storage providers (WOPI hosts)* who want to embed Microsoft's editors (Office for the web, Microsoft 365 mobile, desktop via CSPP Plus) in their own storage. It does not let a third-party editor become a WOPI *client* (editor) for OneDrive or SharePoint Online. Microsoft does not offer that, and OneDrive has no setting for a custom WOPI client URL. The closest supported way into the OneDrive for Business / SharePoint Online web UI is **File Handlers 2.0**, a Microsoft 365 add-in registered on an Entra app. It is not available for OneDrive personal. On-premises SharePoint Server *can* be re-bound to a third-party WOPI client such as Collabora.

### Cited Findings
- "The Microsoft 365 - Cloud Storage Partner Program is for independent software vendors whose business is cloud storage. It's not open to Microsoft 365 customers directly." A cloud storage provider must:
  - develop, own and operate a product with cloud file storage
  - offer it as SaaS
  - store end-user files at rest in a location the partner owns or leases, not the customer's
  - own the WOPI host domain URLs
  - manage identity
  - serve more than one external customer

  "Every application is individually reviewed for suitability by the CSPP team." The programme is governed by the CSPP Integration Terms. — [CSPP: Integrate with Microsoft 365 for the web, updated 2026-07-10](https://learn.microsoft.com/en-us/microsoft-365/cloud-storage-partner-program/online/overview)
- Mandatory scope: participants "must support upload, download, viewing, and editing in Microsoft Word, Excel and PowerPoint for the web even if the published partner solution will only show a subset". — [CSPP online overview](https://learn.microsoft.com/en-us/microsoft-365/cloud-storage-partner-program/online/overview)
- Integration consists of reading WOPI discovery XML, implementing the *server side* of WOPI REST endpoints, and providing a host page that wraps Office for the web in an iframe. Other requirements:
  - proof keys
  - SSL
  - POST with the access token in the body
  - persistent URL-safe file IDs
  - file versions

  — [CSPP online overview](https://learn.microsoft.com/en-us/microsoft-365/cloud-storage-partner-program/online/overview); [WOPI requirements](https://learn.microsoft.com/en-us/microsoft-365/cloud-storage-partner-program/online/wopi-requirements)
- Licensing: "Any user who will edit files using a Microsoft 365 app must have a valid Microsoft 365 license. CSPP partners are responsible for ensuring all of their users have the appropriate license", including programmatic checks for business users. — [CSPP online overview](https://learn.microsoft.com/en-us/microsoft-365/cloud-storage-partner-program/online/overview)
- CSPP also covers Microsoft 365 for mobile integration. — [Integrate with Microsoft 365 for mobile](https://learn.microsoft.com/gl-es/microsoft-365/cloud-storage-partner-program/mobile/overview)
- Registration: [Microsoft 365 Cloud Storage Partner Program sign-up](https://developer.microsoft.com/office/cloud-storage-partner-program)
- File Handlers 2.0 (Microsoft 365 add-in):
  - Supported features: "Customized file icons", "Create new files", "File preview" (proprietary extensions only), "Rich view/edit capability (all file extensions)", and "Custom actions that launch into your app (all file extensions)".
  - The handler is a provider-hosted web endpoint on any stack. Its manifest is registered in the `addIns` collection of an Entra (Azure AD) application.
  - At runtime Office 365 POSTs activation parameters (`client`, `userId`, `domainHint`, `items` = Microsoft Graph URLs with embedded tokens) to the handler, which then uses Graph.
  - Configurations are cached for 24–48 hours.
  - Availability: SharePoint Online GA, OneDrive for Business GA, **OneDrive personal: Not available** (both 1.0 and 2.0).

  — [Integrate with OneDrive file handlers, Microsoft Learn, updated 2026-04-27](https://learn.microsoft.com/en-us/onedrive/developer/file-handlers)
- Collabora's precedent for SharePoint *Server* (on-premises): bind Collabora Online as the WOPI client with `New-SPWOPIBinding -ServerName <host:port> -Extension ODT` per extension. Requires Collabora Online 4.2.5+ and proof-key support. — [Collabora: WOPI binding for Collabora Online in SharePoint 2016 Server](https://www.collaboraonline.com/blog/how-to-wopi-binding-for-collabora-online-in-sharepoint-2016-server/); compatibility with SharePoint 2019/Subscription Edition is unconfirmed in [Collabora forum thread](https://forum.collaboraonline.com/t/collabora-online-with-recent-sharepoint-versions-subscription-edition-2019-feedback/4625)
- Collabora markets itself as a replacement for Microsoft Office Online Server, which it says "ends 1 January 2027". — [Collabora blog](https://www.collaboraonline.com/blog/microsoft-office-online-server-ends-1-january-2027-get-the-self-hosted-alternative-now/)
- A LibreOffice Online article reported finding no option in OneDrive to enter a custom WOPI client URL. It is older and undated in the snippet. — [id.nl article](https://id.nl/huis-en-entertainment/computer-en-gaming/software/samenwerken-in-de-cloud-met-libreoffice-online)

### Inferences
- Aegean Office cannot become "the editor" behind OneDrive/SharePoint Online's built-in Office open action via WOPI. That binding is Microsoft-controlled in the cloud and only exists for on-premises SharePoint Server, which also loses its Microsoft WOPI client (Office Online Server) on 1 Jan 2027 per Collabora.
- Aegean Office could join CSPP only as a *storage host*, embedding Microsoft's editors. That conflicts with its purpose, and it would not qualify as a "business is cloud storage" ISV.
- **File Handlers 2.0 is the realistic deep-UI hook** for business tenants. An "Open in WordLogic/GridLogic/SlideLogic" custom action, or open/preview for ODF and other extensions, would appear in OneDrive for Business / SharePoint document libraries. The handler is a hosted web app, which suits the WASM browser editors, and it reads and writes via Graph. It requires a multi-tenant Entra app plus per-tenant admin consent and registration. It does not exist for personal OneDrive accounts.
- No CSPP fee was stated in the fetched docs. The cost is engineering, review and compliance plus the users' Microsoft 365 licences.

### Gaps
- CSPP fees: no fee is mentioned in the fetched pages. The CSPP Integration Terms (cspp-terms) were not fetched.
- Not confirmed: whether a file handler can take over the *default* open action for .docx/.xlsx/.pptx in OneDrive for Business, or only add a secondary action. "Rich view/edit capability (all file extensions)" suggests yes for view/edit, but the define-actions page was not fetched.
- Not confirmed: whether file handlers are planned to be deprecated. No deprecation notice was found and the page was updated 2026-04-27. A file-handler registration still requires Entra app manifest editing or tenant admin steps (register-manually page not fetched).

## 3. File locking on OneDrive: Graph locks, SharePoint checkout/checkin, Office's co-authoring shared locks, and whether third parties can detect live Office co-authoring

### Takeaway
Microsoft Graph has no general advisory lock/lease API for driveItems. The nearest equivalent is **checkout/checkin**, a SharePoint document-library concept exposed on Graph driveItem. It is heavy-handed: it blocks other editors and hides changes until check-in. Office's co-authoring locks (shared "coauth"/schema locks in MS-FSSHTTP, WOPI Lock/RefreshLock on CSPP hosts) are internal to the Office/SharePoint channel. No supported Graph property was found that reports "this file is currently open for co-authoring in Office".

### Cited Findings
- `POST /drives/{driveId}/items/{itemId}/checkout`: "Check out a driveItem resource to prevent others from editing the document, and prevent your changes from being visible until the document is checked in."
  - Permissions: Files.ReadWrite (delegated, work/school *and* personal Microsoft account listed); Files.ReadWrite.All (application).
  - Returns 204.
  - Page updated 2025-07-23.

  — [driveItem: checkout, Microsoft Graph v1.0](https://learn.microsoft.com/en-us/graph/api/driveitem-checkout?view=graph-rest-1.0)
- For CSPP hosts, Microsoft expects the *host* to handle conflicts from non-Office apps with "some form of file locking or use another type of conflict resolution". On those hosts the WOPI Lock operations are the host's lock primitive. — [CSPP online overview](https://learn.microsoft.com/en-us/microsoft-365/cloud-storage-partner-program/online/overview)
- Google's precedent for "who else has this Office file open": Drive for desktop's **Real-time presence in Microsoft Office**.
  - Shows in the bottom-right of Word/Excel/PowerPoint (Office 2010+) when others are viewing or editing a shared Drive file, and alerts when a newer version is saved.
  - Admins can disable it per domain/OU; launched September 2018.
  - Conflicts are surfaced as side-by-side versions, not merged live.

  — [Google Drive Help: Work with Microsoft Office files](https://support.google.com/drive/answer/9406611); [Google Workspace Updates, Sept 2018](https://workspaceupdates.googleblog.com/2018/09/real-time-presence-in-microsoft-office.html?hl=fr)

### Inferences
- Checkout semantics on OneDrive personal versus OneDrive for Business are not clearly documented. Checkout is a SharePoint library feature, and personal OneDrive may reject it, even though the permissions table lists personal accounts (unverified; test needed).
- Checking out a file while Office users are co-authoring would likely fail or break their session. Checkout is unsuitable as a soft "Aegean Office is editing" signal.
- Practical conflict strategy for Aegean Office on OneDrive:
  - optimistic concurrency with the driveItem `eTag`/`cTag` and `If-Match` on upload
  - change detection via Graph delta queries or webhooks (subscriptions)
  - optionally, presence and soft-lock state kept in Aegean's own relay, Google-presence style, rather than in OneDrive
- Detecting active Office co-authoring: Office writes via cell storage continuously, so frequent eTag churn on a driveItem is a usable heuristic (unverified). There is no documented flag.

### Gaps
- No primary source found stating explicitly "Graph has no lock API". This is inferred from the absence of lock endpoints in the driveItem API family (only checkout/checkin), but the full driveItem method list was not fetched.
- No source found on whether Graph exposes any "currently being edited by" / activity signal. `itemActivities` / analytics APIs were not researched.
- The MS-FSSHTTP coauthoring/schema-lock subrequest names (e.g. "Coauth", "SchemaLock", "ExclusiveLock", "Coauthoring status") come from background knowledge and were not verified against the fetched page.

## 4. Realistic architectures for live co-editing among Aegean Office users on OneDrive-stored files; Fluid Framework / Azure Fluid Relay / Loop status

### Takeaway
The realistic architecture is the one Aegean already uses on Nextcloud, moved to a hosted relay:
- Session keyed by (driveId, itemId).
- Admission by proving the user's Graph access to that item, server-side, with the user's delegated token.
- The relay sequences operations and periodically writes the merged file back to OneDrive with eTag checks.
- Office users editing the same file concurrently are *not* in the session and must be handled as external conflicts.

Fluid Framework is open source and still documented. Azure Fluid Relay's status is **contested**: a single third-party page claims it was retired on 30 Sept 2025, but Microsoft's own Learn pages (updated August 2026) show no retirement notice. Treat it as unconfirmed, and in any case a JavaScript-centric choice that is a poor fit for a Rust/WASM stack.

### Cited Findings
- Microsoft's Azure Fluid Relay overview page (metadata updated 2026-08-02) still describes the service with no retirement banner:
  - "Fluid Framework is an open source, platform independent framework. Azure Fluid Relay is a managed offering for the Fluid Framework… across connected JavaScript clients."
  - Architecture: the service "is responsible for taking in data operations, sequencing the operations, and returning the sequenced operations to the clients". Each client computes state.

  — [Azure Fluid Relay overview, Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-fluid-relay/overview/overview)
- Contradicting claim: innFactory, a Microsoft partner and not a primary source, carries a "Notice" that Azure Fluid Relay "was retired on September 30, 2025. The service is no longer available", recommending Azure Web PubSub or SignalR Service. The notice cites no source, carries a disclaimer that the information "may be outdated or incomplete", and other sections still describe the service in the present tense. — [innFactory Fluid Relay page](https://innfactory.de/en/cloud/azure/products/fluid-relay/). **Contradicted by** the absence of any retirement notice on [Microsoft Learn overview (updated 2026-08-02)](https://learn.microsoft.com/en-us/azure/azure-fluid-relay/overview/overview) and [version compatibility page](https://learn.microsoft.com/en-us/azure/azure-fluid-relay/concepts/version-compatibility). No Azure Updates retirement notice was found in two searches.
- Azure Fluid Relay history: GA announced August 2022. — [Microsoft 365 Developer Blog](https://devblogs.microsoft.com/microsoft365dev/announcing-general-availability-of-azure-fluid-relay-service/); [InfoQ, Aug 2022](https://www.infoq.com/news/2022/08/azure-fluid-relay-service/)
- Fluid Framework v1 docs are marked no longer actively maintained in favour of v2. — [fluidframework.com v1 docs](https://fluidframework.com/docs/v1/deployment/azure-fluid-relay)
- Fluid Relay FAQ: no offline periods longer than one minute are supported. Transport is HTTP + WebSockets, with long-polling fallback. Data is replicated to a paired region unless the Basic SKU is chosen. — [Azure Fluid Relay FAQ (docs.azure.cn mirror)](https://docs.azure.cn/pt-br/azure-fluid-relay/resources/faq)
- Graph primitives a relay would rely on:
  - Checkout is the only lock-like call ([driveItem checkout](https://learn.microsoft.com/en-us/graph/api/driveitem-checkout?view=graph-rest-1.0)).
  - File handler activation passes Graph item URLs with embedded tokens, so a hosted relay/editor launched from OneDrive for Business receives the exact driveItem to key a session on ([file handlers](https://learn.microsoft.com/en-us/onedrive/developer/file-handlers)).
- Related Graph deprecations to avoid in a OneDrive file picker or "recent files" design:
  - Legacy SharePoint `_api/v1.0/files` / `_api/beta/files` endpoints are retired in favour of Graph drive endpoints ([Microsoft 365 Dev Blog](https://devblogs.microsoft.com/microsoft365dev/?p=15835)).
  - `/me/drive/recent` and `/me/drive/sharedWithMe` are reported deprecated, with data stopping after November 2026 (community thread, not an official notice: [Tech Community](https://techcommunity.microsoft.com/discussions/skills-hub-discussions/what-is-the-microsoft-graph-api-replacement-for-deprecated-recent-sharedwithme-a/4551294)).
  - The Microsoft Graph Toolkit File component retires 28 Aug 2026 ([Graph Toolkit file component](https://learn.microsoft.com/it-it/graph/toolkit/components/file)).

### Inferences
- **Recommended architecture: an "Aegean relay keyed by driveItem".**
  1. A client (desktop app or WASM editor) obtains a delegated Graph token (Files.ReadWrite, or Files.ReadWrite.All for shared items).
  2. The client asks the Aegean relay to join session `drive:{driveId}/item:{itemId}`. The relay verifies access by calling `GET /drives/{driveId}/items/{itemId}` (and optionally `/permissions`) *with the user's token*. Success proves read access. A write test or `permissions` roles indicate write access.
  3. The relay runs the same op-sequencing, cursor/presence and per-user undo logic as the Nextcloud app.
  4. One elected writer (the relay with a delegated token of an active editor, or the last client) saves snapshots back with `PUT .../content` plus `If-Match: eTag`.
  5. External edits (Office users, sync clients) are detected via eTag mismatch, delta queries or webhook subscriptions, and surfaced as "file changed outside Aegean – reload/merge".
  6. Join links are shared via Aegean's own invite or Graph sharing links, but authorisation always comes from Graph.

  This needs no Microsoft partnership beyond a standard multi-tenant Entra app registration. It works for personal and business OneDrive (file handlers business-only).
- Fluid Framework is a TypeScript/JS client stack with its own DDS model. Adopting it would mean rewriting Aegean's Rust collaboration core or bridging it. Given the uncertain Azure Fluid Relay status, it is not recommended. Fluid does not interoperate with Office desktop co-authoring either.
- Microsoft Loop is built on Fluid internally; there is no public third-party API to join Loop or Office co-authoring sessions (background knowledge; unverified, not researched in this pass).
- Office users and Aegean users co-editing the *same* OneDrive file simultaneously is not achievable. Best case: Aegean shows a warning when the file's eTag changes rapidly, or a Google-style "someone else is editing in Office" presence heuristic.

### Gaps
- **Azure Fluid Relay status is unresolved.** No Microsoft primary source (Azure Updates retirement notice, Learn banner) was found confirming the innFactory retirement claim, and Microsoft's own docs updated in Aug 2026 show no retirement. Before citing a date, check the Azure Updates "Retirements" feed or Azure portal Service Health for Fluid Relay. Also not established: the latest Fluid Framework 2.x release in 2026, and whether SharePoint Embedded / Loop expose Fluid containers to third parties.
- Microsoft Loop third-party/API status as of 2026 was not researched.
- Graph webhooks/delta latency for OneDrive personal vs business was not researched.

## 5. Precedents: how other suites integrate with OneDrive (ONLYOFFICE, Collabora, LibreOffice, WPS, Zoho, Google, iWork, others); co-editing; blocked or removed integrations

### Takeaway
No third-party suite was found that offers live co-editing *with Microsoft Office users* on OneDrive files. The patterns are:
- **(a) Copy-in/storage connector:** the suite's own server opens the OneDrive file via the API, co-editing happens among the suite's users in its own engine, and the result is saved back. Examples are ONLYOFFICE Workspace/DocSpace and, earlier, LibreOffice remote files.
- **(b) Local sync folder:** WPS, LibreOffice and most desktop apps rely on the OneDrive client.
- **(c) Presence overlay:** Google Drive for desktop does this for Office files on *Drive*, not OneDrive.
- **(d) WOPI client for on-premises SharePoint Server only:** Collabora.

LibreOffice's direct OneDrive support is the notable "disabled" precedent: it was merged but never enabled, citing Microsoft terms of use and API changes.

### Cited Findings
- **ONLYOFFICE DocSpace:**
  - The official FAQ says DocSpace can link Box, Dropbox and OneDrive "to use the connected account as a third-party resource when creating backups or creating public rooms". OneDrive therefore acts as a backing store for rooms.
  - The same FAQ describes ONLYOFFICE's own co-editing modes (Fast: autosave; Strict: paragraph locking) and says the document is "built and saved as DOCX, XLSX, or PPTX to the storage after all the co-authors close the document". Co-editing happens inside ONLYOFFICE's engine and the file is written back on close; the FAQ does not confirm this specifically for OneDrive.
  - Third-party storage for public rooms arrived in DocSpace v2.5 (April 2024).

  — [ONLYOFFICE DocSpace FAQ](https://helpcenter.onlyoffice.com/docspace/faq.aspx); [DocSpace 1-year retrospective](https://forum.onlyoffice.com/t/onlyoffice-docspace-turns-1-a-retrospective-report/8759)
- **ONLYOFFICE Desktop Editors:** connect to DocSpace and other clouds ("Nextcloud, ownCloud, Liferay, kDrive, Seafile"). Real-time co-editing needs an internet connection and the cloud. **OneDrive is not in the Desktop Editors direct-connection list.** — [ONLYOFFICE blog, July 2023: connect Desktop Editors to DocSpace](https://onlyoffice.com/blog/2023/07/how-to-connect-onlyoffice-desktop-editors-to-docspace)
- **ONLYOFFICE legacy:** an older help page "How to edit documents from OneDrive in ONLYOFFICE Documents" (Connectors section) existed for the Workspace/Community Server "Documents" module. The URL now returns 404 (checked 2026-10-19). — [helpcenter.onlyoffice.com/tipstricks/Connect-Onedrive.aspx (404)](https://helpcenter.ONLYOFFICE.com/tipstricks/Connect-Onedrive.aspx)
- **Collabora Online:**
  - Integrates as a WOPI client with on-premises **SharePoint Server** (2016 guide; 2019/SE unconfirmed).
  - No supported OneDrive or SharePoint Online integration was found.
  - Its list of available integrations is host-based (Nextcloud, ownCloud, etc.).

  — [Collabora Online and SharePoint](https://www.collaboraonline.com/integrations/collabora-online-and-sharepoint/); [SharePoint 2016 WOPI binding guide](https://www.collaboraonline.com/blog/how-to-wopi-binding-for-collabora-online-in-sharepoint-2016-server/); [Collabora SDK: available integrations](https://sdk.collaboraonline.com/docs/available_integrations.html)
- **LibreOffice:**
  - LibreOffice 5.1 (2016) was publicised with remote-server integration including OneDrive ([PCWorld](https://www.pcworld.com/article/419534/libreoffice-51-features-streamlined-menus-and-remote-server-support.html)).
  - In bug 62437 developers say the OneDrive code was merged but **not enabled**, because of restrictions in Microsoft's terms of use, and a patch hid the OneDrive entry ([LibreOffice Bugzilla 62437](https://bugs.libreoffice.org/show_bug.cgi?id=62437)).
  - In 2018 the OneDrive option was reported missing in 6.0.1.1 ([Bugzilla 115643](https://www.libreoffice.org/bugzilla/show_bug.cgi?id=115643)), and the old integration was described as "broken and disabled" ([Bugzilla 100031](https://www.libreoffice.org/bugzilla/show_bug.cgi?id=100031)).
  - In 2022 Arch Linux closed "Enable onedrive in remote files" as won't-implement: it needs a client/Drive ID that distros cannot supply. A third-party OneDrive extension was suggested instead ([Arch bug FS#76293](https://bugs.archlinux.org/task/76293)).
  - LibreOffice's other remote-files backend is CMIS, which also served SharePoint on-premises (background knowledge; unverified).
- **WPS Office:**
  - Vendor pages describe editing OneDrive files by opening the locally synced OneDrive folder ([WPS: connect computer or phone OneDrive](https://www.wps.com/office-quick-solution/document-file-issues/connect-computer-or-phone-onedrive/); [WPS: WPS Office and Microsoft OneDrive review](https://wps.com/blog/an-ultimate-review-wps-office-and-microsoft-onedrive)).
  - The mobile app reportedly accesses OneDrive directly ([Softpedia listing](https://mobile.softpedia.com/apk/wps-office/); third-party, unverified).
  - No OneDrive co-editing was found.
- **Google:**
  - Drive for desktop's real-time presence in Microsoft Office (2018) shows who else is viewing or editing a Drive-stored Office file and alerts on newer versions ([Google Drive Help](https://support.google.com/drive/answer/9406611); [Workspace Updates 2018](https://workspaceupdates.googleblog.com/2018/09/real-time-presence-in-microsoft-office.html?hl=fr)).
  - Google Docs/Sheets/Slides also edit Office files stored in Drive (Office editing mode) ([same help page](https://support.google.com/docs/answer/9406611)).
  - This applies to Google Drive, not OneDrive.

### Inferences
- ONLYOFFICE is the closest precedent to what Aegean wants. Its own server is the co-editing relay, and OneDrive is only a storage backend accessed through Microsoft's public API. Concurrent Office edits are not merged.
- LibreOffice's history shows the practical blockers for a desktop-suite direct OneDrive connector:
  - Microsoft's API terms
  - an app registration/client ID that cannot be embedded by redistributors
  - API churn (Live SDK to Graph)

  Aegean, as a single vendor shipping signed binaries with its own Entra app registration, avoids the distro problem but must comply with the Microsoft APIs Terms of Use.
- Most desktop suites (WPS, LibreOffice today, iWork) effectively "support" OneDrive only via the OS-level sync client: Files On-Demand on Windows/macOS, Files app providers on iOS. This is zero-integration but also zero co-editing.

### Gaps
- **Zoho** (Writer/Sheet/Show, WorkDrive): no source found on a OneDrive integration or co-editing. Searches returned nothing relevant.
- **Apple iWork:** not researched. Believed to access OneDrive only via the iOS/macOS Files/File Provider extension, with no co-editing on OneDrive (unverified).
- **ONLYOFFICE Docs connectors:** not confirmed whether any current ONLYOFFICE connector embeds ONLYOFFICE inside OneDrive/SharePoint Online (e.g. a SharePoint connector for on-premises SharePoint exists per background knowledge; unverified).
- **Collabora / LibreOffice 2024–2026:** no source on renewed OneDrive work. No release-notes check was done.
- **Blocked/removed integrations:** only the LibreOffice case is documented. No source was found for Microsoft actively blocking a third-party suite's OneDrive integration.

## 6. Microsoft terms and branding restrictions (OneDrive name/logo in a third-party app UI, "works with OneDrive")

### Takeaway
No OneDrive-specific "works with OneDrive" badge programme for third parties was found. Microsoft's general trademark guidelines:
- allow plain-text, factual references to OneDrive to describe compatibility
- forbid implying endorsement
- forbid using Microsoft logos or icons as your app icon
- require a licence to use Microsoft logos in marketing

FY26 and FY27 Microsoft 365 trademark guideline decks exist and should be checked for specifics.

### Cited Findings
- Microsoft brand assets, including logos and app/product icons, are proprietary, and "many uses… will require a license first". They "may not be used in a way that implies Microsoft published, developed, endorsed, or is otherwise connected with your app". — [Microsoft Trademark and Brand Guidelines](https://microsoft.com/legal/intellectualproperty/trademarks)
- Microsoft's logos, designs and icons "can never be used as your app icon and can only be used in your app advertisements with a license agreement in place". This is from the archived 2021–2022 version of the guidelines. The guidelines also give an acceptable example: an app description saying it lets users access OneDrive content, with no Microsoft content in screenshots. — [Microsoft Trademark guidelines (Wayback, Dec 2021)](https://webcf.waybackmachine.org/web/20211227221835/https://www.microsoft.com/trademarks); [general usage page](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general.aspx)
- Microsoft 365 trademark guidance:
  - logos "should not be altered"
  - third-party marketing may use the Microsoft 365 logo only under a logo licence agreement
  - registering similar names or logos is prohibited

  — [FY26 Microsoft 365 trademark guidelines (PDF)](https://cdn-dynmedia-1.microsoft.com/is/content/microsoftcorp/microsoft/mscle/documents/presentations/FY26_Microsoft_365_trademark_guidelines.pdf); [FY27 Microsoft 365 trademark guidelines (PDF)](https://cdn-dynmedia-1.microsoft.com/is/content/microsoftcorp/microsoft/mscle/documents/presentations/FY27_Microsoft_365_trademark_guidelines.pdf)
- The Open Specifications notice explicitly grants no trademark rights. — [MS-FSSHTTP IP notice](https://learn.microsoft.com/en-us/openspecs/sharepoint_protocols/ms-fsshttp/05fa7efd-48ed-48d5-8d85-77995e17cc81)

### Inferences
- Safe UI pattern for Aegean Office:
  - text labels such as "Open from OneDrive" or "Save to OneDrive" (factual, nominative use)
  - a generic cloud icon rather than the OneDrive logo, unless Microsoft grants a logo licence
  - no "Microsoft-certified" or "official" wording
  - product names must not resemble Microsoft marks
- The FY27 deck (Microsoft's fiscal 2027 began July 2026) is the most current document. Its OneDrive-specific rules were not read in this pass.

### Gaps
- The FY26/FY27 PDFs were not fetched, so any OneDrive-specific clauses (e.g. how to write "OneDrive" or whether a OneDrive glyph may appear in a provider picker) are unverified.
- The Microsoft APIs Terms of Use and Graph developer terms (rate limits, data handling, restrictions on competing products) were not fetched. These are relevant given the LibreOffice "terms of use" precedent.
- No source found for a formal "Works with OneDrive" / "OneDrive partner" badge programme as of 2026.
