# Chat and calls in the editors (Nextcloud Talk): design

Status: built on the Nextcloud apps' `talk` branches (gridcraft-nextcloud 0.11.0,
wordcraft-nextcloud 0.10.0, deckcraft-nextcloud 0.7.0), 2026-10-20; merged into `main`
2026-10-20, with the desktop apps' "Chat about this file" (`*/talk-desktop`). Checked
against Talk 24.0.6 on Nextcloud 34. Step 1 of making Aegean Office feel like Teams. Built on
Talk's APIs, not a fork of Talk, so the apps keep their own licences and Talk stays upgradable.

## What the user sees

1. Above the editor, beside "who's editing", are **Call** and **Chat**. They appear only when
   the server has Talk.
2. **Chat** opens a panel beside the editor (over it on a narrow screen). It holds the
   conversation Talk keeps for the file: the same one as the Files sidebar's Chat tab, and the
   one listed in Talk under the file's name. Everyone the file is shared with is in it, and
   guests on a link to the file.
3. Messages show who sent them and when, grouped by person, with day headings and a "New
   messages" line above what was unread when the panel opened. Links are clickable; edits and
   deletions show as Talk shows them. Scrolling up loads older messages.
4. Typing `@` lists the people Talk offers (the file's people, and "everyone in this chat").
   Enter or Tab picks; the message goes to Talk with a proper mention, which Talk notifies.
5. With the panel closed, Chat shows the unread count; it turns red when someone mentioned you.
6. **Call** starts the file's call, or **Join call** (green) joins the one going on, in a Talk
   window beside the editor. Talk asks for camera and microphone, then joins.
7. A file shared with nobody has no chat yet. The panel says to share it, and the chat appears
   on its own (within 30 s) once it's shared. A link to a folder has no chat: Talk keeps chats
   for files shared on their own.

## How (src/talk.js, the same in the three apps)

| Step | Talk API (OCS, `apps/spreed/api/…`) |
|---|---|
| Is Talk here? | `spreed` in the capabilities the page carries |
| The file's conversation | `v1/file/{fileId}` (signed in) or `v1/publicshare/{shareToken}` (a link) → `token` |
| Join (become a participant) | `POST v4/room/{token}/participants/active {force: false}`; 409 (this browser is in the call in another window) is fine |
| Guest name | `POST v1/guest/{token}/name` |
| Unread, call going on, permissions | `GET v4/room/{token}`, every 30 s (2 min when the tab is hidden) |
| Messages | `GET v1/chat/{token}`: the last 50, then long polling (`lookIntoFuture=1`, 30 s) while the panel is open |
| Post | `POST v1/chat/{token} {message, referenceId}`; mentions as `@"id"` |
| Read | `POST v1/chat/{token}/read` while the panel is open and the tab visible |
| `@` list | `GET v1/chat/{token}/mentions` |
| Call | open `/call/{token}#direct-call` in a window named for the conversation |

The page never leaves the conversation: leaving would end a call this browser has in a Talk
window (Talk keeps one session per conversation per browser session). Talk tidies up idle
sessions itself.

## Two gaps in Talk, filled by the apps

Both go through the apps' existing `POST /apps/<app>/mention` (`MentionService`), with `where`:

- `chat`: **someone @mentioned who wasn't in the chat yet.** Talk adds them to the
  conversation, but with their read marker already past the message, so its notification is
  deleted the first time it's shown (Talk 24; `Notifier::shouldMentionedUserBeNotified` →
  `addUsers`, then `parseChatMessage` drops a notification at or below the read marker). Before
  posting, the panel checks who's in the conversation (`GET v4/room/{token}/participants`); after
  posting, the app tells the newcomers: "Ann mentioned you in the chat about Budget.xlsx", plus
  an email unless `mention_email` is `no`, with a link that opens the file with the chat open
  (`/apps/<app>/edit?path=…&chat=1`).
- `call`: **a call started about the file.** Talk never sends call notifications for a file's
  conversation (`Notification\Listener::checkCallNotifications`). When this person's Call
  button started the call, the panel watches for it to go live (every 3 s, for a minute) and the
  app tells the people in the conversation who aren't in the call: "Ann started a call about
  Budget.xlsx", no email, same link.

Signed-in users on the file's own page only (the route needs a user and the file in their
files). Guests on a link and signed-in users on a link get Talk's own behaviour. If Talk fixes
the first gap, people will get two notifications for a first mention; drop the `chat` call then.

## Not done

- The desktop apps: "Chat about this file" (beside Share) opens the file's conversation in the
  browser; a native chat pane would need the same API from Rust.
- The call inside the editor page (Talk's call view embedded), rather than a Talk window.
- Reactions, replies, threads, file attachments and message editing from the panel (Talk has
  them; "Open in Talk" is one click away).
- Faster unread counts with the panel closed (30 s now): long polling while closed would hold a
  PHP worker per open document.
