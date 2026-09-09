# Wires the widget into Claude Code so it starts with your Claude sessions.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1
#   powershell ... -File install-hook.ps1 -Uninstall
#
# It adds a SessionStart hook to ~/.claude/settings.json. The widget is
# single-instance, so the hook firing on every session is harmless: the second
# and later launches see the lock and exit at once.
#
# Nothing stops the widget when Claude exits. Close it from its own right-click
# menu.
#
# Only the SessionStart entry pointing at this folder's start-hidden.vbs is
# added or removed; every other hook and setting is kept. The file is still
# rewritten by PowerShell's JSON writer, which reorders keys and re-indents, so
# a timestamped backup is written next to it first.

param(
    [switch]$Uninstall,
    [string]$SettingsPath = (Join-Path $env:USERPROFILE '.claude\settings.json')
)

Set-StrictMode -Version 2.0

$vbs = Join-Path $PSScriptRoot 'start-hidden.vbs'
if (-not (Test-Path -LiteralPath $vbs)) { throw "not found: $vbs" }
$command = "wscript.exe `"$vbs`""

if (Test-Path -LiteralPath $SettingsPath) {
    $backup = "$SettingsPath.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item -LiteralPath $SettingsPath -Destination $backup
    $settings = Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $backup = $null
    New-Item -ItemType Directory -Path (Split-Path $SettingsPath) -Force | Out-Null
    $settings = [pscustomobject]@{}
}

if (-not $settings.PSObject.Properties['hooks']) {
    $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
}
if (-not $settings.hooks.PSObject.Properties['SessionStart']) {
    $settings.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue @()
}

# Drop any entry that already points at this widget, so installing twice does
# not stack duplicates and uninstalling is just "keep everything else".
$kept = @($settings.hooks.SessionStart | Where-Object {
    ($_ | ConvertTo-Json -Depth 6 -Compress) -notlike '*start-hidden.vbs*'
})

if ($Uninstall) {
    $settings.hooks.SessionStart = $kept
    $verb = 'removed'
} else {
    $entry = [pscustomobject]@{
        hooks = @([pscustomobject]@{ type = 'command'; command = $command })
    }
    $settings.hooks.SessionStart = @($kept) + @($entry)
    $verb = 'installed'
}

$settings | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $SettingsPath -Encoding UTF8

Write-Host "$verb : $SettingsPath"
if ($backup) { Write-Host "backup  : $backup" }
if (-not $Uninstall) {
    Write-Host "command : $command"
    Write-Host ''
    Write-Host 'Start a new Claude Code session to see it.'
}
