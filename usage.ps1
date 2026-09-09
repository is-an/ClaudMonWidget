# Reads Claude Code's local files, and optionally asks Anthropic directly, to
# return current usage.
#
# Three sources, in order of freshness:
#   1. usage-cache.json (ours)  - written by Sync-ClaudeUsage from a live
#      GET https://api.anthropic.com/api/oauth/usage, using the OAuth token
#      Claude Code already stored. Exactly what /usage shows, as of the sync.
#   2. ~/.claude.json -> cachedUsageUtilization
#      The same numbers, but only refreshed when Claude Code itself fetches
#      them. Can be days old. Used when we have no live cache.
#   3. ~/.claude/projects/**/*.jsonl -> assistant lines
#      Token counts per request with a timestamp. Always current, but it is our
#      own tally, not the server's.
#
# Sources 2 and 3 need no network. Only Sync-ClaudeUsage goes out.

Set-StrictMode -Version 2.0

$script:ClaudeUsageUrl = 'https://api.anthropic.com/api/oauth/usage'

# Both ~/.claude.json and the live response carry the same window objects, so
# one regex reader serves both. Regex rather than ConvertFrom-Json because
# ~/.claude.json also holds a project map keyed by absolute path, and
# PowerShell 5.1's JSON parser is case-insensitive about keys: "c:\..." and
# "C:\..." collide as duplicates and the whole parse throws.
function Read-Windows {
    param([string]$Text)
    $out = @{}
    foreach ($name in @('five_hour','seven_day')) {
        # These window objects have no nested braces, so [^}]* is enough.
        $pat = '"' + $name + '":\s*\{[^}]*?"utilization":\s*([\d.]+)[^}]*?"resets_at":\s*"([^"]+)"'
        if ($Text -match $pat) {
            $out[$name] = @{
                Pct    = [double]$Matches[1]
                Resets = ([datetime]$Matches[2]).ToLocalTime()
            }
        }
    }
    return $out
}

function Get-ClaudeAccount {
    param([string]$ConfigPath = (Join-Path $env:USERPROFILE '.claude.json'))

    $a = [pscustomobject]@{ Name = $null; Email = $null; Plan = $null }
    try {
        if (-not (Test-Path -LiteralPath $ConfigPath)) { return $a }
        $raw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8

        # Scope to the oauthAccount object; displayName and the like also occur
        # elsewhere in this file.
        # (?s) so . spans lines; non-greedy stops at the block's own closing brace.
        if ($raw -match '(?s)"oauthAccount":\s*\{(.*?)\n\s*\}') { $raw = $Matches[1] }

        if ($raw -match '"displayName":\s*"([^"]*)"')      { $a.Name  = $Matches[1] }
        if ($raw -match '"emailAddress":\s*"([^"]*)"')     { $a.Email = $Matches[1] }
        if ($raw -match '"organizationType":\s*"([^"]*)"') {
            $a.Plan = switch ($Matches[1]) {
                'claude_pro'        { 'Pro' }
                'claude_max'        { 'Max' }
                'claude_max_5x'     { 'Max 5x' }
                'claude_max_20x'    { 'Max 20x' }
                'claude_team'       { 'Team' }
                'claude_enterprise' { 'Enterprise' }
                default             { $Matches[1] -replace '^claude_', '' }
            }
        }
    } catch { }
    return $a
}

