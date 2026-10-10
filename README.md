# Samsung Notes × Claude (Samsung Notes MCP)

Lets Claude **read your Samsung Notes directly**. English port of
[kraewon7422/samsung-notes-mcp](https://github.com/kraewon7422/samsung-notes-mcp) (MIT).

- Notes written on a Galaxy tablet/phone show up too (Samsung Cloud syncs them to the Samsung Notes app on this PC)
- **Runs entirely on your computer** — notes are not sent to any outside server
- **Read-only** — Claude cannot edit or delete notes

Example:

> "Find the quadratic equations note in my Math folder and show me the first page" → Claude **looks at your handwritten working** and grades it

---

## Requirements

| What | Notes |
|---|---|
| Windows PC | Windows 10/11 |
| Samsung Notes (PC app) | Install "Samsung Notes" from the Microsoft Store → sign in to your Samsung account → confirm notes have synced |
| Claude Desktop or Claude Code | [claude.ai/download](https://claude.ai/download) |
| Python 3.10+ | The installer installs it if missing |

## Install

Double-click **`install.bat`** (if Windows SmartScreen warns you: **More info** → **Run anyway**).
When it says **"Setup complete"**, restart Claude Desktop / start a new Claude Code session.

The installer creates a private `.venv` in this folder with `mcp<2`, `pillow`
and `av` (the server uses the mcp v1 `FastMCP` API, which mcp 2.x renamed; `av` reads
recording durations), then registers
the server as `samsung-notes` in Claude Desktop and Claude Code.

## Usage — just ask

| You want to | Say to Claude |
|---|---|
| See folders | "Show my Samsung Notes folders" |
| List notes | "What's in my Math folder?" |
| Recent notes | "Show the 5 notes I edited most recently" |
| Search | "Search my Samsung Notes for history" |
| Read a note | "Read the ○○ note" |
| See handwriting (first page) | "Show the first page of the ○○ note" |
| See handwriting (any page) | "Show page 3 of the ○○ note" / "List that note's pages" |
| Get graded | "Look at page 5 of this note and grade my solutions" |
| Summarise | "Summarise the ○○ note" |
| Voice recordings | "Does the ○○ note have recordings? Where are they?" |

## Tools (11, all read-only)

| Tool | What it does |
|---|---|
| `samsung_notes_list_folders` | All folders with note counts |
| `samsung_notes_list_notes` | Notes in a folder (or all), newest first |
| `samsung_notes_recent` | Most recently modified notes |
| `samsung_notes_read_note` | Metadata + typed text, PDF text, text boxes |
| `samsung_notes_search` | Keyword search across titles and text |
| `samsung_notes_list_note_images` | Imported PDF/photo page backgrounds (no pen strokes) |
| `samsung_notes_get_page_image` | One of those background images |
| `samsung_notes_get_thumbnail` | First page as rendered by the app, **with handwriting** |
| `samsung_notes_list_pages` | Every page and whether its handwriting render is available |
| `samsung_notes_get_page` | Any page rendered **with handwriting** |
| `samsung_notes_list_recordings` | A note's voice recordings: file path, size, duration (not transcribed) |

## Troubleshooting

| Symptom | Fix |
|---|---|
| Claude says the tool doesn't exist | Restart Claude Desktop / start a new Claude Code session |
| New notes are missing | Open the Samsung Notes app on this PC once so it syncs |
| "Samsung Notes is not installed" | Install Samsung Notes from the Microsoft Store and sign in |
| Python got installed, then setup stopped | Run `install.bat` once more |
| "That page isn't ready yet" | Open the note in the Samsung Notes PC app and scroll to that page once (Samsung only saves images of pages you've viewed) |
| Anything else | Ask Claude Code "the MCP server in this folder isn't working, fix it" — `CLAUDE.md` has debugging notes |

## Security & privacy

- Note data never leaves your computer. The program has no server or account.
  (What Claude reads during a conversation is handled like any other conversation content.)
- Read-only: the original note database is never modified (it's copied to a temp file before every read).
- Locked (password-protected) notes are encrypted and can't be read.

## Limitations

- **Handwriting** isn't converted to text. Claude looks at the rendered page as an image instead.
  (For notes written on top of a PDF, the PDF's text is extracted.)
- Handwritten pages **after the first** only exist as images once you've opened the note in the
  **PC** app and scrolled to that page. Unviewed pages show as *not ready* in the page list.
  These cached images are low resolution (~286 px wide).
- **Voice recordings** are listed (path, size, length) but not transcribed.
- You see notes as of the PC app's last sync.

---

## Advanced: use from a tablet or claude.ai web (optional, not set up)

The default install works **only with Claude on this PC**. To use it from the Claude app
on a Galaxy tab or from claude.ai, you'd expose this PC through **your own Tailscale account**
(needs a paid Claude plan):

```powershell
# 1. Install Tailscale and sign in (https://tailscale.com)
# 2. Run the server in HTTP mode (a secret URL is generated automatically)
.\.venv\Scripts\python.exe server.py --http
# 3. Turn on the tunnel
tailscale funnel --bg 8788
# 4. Add the URL in claude.ai → Settings → Connectors → Add custom connector:
#    https://<your funnel host>/<value in http_secret.txt>/mcp
```

⚠️ Anyone who has that secret URL can read your notes. Never share it. If unsure, stick with the local install.
To rotate it: delete `http_secret.txt`, restart the server, and re-add the connector.

---

## Technical notes

- Single-file MCP server (`server.py`, Python, FastMCP) over the Samsung Notes
  for Windows local database: `%LOCALAPPDATA%\Packages\SAMSUNGELECTRONICSCoLtd.SamsungNotes_*\LocalState`
  (`Storage.sqlite` for metadata/text, `wdoc\<uuid>\` for page images/PDFs;
  voice recordings are `.m4a` files in `wdoc\<uuid>\media\` with the same `N@` order prefix).
- Handwritten pages beyond the first come from the app's own per-page render cache
  (`Thumbnail\<note-uuid>\<n>\<page-uuid>.jpeg`), ordered via `PageDB`.
- The live DB is snapshot-copied to `%TEMP%` before every read — the Samsung
  Notes app never sees a lock, and nothing is ever written to its data.
- The OneNote/Microsoft Graph route does **not** work for Samsung Notes
  (Microsoft retired the OneNote feed) — that's why this reads the local DB.
