# @mentions in comments: design

Status: built on branches `gl/mentions`, `wl/mentions`, `sl/mentions` and the Nextcloud apps'
`mentions`, 2026-10-19; merged into each repo's `main` 2026-10-20. Applies to GridLogic, WordLogic and SlideLogic and their Nextcloud
apps. Fork-specific (Aegean Office), modelled on how Microsoft 365 behaves.

## What the user sees (the Office behaviour we match)

1. In a comment or a reply, typing `@` at the start of a word opens a people list under the
   text box. Typing more letters narrows it (name, user id or email). Up and Down move, Enter or
   Tab picks, Escape closes, clicking picks.
2. Picking puts `@Display Name` into the text, drawn as a mention (accent colour) in the comment
   cards. Editing a character inside a mention turns it back into plain text, as in Office.
3. Posting the comment notifies each mentioned person: a Nextcloud notification (bell, mobile
   push) and an email, both saying who mentioned them, in which file, with the comment text and a
   link that opens the file at that comment.
4. Editing a comment tells only the people newly mentioned in it. If a mentioned person can't open the file, a dialog asks before anything is sent:
   "Share and notify" (shares the file with them, can edit, then notifies) or "Don't share"
   (the comment is posted, they aren't notified). Office does the same.
5. Mentions work for files in Nextcloud, opened in the browser or from the desktop app signed in
   to Nextcloud. For a local file, or for a visitor on a public link, `@` is just text, and the
   list says why ("Save the file to Nextcloud to mention people").
6. Mentions are kept in the file the way Office keeps them, so they survive a round trip through
   Excel, Word and PowerPoint (below).

Not done (Office has it): "Assign to" (turning a mention into a task) and reactions.

## Who can be mentioned

Nextcloud users only (sharee type 0), found with the sharees API the Share dialog already uses
(`apps/files_sharing/api/v1/sharees`, `itemType=file`, `shareType[]=0`). That API applies the
server's sharing rules (same group only, no enumeration, and so on), so the list never shows
people the user couldn't share with. Groups, emails and federated users aren't offered: a
mention needs one person who can be notified.

## The person record

```
Person { name: display name, id: Nextcloud uid, email: optional }
```

In the files, `userId` is the uid and `providerId` is `"Nextcloud"`. Office ignores providers
it doesn't know; it uses `userId`/`providerId` only to match people to its own directory.

## Host contract (bridge `*:cloud` ops)

Two new ops on the existing `Cloud` request/response channel (`gridcraft:cloud`,
`wordcraft:cloud`, `deckcraft:cloud`), answered by the Nextcloud page (`share.js`) in the
browser and by `nextcloud.rs` in the desktop app:

| Op | Params | Answer |
|---|---|---|
| `people.search` | `{query}` | `[{id, name, email?, profile?}]` (`profile`: their page, `/u/<uid>`) |
| `mention.notify` | `{people: [id], text, anchor}` | `{notified: [id], noAccess: [{id, name}]}` |

- `share.info` gains `mentions: bool` (true when the file is in Nextcloud and the user is signed
  in and not a link visitor). The editor asks for it once, when a comment box first gets `@`.
- `text` is the comment text, cut to 1,000 characters. `anchor` is the app's comment address,
  passed back as `?comment=` when the link is opened (GridLogic `Sheet1!B3`, WordLogic the
  comment's durable id, SlideLogic the comment's GUID).
- Users the server finds without access come back in `noAccess`; nothing is sent to them. After
  "Share and notify" the editor runs the existing `share.add` for each (user share, can edit) and
  calls `mention.notify` again with just them.

## Nextcloud app (each of gridcraft, wordcraft, deckcraft)

- `POST /apps/<app>/mention` (`MentionController`, signed-in users only, rate-limited to 60 an
  hour per user, at most 20 people a call): checks the caller can see `fileId`, and for each uid
  checks the user exists, isn't the caller and can see the file
  (`IRootFolder::getUserFolder(uid)->getFirstNodeById(fileId)`). Sends:
  - a notification (`OCP\Notification`, app `<app>`, object `file/<fileId>`, subject `mention`)
    whose link opens `/apps/<app>/edit?path=<their path>&comment=<anchor>`;
  - an email (`IMailer` with an `EMailTemplate`), when the user has an address and the app config
    `mention_email` isn't `no`.
- `Notifier` (`INotifier`) renders the notification in the user's language: "{actor} mentioned
  you in {file}", the comment text as the message, the app icon.
- The editor page passes `comment` from its URL to the iframe; the app opens the comments pane
  and selects that comment once the file is loaded.

## In each file format

- **XLSX** (MS-XLSX threaded comments): a mention is
  `<mentions><mention mentionpersonId="{person}" mentionId="{guid}" startIndex="n" length="n"/></mentions>`
  inside `threadedComment`, with offsets in UTF-16 units of `<text>`, and the person in
  `xl/persons/person.xml` (`displayName`, `id`, `userId`, `providerId`). Only threaded comments
  carry mentions; a note's `@` is text, as in Excel.
- **DOCX**: a mention is a hyperlink in the comment body to `mailto:<email>` (or the user's
  Nextcloud profile, `<server>/u/<uid>`, when there's no email) whose run has the character style
  `Mention`; the style is added to `styles.xml` when missing.
- **PPTX**: PowerPoint's modern comment schema (MS-PPTX `p188`) has no mention element; the text
  keeps `@Display Name` as a run, and SlideLogic records the spans in the comment's own `extLst`
  under its own URI (`{A3C6E1F2-6B1D-4C9A-9E35-AE6E0FFC1D01}`, `al:mentionLst` with `start`,
  `len`, `name`, `userId`, `providerId`), which PowerPoint should skip as an unknown extension.
  Comment ids (the `cm`/`reply` GUIDs) are kept, so a link still finds its comment after a save.
  Not checked against PowerPoint itself yet: how PowerPoint stores its own mentions isn't in the
  published schema, so a mention made in PowerPoint reads as plain `@Name` text here.
- Native formats (`.scjson`, WordLogic state, `.deckcraft`) carry the same fields through serde.

## Co-editing

Mentions are part of the comment, so they travel wherever the comment already travels. GridLogic
(to 2) and SlideLogic (to 4) raise `collab::PROTOCOL`, because older builds would drop the new
fields; WordLogic's mentions are runs and a style, which its ops already carry. Notifications are sent
by the person who posts, once, never by the replicas that receive the comment.