# Asks Anthropic for the current utilization and caches the reply next to this
# script. Uses the OAuth token Claude Code already stored; it never writes to
# Claude Code's own files, so a failure here cannot corrupt anything of theirs.
# Returns a status string, never throws.
function Sync-ClaudeUsage {
    param(
        [string]$CachePath       = (Join-Path $PSScriptRoot 'usage-cache.json'),
        [string]$OAuthFilePath = (Join-Path $env:USERPROFILE '.claude\.credentials.json'),
        [int]$TimeoutSec = 15,
        # Skip the call when the cache is younger than this. Startup passes the
        # sync interval so that restarting the widget repeatedly - which the
        # Claude Code hook makes easy - does not hammer the endpoint into a 429.
        [int]$MinAgeSeconds = 0
    )

    try {
        if ($MinAgeSeconds -gt 0 -and (Test-Path -LiteralPath $CachePath)) {
            $age = (Get-Date) - (Get-Item -LiteralPath $CachePath).LastWriteTime
            if ($age.TotalSeconds -lt $MinAgeSeconds) { return 'ok' }
        }

        if (-not (Test-Path -LiteralPath $OAuthFilePath)) { return 'no credentials' }

        $cred = Get-Content -LiteralPath $OAuthFilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $oauth = $cred.PSObject.Properties['claudeAiOauth']
        if (-not $oauth) { return 'no oauth' }
        $token = $oauth.Value.accessToken
        if (-not $token) { return 'no token' }

        # Refreshing an expired token means running the OAuth dance, which is
        # Claude Code's job. Skip the call and let it refresh on its next run.
        $exp = $oauth.Value.PSObject.Properties['expiresAt']
        if ($exp -and [double]$exp.Value -lt ([datetime]::UtcNow - [datetime]'1970-01-01').TotalMilliseconds) {
            return 'token expired'
        }

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $body = Invoke-WebRequest -Uri $script:ClaudeUsageUrl -Method Get -TimeoutSec $TimeoutSec `
                    -UseBasicParsing -Headers @{
                        Authorization    = "Bearer $token"
                        'anthropic-beta' = 'oauth-2025-04-20'
                        'Content-Type'   = 'application/json'
                    } | Select-Object -ExpandProperty Content

        # Only overwrite the cache with something we can actually read, so a
        # changed response shape leaves the last good copy in place.
        if ((Read-Windows $body).Count -eq 0) { return 'unrecognized response' }

        [System.IO.File]::WriteAllText($CachePath, $body, (New-Object System.Text.UTF8Encoding $false))
        return 'ok'
    } catch {
        # The framework's message is a localized sentence that overruns the
        # widget's one line. The status code is the part worth showing.
        $resp = $_.Exception.PSObject.Properties['Response']
        if ($resp -and $resp.Value) {
            return ('http {0}' -f [int]$resp.Value.StatusCode)
        }
        return 'sync failed'
    }
}

function Get-ClaudeUsage {
    param(
        [string]$ClaudeDir = (Join-Path $env:USERPROFILE '.claude'),
        [string]$ConfigPath = (Join-Path $env:USERPROFILE '.claude.json'),
        [string]$CachePath = (Join-Path $PSScriptRoot 'usage-cache.json'),
        [double]$WindowHours = 5,
        [datetime]$Now = (Get-Date)
    )

    $nowUtc = $Now.ToUniversalTime()

    $result = [pscustomobject]@{
        FiveHourPct     = $null   # 0-100; $null when we have nothing current
        FiveHourResets  = $null   # [datetime] local
        SevenDayPct     = $null
        SevenDayResets  = $null
        Source          = 'none'  # live | claude-code | none
        FetchedAgeMin   = $null   # how old the numbers above are
        WindowStart     = $null   # [datetime] local
        WindowTokens    = 0       # our own tally, always current: all four kinds
        WindowBilled    = 0       # input + output + cache writes
        WindowCacheRead = 0       # dwarfs the rest, so it is kept separate
        WindowRequests  = 0
        Error           = $null
    }

    # --- utilization: our live cache first, Claude Code's second -------------
    $resetsAtUtc = $null
    try {
        $win = @{}

        if (Test-Path -LiteralPath $CachePath) {
            $win = Read-Windows (Get-Content -LiteralPath $CachePath -Raw -Encoding UTF8)
            if ($win.Count) {
                $result.Source = 'live'
                $age = $nowUtc - (Get-Item -LiteralPath $CachePath).LastWriteTimeUtc
                $result.FetchedAgeMin = [math]::Round($age.TotalMinutes, 1)
            }
        }

        if ($win.Count -eq 0 -and (Test-Path -LiteralPath $ConfigPath)) {
            $raw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
            $win = Read-Windows $raw
            if ($win.Count) {
                $result.Source = 'claude-code'
                if ($raw -match '"fetchedAtMs":\s*(\d+)') {
                    $fetchedUtc = [datetime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc).AddMilliseconds([double]$Matches[1])
                    $result.FetchedAgeMin = [math]::Round(($nowUtc - $fetchedUtc).TotalMinutes, 1)
                }
            }
        }

        if ($win.ContainsKey('five_hour')) {
            $result.FiveHourPct    = $win['five_hour'].Pct
            $result.FiveHourResets = $win['five_hour'].Resets
            $resetsAtUtc = $result.FiveHourResets.ToUniversalTime()
        }
        if ($win.ContainsKey('seven_day')) {
            $result.SevenDayPct    = $win['seven_day'].Pct
            $result.SevenDayResets = $win['seven_day'].Resets
        }
    } catch {
        $result.Error = "utilization: $($_.Exception.Message)"
    }

    # Window start: trust the reset time while it is still in the future. Once
    # it has passed, the numbers are from an old window, so fall back to a
    # rolling window ending now and withhold the percentage.
    if ($resetsAtUtc -and $resetsAtUtc -gt $nowUtc) {
        $startUtc = $resetsAtUtc.AddHours(-$WindowHours)
    } else {
        $startUtc = $nowUtc.AddHours(-$WindowHours)
        $result.FiveHourPct = $null
    }
    $result.WindowStart = $startUtc.ToLocalTime()

    # --- our own tally from the session logs --------------------------------
    # Regex instead of ConvertFrom-Json per line: these files run to hundreds of
    # KB and we re-read them every few seconds.
    $projects = Join-Path $ClaudeDir 'projects'
    if (Test-Path -LiteralPath $projects) {
        $startLocal = $startUtc.ToLocalTime()
        $files = Get-ChildItem -LiteralPath $projects -Recurse -Filter *.jsonl -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.LastWriteTime -ge $startLocal }

        foreach ($f in $files) {
            try {
                # ReadAllLines keeps the handle shared; Claude Code is writing to these.
                $lines = [System.IO.File]::ReadAllLines($f.FullName)
            } catch {
                continue   # locked or mid-write; the next poll picks it up
            }

            foreach ($line in $lines) {
                if ($line -notmatch '"type":"assistant"') { continue }
                if ($line -notmatch '"usage":') { continue }
                if ($line -notmatch '"timestamp":"([^"]+)"') { continue }

                $ts = ([datetime]$Matches[1]).ToUniversalTime()
                if ($ts -lt $startUtc) { continue }

                # The [,{] guard keeps "input_tokens" from also matching
                # "cache_creation_input_tokens" and "ephemeral_1h_input_tokens".
                $billed = 0
                foreach ($pat in @('[,{]"input_tokens":(\d+)',
                                   '[,{]"output_tokens":(\d+)',
                                   '"cache_creation_input_tokens":(\d+)')) {
                    if ($line -match $pat) { $billed += [int]$Matches[1] }
                }
                $cacheRead = 0
                if ($line -match '"cache_read_input_tokens":(\d+)') { $cacheRead = [int]$Matches[1] }

                $result.WindowBilled += $billed
                $result.WindowCacheRead += $cacheRead
                $result.WindowTokens += ($billed + $cacheRead)
                $result.WindowRequests++
            }
        }
    }

    return $result
}

function Format-Tokens {
    param([double]$N)
    if ($N -ge 1000000) { return ('{0:0.0}M' -f ($N / 1000000)) }
    if ($N -ge 1000)    { return ('{0:0.0}k' -f ($N / 1000)) }
    return [string][int]$N
}

# Time left until a reset, at whatever scale reads best. The 5-hour window
# lands in the hour branch, the 7-day window in the day branch: "6d 5h" is
# something you can hold in your head, "149h 05m" is not.
function Format-Remaining {
    param($ResetsAt, [datetime]$Now = (Get-Date))
    if (-not $ResetsAt) { return '--' }
    $span = ([datetime]$ResetsAt) - $Now
    if ($span.TotalSeconds -le 0) { return '--' }
    # Floor, not [int]. PowerShell's [int] cast rounds, so 3h34m (TotalHours
    # 3.58) came out as "4h 34m" - a whole hour more budget than you have,
    # while the minutes stayed right, which is what made it look plausible.
    if ($span.TotalDays -ge 1) {
        return ('{0}d {1}h' -f [int][math]::Floor($span.TotalDays), $span.Hours)
    }
    if ($span.TotalHours -ge 1) {
        return ('{0}h {1:00}m' -f [int][math]::Floor($span.TotalHours), $span.Minutes)
    }
    return ('{0}m' -f [int][math]::Floor($span.TotalMinutes))
}

function Format-Age {
    param($Minutes)
    if ($null -eq $Minutes)  { return 'n/a' }
    if ($Minutes -lt 1)      { return 'now' }
    if ($Minutes -ge 1440)   { return ('{0:0}d' -f ($Minutes / 1440)) }
    if ($Minutes -ge 60)     { return ('{0:0}h' -f ($Minutes / 60)) }
    return ('{0:0}m' -f $Minutes)
}

if ($MyInvocation.InvocationName -ne '.') {
    Get-ClaudeAccount | Format-List
    Get-ClaudeUsage | Format-List
}
