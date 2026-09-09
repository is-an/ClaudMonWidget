# ClaudMonWidget

**English** · [한국어](README.ko.md) · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · [Español](README.es.md)

A translucent, always-on-top Windows widget showing your Claude Code usage.

```
┌──────────────────────────────────┐
│  ● 54%                   2h 57m  │
│  ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░  │
│  6%                       6d 4h  │
│  ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
└──────────────────────────────────┘
```

Nothing to install. It runs on the PowerShell 5.1 and WPF that ship with
Windows. No `npm install`, no separate sign-in — it reuses the credentials
Claude Code already stored.

---

## Contents

- [Install](#install)
- [Run](#run)
- [Start automatically](#start-automatically)
  - [With Windows](#with-windows)
  - [With Claude Code](#with-claude-code)
- [Controls](#controls)
- [Skins](#skins)
- [How it gets the numbers](#how-it-gets-the-numbers)
- [Settings](#settings)
- [Troubleshooting](#troubleshooting)
- [Tests](#tests)
- [Building](#building)
- [Writing your own skin](#writing-your-own-skin)
- [Known limits](#known-limits)

---

## Install

Windows 10/11 with Claude Code installed and signed in is the whole
prerequisite.

```powershell
git clone https://github.com/is-an/ClaudMonWidget.git
cd ClaudMonWidget
```

A ZIP unpacked anywhere works too. The location does not matter, but the widget
writes `config.json` and `usage-cache.json` into its own folder, so it needs to
be writable. Avoid `C:\Program Files`.

There is no installer and nothing goes in the registry. To remove it, delete the
folder (undo [autostart](#start-automatically) first if you set it up).

## Run

Double-click **`start-hidden.vbs`**. No console window appears.

Or from a console:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File widget.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File widget.ps1 -Skin detail
```

`-ExecutionPolicy Bypass` applies to that one launch. It does not change your
system policy.

No `.exe` ships with this repository. [`build.ps1`](#building) can compile a
46KB launcher if you prefer one, but it is only a launcher — it needs
`widget.ps1` beside it and does nothing on its own, so there is no standalone
binary to hand around, and a committed one would only trip SmartScreen.

The **folder** is portable, though: no installer, nothing in the registry, and
`config.json` and `usage-cache.json` are written next to the scripts, so
settings travel with it. Copy the folder anywhere, including a USB stick. The
usage numbers still come from the Claude Code account on whatever machine it
runs on, and the [autostart](#start-automatically) entries store an absolute
path, so re-run `install-hook.ps1` after moving the folder.

**Only one widget runs at a time.** Launching it again while one is up exits
immediately and silently. That keeps widgets from stacking on screen with a
stale one on top.

## Start automatically

### With Windows

1. `Win+R` → `shell:startup` opens the Startup folder.
2. Put a **shortcut** to `start-hidden.vbs` in it.

Delete the shortcut to undo. To give the shortcut a proper icon instead of the
default script one, point its Change Icon at `icon.ico` in this folder.

### With Claude Code

Start the widget when a Claude Code session starts. Better if you only want it
around while you are working with Claude.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1
```

This adds one entry to `hooks.SessionStart` in `~/.claude/settings.json`. Your
other hooks and settings are left alone, and a timestamped backup is written
next to the file first. Running it twice does not create a duplicate.

To undo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1 -Uninstall
```

By hand, the entry looks like this:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "wscript.exe \"C:\\path\\ClaudMonWidget\\start-hidden.vbs\""
          }
        ]
      }
    ]
  }
}
```

The hook fires on every session, but the widget is single-instance, so every
launch after the first exits at once.

**The widget outlives Claude Code.** Close it from its own right-click `Exit`.
Closing it on session end would need a stop hook that kills the process, and
that fires even when other Claude sessions are still open, so it is not
included.

## Controls

| Action | Result |
|---|---|
| Drag | Move it. The position is saved to `config.json` on exit |
| Hover | Tooltip: window start, billed tokens, cache-read tokens, data source |
| Right-click | Menu |

Menu:

- **Skin** — `simple1` / `simple2` / `border1` / `border2` / `detail`. One at a time.
- **Opacity** — 55 / 75 / 92 / 100%. One at a time.
- **Always on top** — toggle.
- **Auto sync** — toggle asking Anthropic every 5 minutes.
- **Sync now** — ask Anthropic right now.
- **Refresh now** — re-read local files only.
- **Exit** — quit.

## Skins

Five. A trailing `1` means the 5-hour session only; `2` adds the 7-day window.

| Name | Width | Shows |
|---|---|---|
| `simple1` | 150 | Bare 5-hour number, no panel |
| `simple2` | 250 | Bare two columns: 5-hour and 7-day |
| `border1` | 270 | Rounded pill with the 5-hour bar |
| `border2` | 270 | Rounded pill with 5-hour and 7-day bars |
| `detail` | 300 | Account name and plan badge, both bars, token and request counts, data source |

`border2` is the default. Height follows the content, so nothing clips on a
machine with larger font scaling.

Both windows show **time remaining** until the next reset. The unit follows the
scale: `3h 04m` for the 5-hour window, `6d 5h` for the 7-day one. `149h 05m` is
not a number you can hold in your head.

```
simple1              simple2
  ● 54%              ● 54%  │  6%
   2h 57m              2h 57m │  6d 4h

border1                          border2
┌──────────────────────┐  ┌──────────────────────┐
│ ● 54%        2h 57m  │  │ ● 54%        2h 57m  │
│ ▓▓▓▓▓▓▓░░░░░░░░░░░░  │  │ ▓▓▓▓▓▓▓░░░░░░░░░░░░  │
└──────────────────────┘  │ 6%              6d 4h│
                          │ ▓░░░░░░░░░░░░░░░░░░  │
                          └──────────────────────┘
```

`detail`:

```
ANIN                        [Pro]
─────────────────────────────────
● 5-hour session          2h 57m
54%
▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░
6%                         6d 4h
▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
807.1k tok / 399 req / live 2m
```

Both rows follow one rule: percentage on the left, time remaining on the right.

Colour steps: green below 70%, amber at 70%, red at 90%, grey when there is no
value.

---

## How it gets the numbers

Three sources, freshest first.

### 1. Ask Anthropic directly (every 5 minutes by default)

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <access token>
anthropic-beta: oauth-2025-04-20
```

The same endpoint Claude Code calls to draw `/usage`, so the widget's percentage
is the percentage `/usage` shows.

The token is the one Claude Code already stored:

```
%USERPROFILE%\.claude\.credentials.json  →  claudeAiOauth.accessToken
```

The widget never asks you to sign in and never sends the token anywhere except
the request header above. If the token has expired it skips the call — refreshing
is Claude Code's OAuth flow to run, and the widget does not imitate it.

The response:

```json
{
  "five_hour": { "utilization": 36.0, "resets_at": "2026-09-09T09:04:59+00:00" },
  "seven_day": { "utilization": 4.0,  "resets_at": "2026-09-15T09:59:59+00:00" },
  "limits": [ ... ],
  "spend": { ... }
}
```

It is saved verbatim to `usage-cache.json` in the widget's folder.

**Claude Code's own files are never written to.** `~/.claude.json` is rewritten
wholesale by Claude Code, and writing to it from outside could corrupt that
state. If the widget fails or dies, nothing on Claude Code's side is affected.

### 2. `%USERPROFILE%\.claude.json` → `cachedUsageUtilization`

The same numbers, but only refreshed when Claude Code itself fetches them. It
can be days old. Used only when source 1 is unavailable.

In practice this cache sat 44 hours stale reading 70% / 60% while a live call at
that same moment returned 28% / 3%. That is why source 1 exists.

### 3. `%USERPROFILE%\.claude\projects\**\*.jsonl` → assistant lines

```json
"usage": { "input_tokens": 2, "cache_creation_input_tokens": 25110,
           "cache_read_input_tokens": 29894, "output_tokens": 599 }
```

Per-request token counts with timestamps, re-read every 5 seconds with no
network involved. Always current, but it is our own tally, not the server's.

Only lines inside the session window are summed. Window start =
`five_hour.resets_at` − 5 hours.

Cache-read tokens run more than 20× the billed ones, so they are counted
separately. The `tok` figure on screen is billed tokens (input + output + cache
writes); cache reads appear only in the tooltip.

### Account name and plan

Read from the `oauthAccount` block of `~/.claude.json` — no network call.

| Field | Used for |
|---|---|
| `displayName` | Account name |
| `emailAddress` | Tooltip on the name |
| `organizationType` | Plan badge |

`organizationType` maps: `claude_pro`→`Pro`, `claude_max`→`Max`,
`claude_max_5x`→`Max 5x`, `claude_max_20x`→`Max 20x`, `claude_team`→`Team`,
`claude_enterprise`→`Enterprise`.

It cannot change while the widget runs, so it is read once at window creation.

### Knowing what you are looking at

The bottom line of the `detail` skin names the source and its age.

| Shown | Meaning |
|---|---|
| `live now` | Just fetched from Anthropic |
| `live 12m` | Fetched 12 minutes ago |
| `claude-code 2d` | Live call failed; using Claude Code's cache, two days old |
| `token expired` | Token expired. Run Claude Code once to refresh it |
| `http 429` | Called too often. Clears itself on the next cycle |
| `http 401` | Auth rejected. Sign in to Claude Code again |
| `sync failed` | Network error and the like |

Restarting the widget does not re-fetch if the cache is younger than
`syncSeconds` (300 by default). That keeps frequent restarts — which the Claude
Code hook makes easy — from hammering the endpoint into an `http 429`. `Sync
now` ignores the limit.

If `resets_at` has already passed, that percentage belongs to an expired window
and is **not shown.** The widget falls back to its own token tally instead.
Never presenting a stale number as a current one is the rule this widget is
built around.

That state is meant to be brief. When the poll notices the window has rolled
over, it asks Anthropic for the new one on the spot rather than waiting for the
next scheduled sync, so the gap is seconds rather than up to `syncSeconds`.

Cost in dollars is not shown. The `cost-state` line that records it is written
near the end of a session, so an in-progress session file does not have one.

---

## Settings

`config.json` is created when the widget first exits. The right-click menu
changes most of it, so you rarely need to open the file.

| Key | Default | Meaning |
|---|---|---|
| `skin` | `border2` | Starting skin. An unknown name falls back to the default |
| `opacity` | `0.92` | Window opacity |
| `left` / `top` | `-1` | Position. `-1` places it bottom-right |
| `pollSeconds` | `5` | How often local files are re-read |
| `syncSeconds` | `300` | How often Anthropic is asked |
| `autoSync` | `true` | Automatic sync. Off means `Sync now` only |
| `windowHours` | `5` | Session window length |
| `warnPct` / `dangerPct` | `70` / `90` | Amber and red thresholds |

`usage-cache.json` is the last sync response. Deleting it is safe — the next
sync recreates it.

## Troubleshooting

**The widget is nowhere on screen**
`left` / `top` in `config.json` may point at a monitor you no longer have.
Delete that file and start again; it goes back to the bottom-right corner.

**Time remaining differs from the Claude app or web**
Both read the same `resets_at`, so they should not disagree. If they do, the
widget is probably out of date — check for a newer version. Seconds are dropped,
so a difference of up to a minute is expected; more than that is a bug.

**The numbers are frozen**
Probably a long-running instance. `Exit` and start it again. Time remaining is
recomputed every 5 seconds, so it should lose a minute every minute.

**The bottom line stays on `claude-code`**
The live call keeps failing. Press `Sync now` to see the reason. If it says
`token expired`, run Claude Code once to refresh the token.

**A token count shows instead of a `%`**
Everything available is from an expired session window. Press `Sync now`, or run
`/usage` once in Claude Code.

**Script execution is blocked**
`start-hidden.vbs` and the commands above apply `-ExecutionPolicy Bypass` to
that launch only. If it is still blocked, it is likely an organisation policy.

## Tests

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test-usage.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File test-menu.ps1
```

`test-usage.ps1` builds a fake `.claude` tree in TEMP and pins the reference
clock, then checks aggregation, account parsing, source priority and fallback.
It touches no network and does not depend on what the real logs contain, so it
gives the same result whenever it runs.

`test-menu.ps1` checks that the right-click menu really behaves like radio
buttons. WPF `MenuItem` has no radio mode, so left alone the opacity entries all
select at once.

## Building

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1
```

It draws `icon.ico` with `System.Drawing`, packs the `.ico` by hand, and
compiles `ClaudMonWidget.exe` with the C# compiler that ships with the .NET
Framework on every Windows install. Nothing is downloaded.

`icon.ico` is committed. The exe is not, and is git-ignored: it only launches
`widget.ps1` from its own folder, so it is not something to hand around on its
own, and `start-hidden.vbs` already does that job without compiling anything.
Build it if you want a double-clickable file with the icon on it.

## Writing your own skin

Add one file, `skins\<name>.xaml`. `widget.ps1` needs no changes.

The host looks these names up with `FindName` and fills in **only the ones that
exist**, so include just what you want.

| `x:Name` | Type | Filled with |
|---|---|---|
| `Dot` | Shape | Status colour |
| `TxtMain` | TextBlock | 5-hour percentage, or the token tally when there is none |
| `TxtReset` | TextBlock | Time to the 5-hour reset (`3h 04m`), else `--` |
| `TxtWeek` | TextBlock | 7-day percentage |
| `TxtWeekReset` | TextBlock | Time to the 7-day reset (`6d 5h`), else `--` |
| `TxtSub` | TextBlock | `563.0k tok / 249 req / live now` |
| `TxtUser` | TextBlock | Account name, e-mail in the tooltip |
| `TxtPlan` | TextBlock | Plan badge |
| `BarTrack` / `BarFill` | Border | 5-hour progress bar |
| `WeekTrack` / `WeekFill` | Border | 7-day progress bar |
| `Root` | any container | Where the right-click menu attaches |

The `Window` needs `WindowStyle="None"`, `AllowsTransparency="True"` and
`Background="Transparent"`. Use `SizeToContent="Height"` so nothing clips when
font sizes differ.

To list a new skin in the menu, add the name to the `$Skins` array near the top
of `widget.ps1` and to the `ValidateSet` on the `-Skin` parameter.

```powershell
$Skins = @('simple1','simple2','border1','border2','detail')
```

If `config.json` names a skin that no longer exists, the widget falls back to
the default rather than refusing to start.

## Known limits

- The token tally is ours, and is not guaranteed to match how Anthropic bills or
  meters. The `%` on screen is the server's number; `tok` is ours.
- `/api/oauth/usage` is not a publicly documented API. The widget uses what
  Claude Code uses. If the response shape changes, the sync records
  `unrecognized response` and **leaves the last good cache in place** — the
  display does not go blank.
- No click-through. Turning it on would put the right-click menu out of reach
  and drag a global hotkey along with it.
- If a Claude Code update renames JSONL fields the tally can go to zero. The
  widget shows `--` rather than dying.
- Windows only. It is tied to WPF.

## Mines stepped on in PowerShell 5.1

Written down so the next change does not step on them again. Every one of these
fails quietly with a wrong value rather than an error.

- **Do not parse `~/.claude.json` with `ConvertFrom-Json`.** It holds a project
  map keyed by absolute path, and the parser treats keys case-insensitively, so
  `c:\...` and `C:\...` collide as duplicates and the whole parse throws. Pull
  out the few values you need with a regex instead.
- **Keep non-ASCII out of `.ps1` files.** A script without a BOM is read as ANSI
  and the characters are mangled. Localised labels live in the XAML, which is
  read as UTF-8 explicitly. For the same reason, never round-trip these files
  through `Get-Content | Set-Content`.
- **A scriptblock with `GetNewClosure()` runs against a cloned scope.** It sees
  neither `$script:` variables its creator assigned afterwards nor functions
  defined inside the enclosing function. Put shared state in one hashtable and
  pass it by reference, and put the helpers a handler calls at script level.
  Missing this made a `SourceInitialized` handler throw partway through, so the
  polling timer after it never started. The widget sat there looking fine,
  frozen on its first frame — a dead widget is obvious, a stopped one is not.
  The polling timer now starts **first, unconditionally**.
- **An `[int]` cast rounds, it does not truncate.** `[int]3.58` is `4`.
  Computing time left as `[int]$span.TotalHours` turned 3h34m into `4h 34m`. The
  minutes stayed correct, so it looked entirely plausible, and it read as an
  hour of budget that did not exist. Use `[math]::Floor` when cutting hours.
  A number that represents a budget must not err upward.
- **`return $array` unrolls into the pipeline.** The caller gets an `object[]`
  of boxed elements instead of the `byte[]` it asked for. `.Length` still reads
  right, so the icon directory looked correct while `BinaryWriter.Write` picked
  a different overload and emitted one byte per entry: a 108-byte `.ico` with a
  perfect header and no images. Return `, $array`.
- **A scriptblock wired to an event is handed `(sender, args)` positionally.**
  Give it a typed parameter and the cast runs against the sender — a
  `DispatcherTimer`, say — and throws inside the handler, where nothing surfaces
  it. Auto-sync and `Sync now` both died this way while the widget went on
  looking healthy: the cache stopped refreshing, the session window rolled over,
  and the percentage went grey until a restart, which took the direct-call path.
  Handlers take no parameters; a wrapper passes the real argument on.
  `test-menu.ps1` pins both halves.
- **Do not use `.Count` on a pipeline result under `StrictMode 2.0`.** A single
  result comes back as a scalar and `.Count` throws. When that happens while
  evaluating an argument, the whole check is skipped — so the test suite
  silently pretends to pass. Wrap it in `@(...)`.
