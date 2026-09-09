# ClaudMonWidget

**English** · [한국어](README.ko.md) · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · [Español](README.es.md)

A translucent, always-on-top Windows widget showing your Claude Code usage.

```
┌─────────────────────────────────┐
│ ANIN                      [Pro] │
│ ─────────────────────────────── │
│ ● 5-hour session         2h 57m │
│ 54%                             │
│ ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░  │
│ 6%                        6d 4h │
│ ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│ 807.1k tok / 399 req / live 2m  │
└─────────────────────────────────┘
```

Nothing to install: it runs on the PowerShell 5.1 and WPF that ship with
Windows, and reuses the credentials Claude Code already stored. No `npm
install`, no separate sign-in.

## Install

Windows 10/11 with Claude Code installed and signed in is the whole
prerequisite.

```powershell
git clone https://github.com/is-an/ClaudMonWidget.git
```

A ZIP unpacked anywhere works too. The widget writes `config.json` and
`usage-cache.json` into its own folder, so that folder must be writable — avoid
`C:\Program Files`. There is no installer and nothing goes in the registry; to
remove it, delete the folder.

## Run

Double-click **`start-hidden.vbs`**. No console window appears. Or:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File widget.ps1 -Skin detail
```

`-ExecutionPolicy Bypass` applies to that one launch and does not change your
system policy.

**Only one widget runs at a time.** Launching another while one is up exits
silently, so widgets never stack up with a stale one on top.

The **folder** is portable — copy it anywhere, including a USB stick, and your
settings come along. Usage numbers still come from the Claude Code account on
whichever machine runs it.

## Start automatically

**With Windows** — `Win+R` → `shell:startup`, then put a shortcut to
`start-hidden.vbs` in that folder. Point its Change Icon at `icon.ico` for a
proper icon. Delete the shortcut to undo.

**With Claude Code** — start it alongside every Claude session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1 -Uninstall
```

This adds one `hooks.SessionStart` entry to `~/.claude/settings.json`, leaving
your other hooks alone and writing a timestamped backup first. Running it twice
does not duplicate. Both autostart routes store an absolute path, so re-run this
after moving the folder.

The widget outlives Claude Code — close it with `Exit` in its own menu.

## Controls

Drag to move. Hover for a tooltip with the window start and token breakdown.
Right-click for the menu:

- **Skin** and **Opacity** — one selection each.
- **Always on top**, **Auto sync** — toggles.
- **Sync now** — ask Anthropic immediately. **Refresh now** — re-read local files.
- **Exit**.

## Skins

A trailing `1` shows the 5-hour session only; `2` adds the 7-day window.
`border2` is the default.

| Name | Width | Shows |
|---|---|---|
| `simple1` | 150 | Bare 5-hour number, no panel |
| `simple2` | 250 | Bare two columns: 5-hour and 7-day |
| `border1` | 270 | Rounded pill with the 5-hour bar |
| `border2` | 270 | Rounded pill with both bars |
| `detail` | 300 | Account name and plan badge, both bars, token and request counts, data source |

```
simple1            simple2
  ● 54%              ● 54%  │  6%
  2h 57m             2h 57m │  6d 4h

border1                     border2
┌──────────────────────┐    ┌──────────────────────┐
│ ● 54%        2h 57m  │    │ ● 54%        2h 57m  │
│ ▓▓▓▓▓▓▓░░░░░░░░░░░░  │    │ ▓▓▓▓▓▓▓░░░░░░░░░░░░  │
└──────────────────────┘    │ 6%             6d 4h │
                            │ ▓░░░░░░░░░░░░░░░░░░  │
                            └──────────────────────┘
```

`detail` is the one at the top of this page.

Every row reads the same way: percentage on the left, time remaining on the
right, in units that match the scale (`3h 04m`, `6d 5h`). Height follows the
content, so nothing clips under font scaling. Colours: green below 70%, amber at
70%, red at 90%, grey when there is no value.

