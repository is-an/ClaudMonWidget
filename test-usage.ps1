# Self-check for Get-ClaudeUsage. Builds a fake .claude tree in TEMP so the
# assertions do not depend on whatever the real logs happen to contain.
# Run:  powershell -File test-usage.ps1

# Without this an error while evaluating a Check argument - a renamed function,
# a .Count on a scalar - kills that one line and lets the run finish with
# "all checks passed" having silently skipped it.
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'usage.ps1')

$root = Join-Path $env:TEMP ("claudmon-test-" + [guid]::NewGuid().ToString('N').Substring(0,8))
$proj = Join-Path $root '.claude\projects\demo'
New-Item -ItemType Directory -Path $proj -Force | Out-Null

$now      = Get-Date '2026-09-09T12:00:00Z'
$resetsAt = $now.AddHours(2)          # 2h left, so window started 3h ago
$inside   = $now.AddHours(-1)         # counts
$outside  = $now.AddHours(-4)         # older than the window, ignored

$cfg = @"
{
  "someProject": { "a": 1, "displayName": "wrong project field" },
  "oauthAccount": {
    "emailAddress": "tester@example.com",
    "displayName": "TESTER",
    "organizationType": "claude_max_20x"
  },
  "cachedUsageUtilization": {
    "fetchedAtMs": $([int64](($now.AddMinutes(-30)).ToUniversalTime() - [datetime]'1970-01-01').TotalMilliseconds),
    "utilization": {
      "five_hour": { "utilization": 42, "resets_at": "$($resetsAt.ToUniversalTime().ToString('o'))", "limit_dollars": null },
      "seven_day": { "utilization": 61, "resets_at": "$($now.AddDays(2).ToUniversalTime().ToString('o'))", "limit_dollars": null }
    }
  }
}
"@
$cfgPath = Join-Path $root 'claude.json'
Set-Content -LiteralPath $cfgPath -Value $cfg -Encoding UTF8

function New-AssistantLine {
    param($Timestamp, $In, $Out, $CacheWrite, $CacheRead)
    $ts = $Timestamp.ToUniversalTime().ToString('o')
    # ephemeral_1h_input_tokens is present in real logs and must not be counted.
    return '{"type":"assistant","message":{"usage":{"input_tokens":' + $In +
           ',"cache_creation_input_tokens":' + $CacheWrite +
           ',"cache_read_input_tokens":' + $CacheRead +
           ',"output_tokens":' + $Out +
           ',"cache_creation":{"ephemeral_1h_input_tokens":999}}},"timestamp":"' + $ts + '"}'
}

$lines = @(
    '{"type":"mode","mode":"normal"}'
    New-AssistantLine $inside  10 20 30 1000
    New-AssistantLine $inside   1  2  3  500
    New-AssistantLine $outside 99 99 99 9999   # before the window
    '{"type":"user","message":{"content":"no usage here"}}'
)
$logPath = Join-Path $proj 'a.jsonl'
Set-Content -LiteralPath $logPath -Value $lines -Encoding UTF8
# Get-ClaudeUsage skips files last written before the window, so the fixture
# needs a matching timestamp, not the real clock's.
(Get-Item -LiteralPath $logPath).LastWriteTime = $inside

$noCache = Join-Path $root 'no-such-cache.json'
$u = Get-ClaudeUsage -ClaudeDir (Join-Path $root '.claude') -ConfigPath $cfgPath -CachePath $noCache -Now $now

$fail = @()
function Check($name, $actual, $expected) {
    if ($actual -ne $expected) { $script:fail += "$name : expected $expected, got $actual" }
    else { Write-Host "ok   $name = $actual" }
}

Check 'FiveHourPct'     $u.FiveHourPct     42
Check 'SevenDayPct'     $u.SevenDayPct     61
Check 'Source'          $u.Source          'claude-code'
Check 'WindowRequests'  $u.WindowRequests  2
Check 'WindowBilled'    $u.WindowBilled    66      # (10+20+30) + (1+2+3)
Check 'WindowCacheRead' $u.WindowCacheRead 1500
Check 'WindowTokens'    $u.WindowTokens    1566
Check 'FetchedAgeMin'   $u.FetchedAgeMin   30
Check 'WindowStart'     $u.WindowStart.ToUniversalTime() $now.AddHours(-3).ToUniversalTime()
Check 'Error'           $u.Error           $null

Check 'Format-Tokens k'  (Format-Tokens 1566)    '1.6k'
Check 'Format-Tokens M'  (Format-Tokens 2500000) '2.5M'
Check 'Format-Remaining' (Format-Remaining $resetsAt $now) '2h 00m'
Check 'Format-Remaining past' (Format-Remaining $now.AddMinutes(-1) $now) '--'

# The hours field must be floored. [int] rounds, which turned 3h34m into
# "4h 34m" - an hour of budget that does not exist, with correct-looking
# minutes. Every case below has a fractional hour at or above .5.
Check 'remaining floors hours'  (Format-Remaining $now.AddMinutes(214).AddSeconds(36) $now) '3h 34m'
Check 'remaining floors at .5'  (Format-Remaining $now.AddMinutes(90) $now)  '1h 30m'
Check 'remaining floors 59m'    (Format-Remaining $now.AddSeconds(3590) $now) '59m'
Check 'remaining just over 1h'  (Format-Remaining $now.AddMinutes(60) $now)  '1h 00m'

# Past a day the units switch: "6d 5h" is holdable, "149h 05m" is not.
Check 'remaining days'          (Format-Remaining $now.AddDays(6).AddHours(5) $now)  '6d 5h'
Check 'remaining exactly 1 day' (Format-Remaining $now.AddHours(24) $now)            '1d 0h'
Check 'remaining just under'    (Format-Remaining $now.AddHours(23).AddMinutes(59) $now) '23h 59m'
Check 'remaining null'          (Format-Remaining $null $now) '--'

# A reset time already in the past means the cached percentage belongs to an
# old window, so it must be withheld rather than shown as current.
$stale = Get-ClaudeUsage -ClaudeDir (Join-Path $root '.claude') -ConfigPath $cfgPath -CachePath $noCache -Now $now.AddHours(5)
Check 'stale FiveHourPct withheld' $stale.FiveHourPct $null

# Account details come out of the oauthAccount block only. "someProject" above
# also has a displayName, and picking that one up would show the wrong name.
$a = Get-ClaudeAccount -ConfigPath $cfgPath
Check 'account name'  $a.Name  'TESTER'
Check 'account email' $a.Email 'tester@example.com'
Check 'account plan'  $a.Plan  'Max 20x'

# A live cache written by Sync-ClaudeUsage must win over Claude Code's older
# copy, which is the whole point of syncing.
$live = @"
{"five_hour":{"utilization":8,"resets_at":"$($resetsAt.ToUniversalTime().ToString('o'))"},
 "seven_day":{"utilization":9,"resets_at":"$($now.AddDays(2).ToUniversalTime().ToString('o'))"}}
"@
$livePath = Join-Path $root 'usage-cache.json'
Set-Content -LiteralPath $livePath -Value $live -Encoding UTF8
$lu = Get-ClaudeUsage -ClaudeDir (Join-Path $root '.claude') -ConfigPath $cfgPath -CachePath $livePath -Now $now
Check 'live wins Source'      $lu.Source      'live'
Check 'live wins FiveHourPct' $lu.FiveHourPct 8
Check 'live wins SevenDayPct' $lu.SevenDayPct 9

# An unreadable cache must fall back rather than blank the widget.
Set-Content -LiteralPath $livePath -Value 'garbage, not json' -Encoding UTF8
$fb = Get-ClaudeUsage -ClaudeDir (Join-Path $root '.claude') -ConfigPath $cfgPath -CachePath $livePath -Now $now
Check 'bad cache falls back'  $fb.Source      'claude-code'
Check 'bad cache keeps pct'   $fb.FiveHourPct 42

# A fresh cache must short-circuit before any network call. If this ever tries
# to reach the endpoint the test suite stops being offline.
Set-Content -LiteralPath $livePath -Value $live -Encoding UTF8
Check 'sync skips fresh cache' (Sync-ClaudeUsage -CachePath $livePath -MinAgeSeconds 3600) 'ok'
(Get-Item -LiteralPath $livePath).LastWriteTime = (Get-Date).AddHours(-2)
Check 'sync no credentials'    (Sync-ClaudeUsage -CachePath $livePath -MinAgeSeconds 3600 -OAuthFilePath (Join-Path $root 'nope.json')) 'no credentials'

Check 'Format-Age minutes' (Format-Age 30)   '30m'
Check 'Format-Age hours'   (Format-Age 150)  '3h'
Check 'Format-Age days'    (Format-Age 2649) '2d'
Check 'Format-Age null'    (Format-Age $null) 'n/a'

Remove-Item -LiteralPath $root -Recurse -Force

if ($fail.Count) {
    Write-Host ''
    $fail | ForEach-Object { Write-Host "FAIL $_" -ForegroundColor Red }
    exit 1
}
Write-Host "`nall checks passed" -ForegroundColor Green