Adding a skin is one `skins\<name>.xaml` file — see PLAN.md for the element
contract.

## Where the numbers come from

Three sources, freshest first.

**1. Anthropic, every 5 minutes.**
`GET https://api.anthropic.com/api/oauth/usage` with
`Authorization: Bearer <token>` and `anthropic-beta: oauth-2025-04-20` — the
same endpoint Claude Code calls to draw `/usage`, so the percentages match. The
token is the one already in `%USERPROFILE%\.claude\.credentials.json`; the
widget never asks you to sign in and never sends it anywhere else. The reply is
cached in `usage-cache.json`. **Claude Code's own files are never written to.**

**2. `%USERPROFILE%\.claude.json` → `cachedUsageUtilization`.**
The same numbers, but only refreshed when Claude Code fetches them — it was
found 44 hours stale reading 70% while a live call returned 28%. Fallback only.

**3. `%USERPROFILE%\.claude\projects\**\*.jsonl`.**
Per-request token counts, re-read every 5 seconds with no network. Our own
tally, not the server's. The `tok` figure is billed tokens; cache reads run 20×
higher and appear only in the tooltip.

The account name and plan badge come from the `oauthAccount` block of
`~/.claude.json`, read once with no network call.

The bottom line of `detail` names the source and its age — `live now`,
`claude-code 2d`, or a failure such as `token expired` or `http 429`. A
percentage whose `resets_at` has passed belongs to an expired window and is
**not shown**: never presenting a stale number as a current one is the rule this
widget is built around. The poll notices that rollover and fetches the new
window at once, so the gap lasts seconds.

Cost in dollars is not shown: the `cost-state` line recording it is written near
the end of a session, so a session in progress has none.

## Settings

`config.json` is created on first exit; the menu changes most of it.

| Key | Default | Meaning |
|---|---|---|
| `skin` | `border2` | Starting skin; an unknown name falls back to the default |
| `opacity` | `0.92` | Window opacity |
| `left` / `top` | `-1` | Position; `-1` places it bottom-right |
| `pollSeconds` | `5` | How often local files are re-read |
| `syncSeconds` | `300` | How often Anthropic is asked |
| `autoSync` | `true` | Off means `Sync now` only |
| `windowHours` | `5` | Session window length |
| `warnPct` / `dangerPct` | `70` / `90` | Amber and red thresholds |

`usage-cache.json` is the last sync response; deleting it is safe.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Nowhere on screen | `left` / `top` may name a monitor you no longer have. Delete `config.json` |
| Frozen, or a token count instead of a `%` | `Exit` and restart, or press `Sync now` and read the reason on the bottom line |
| `token expired` on that line | Run Claude Code once to refresh the token |
| Time remaining differs from the Claude app | Both read the same `resets_at`; check for a newer version. Seconds are dropped, so a minute of drift is normal |
| Script execution blocked | Everything here applies `-ExecutionPolicy Bypass` per launch; if it persists, suspect an organisation policy |

## Development

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test-usage.ps1   # aggregation, offline
powershell -NoProfile -ExecutionPolicy Bypass -File test-menu.ps1    # menu and event wiring
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1        # icon.ico + launcher exe
```

The tests build a fake `.claude` tree in TEMP with a pinned clock, so they touch
no network and give the same result whenever they run. `icon.ico` is committed;
the exe is not, since it only launches `widget.ps1` and `start-hidden.vbs`
already does that without compiling. PLAN.md holds the design notes, the skin
element contract, and the PowerShell 5.1 traps this was built around.

## Known limits

- The token tally is ours and may not match how Anthropic bills. The `%` is the
  server's number.
- `/api/oauth/usage` is not a documented API. If its shape changes, the sync
  records `unrecognized response` and keeps the last good cache.
- No click-through: it would put the right-click menu out of reach.
- Windows only, tied to WPF.
