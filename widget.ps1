# ClaudMonWidget - translucent always-on-top Claude Code usage widget.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File widget.ps1
#   powershell ... -File widget.ps1 -Skin detail
#
# Drag to move. Right-click for the menu. Position, skin and opacity are saved
# to config.json next to this script.
#
# Kept ASCII on purpose: PowerShell 5.1 reads a BOM-less script as ANSI, so any
# non-ASCII string here would come out mangled. Korean labels live in the XAML,
# which is read as UTF-8 explicitly.

param(
    [ValidateSet('simple1','simple2','border1','border2','detail','border-both','detail-both')]
    [string]$Skin,
    [ValidateSet('claude','codex')]
    [string]$Tool
)

Set-StrictMode -Version 2.0
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# test-menu.ps1 dot-sources this file for its helpers. It must not take the
# single-instance lock and must not open a window.
$Standalone = ($MyInvocation.InvocationName -ne '.')

# One widget per user. The Claude Code hook fires on every session start, so
# without this a day's work leaves a stack of widgets on top of each other, and
# the one on top may be an old instance showing an old reset time.
if ($Standalone) {
    $mutex = New-Object System.Threading.Mutex($false, 'Local\ClaudMonWidget')
    if (-not $mutex.WaitOne(0)) { exit 0 }
}

. (Join-Path $PSScriptRoot 'usage.ps1')

$ConfigPath = Join-Path $PSScriptRoot 'config.json'

# The "1" variants show the 5-hour session only; the "2" variants add the
# 7-day window. The "-both" variants stack Claude and Codex in one window and
# ignore the Tool setting. Order here is the order of the right-click menu.
$Skins = @('simple1','simple2','border1','border2','detail','border-both','detail-both')

$Default = @{
    tool        = 'claude'   # claude | codex - which CLI's usage to show
    skin        = 'border2'
    opacity     = 0.92
    left        = -1        # -1 means "not placed yet"
    top         = -1
    pollSeconds = 5         # re-read local files
    syncSeconds = 300       # ask Anthropic for fresh utilization
    autoSync    = $true
    windowHours = 5
    warnPct     = 70
    dangerPct   = 90
}

function Read-Config {
    $c = $Default.Clone()
    if (Test-Path -LiteralPath $ConfigPath) {
        try {
            $json = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($k in @($c.Keys)) {
                $p = $json.PSObject.Properties[$k]
                if ($p -and $null -ne $p.Value) { $c[$k] = $p.Value }
            }
        } catch { }   # a corrupt config should not stop the widget starting
    }
    return $c
}

function Write-Config($c) {
    try {
        [pscustomobject]$c | ConvertTo-Json | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
    } catch { }
}

$cfg = Read-Config
if ($Skin) { $cfg.skin = $Skin }
if ($Tool) { $cfg.tool = $Tool }
if ($cfg.tool -ne 'codex') { $cfg.tool = 'claude' }   # unknown name -> default

# The two CLIs expose the same shape of numbers; one pair of readers per tool.
function Get-Usage {
    param([double]$WindowHours)
    if ($cfg.tool -eq 'codex') { return Get-CodexUsage -WindowHours $WindowHours }
    return Get-ClaudeUsage -WindowHours $WindowHours
}
function Get-Account {
    if ($cfg.tool -eq 'codex') { return Get-CodexAccount }
    return Get-ClaudeAccount
}

# Fill a skin's name/plan elements from an account object. Both may be $null -
# skins that leave them out just get skipped.
function Set-AccountText($acct, $userEl, $planEl) {
    if ($userEl) {
        $who = $acct.Name
        if (-not $who) { $who = $acct.Email }
        if (-not $who) { $who = 'not signed in' }
        $userEl.Text = $who
        if ($acct.Email) { $userEl.ToolTip = $acct.Email }
    }
    if ($planEl) {
        if ($acct.Plan) { $planEl.Text = $acct.Plan } else { $planEl.Text = '--' }
    }
}

$Green = '#4ADE80'
$Amber = '#FBBF24'
$Red   = '#F87171'
$Grey  = '#9AA0A6'

function Get-StateColor($pct) {
    if ($null -eq $pct)          { return $Grey }
    if ($pct -ge $cfg.dangerPct) { return $Red }
    if ($pct -ge $cfg.warnPct)   { return $Amber }
    return $Green
}

function Set-Brush($element, $hex) {
    if (-not $element) { return }
    $brush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($hex)
    if ($element -is [System.Windows.Shapes.Shape]) { $element.Fill = $brush }
    else { $element.Background = $brush }
}

# These three live at script level rather than inside Show-Widget: a scriptblock
# with GetNewClosure() runs against a cloned scope that cannot see functions
# defined inside the enclosing function, but does see script-level ones.
function Add-MenuItem($menu, $header, $action) {
    $mi = New-Object System.Windows.Controls.MenuItem
    $mi.Header = $header
    $mi.Add_Click($action)
    $menu.Items.Add($mi) | Out-Null
    return $mi
}

function Add-Separator($menu) {
    $menu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null
}

# WPF MenuItem has no radio mode: IsCheckable only toggles, so a group of them
# behaves like independent checkboxes. Clearing the siblings on click is what
# makes a set mutually exclusive.
function Set-OnlyChecked($group, $chosen) {
    foreach ($mi in $group) { $mi.IsChecked = [bool]($mi -eq $chosen) }
}

# --- build one window from a skin file -------------------------------------
# Returns $true to keep running (skin switch), $false to exit for good.
function Show-Widget([string]$skinName) {

    $xamlPath = Join-Path $PSScriptRoot ("skins\$skinName.xaml")
    if (-not (Test-Path -LiteralPath $xamlPath)) {
        # A config.json written by an older version names a skin that no longer
        # exists. Falling back beats refusing to start over a cosmetic setting.
        $skinName = $Default.skin
        $cfg.skin = $skinName
        $xamlPath = Join-Path $PSScriptRoot ("skins\$skinName.xaml")
        if (-not (Test-Path -LiteralPath $xamlPath)) { throw "skin not found: $xamlPath" }
    }

    [xml]$xaml = [System.IO.File]::ReadAllText($xamlPath, [System.Text.Encoding]::UTF8)
    $win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

    $win.Opacity = [double]$cfg.opacity
    $win.WindowStartupLocation = 'Manual'
    if ($cfg.left -ge 0 -and $cfg.top -ge 0) {
        $win.Left = $cfg.left
        $win.Top  = $cfg.top
    } else {
        # Off-screen until ContentRendered can measure the skin and place it in
        # the bottom-right corner, so the first frame does not flash mid-screen.
        $win.Left = -10000
        $win.Top  = -10000
    }

    # Skins are free to omit any of these; every use is null-guarded. A "-both"
    # skin carries a second copy of the usage elements with a "2" suffix - the
    # Codex block - which $ui2 collects.
    $usageNames = @('Dot','TxtMain','TxtSub','TxtReset','TxtWeek','TxtWeekReset',
                    'BarTrack','BarFill','WeekTrack','WeekFill','TxtUser','TxtPlan')
    $ui  = @{ Root = $win.FindName('Root') }
    $ui2 = @{}
    foreach ($n in $usageNames) {
        $ui[$n]  = $win.FindName($n)
        $ui2[$n] = $win.FindName($n + '2')
    }
    $both = [bool]$ui2.TxtMain

    # The account does not change while the widget runs, so read it once. In a
    # both skin the first block is always Claude, the second always Codex.
    if ($both) {
        Set-AccountText (Get-ClaudeAccount) $ui.TxtUser  $ui.TxtPlan
        Set-AccountText (Get-CodexAccount)  $ui2.TxtUser $ui2.TxtPlan
    } else {
        Set-AccountText (Get-Account) $ui.TxtUser $ui.TxtPlan
    }

    # Everything the event handlers below have to share and mutate lives here.
    # A closure captures the hashtable reference, so writes through it are seen
    # by everyone; $script: variables are not, because GetNewClosure() runs the
    # handler against a cloned scope with its own script-level storage.
    $state = @{
        Relaunch      = $false
        SyncNote      = ''
        SyncTimer     = $null
        Both          = $both
        ToolItems     = @()
        SkinItems     = @()
        OpacityItems  = @()
        WindowExpired = $false   # the cached window has rolled over; re-sync
    }

    # --- drag ---
    # DragMove throws if the button is already released by the time it runs.
    $win.Add_MouseLeftButtonDown({ try { $win.DragMove() } catch { } }.GetNewClosure())

    # --- paint one usage result into one block of elements -----------------
    # $e is a hashtable keyed by the un-suffixed element names ($ui or $ui2).
    # $primary is the Claude/5-hour block whose rollover drives the re-sync.
    $paint = {
        param($u, $e, $primary)

        $pct = $u.FiveHourPct
        if ($primary) { $state.WindowExpired = ($null -eq $pct) }

        $color = Get-StateColor $pct
        Set-Brush $e.Dot $color
        Set-Brush $e.BarFill $color

        if ($null -ne $pct) {
            if ($e.TxtMain) { $e.TxtMain.Text = ('{0:0}%' -f $pct) }
        } else {
            # An expired window: show our own tally, never dressed as a percent.
            if ($e.TxtMain) { $e.TxtMain.Text = (Format-Tokens $u.WindowBilled) }
        }

        if ($e.BarFill -and $e.BarTrack) {
            $w = $e.BarTrack.ActualWidth
            if ($w -gt 0) {
                $frac = 0
                if ($null -ne $pct) { $frac = [math]::Min(1.0, $pct / 100.0) }
                $e.BarFill.Width = $w * $frac
            }
        }

        if ($e.TxtReset) { $e.TxtReset.Text = Format-Remaining $u.FiveHourResets }

        if ($e.TxtWeek) {
            if ($null -ne $u.SevenDayPct) { $e.TxtWeek.Text = ('{0:0}%' -f $u.SevenDayPct) }
            else { $e.TxtWeek.Text = '--' }
        }
        if ($e.TxtWeekReset) { $e.TxtWeekReset.Text = Format-Remaining $u.SevenDayResets }
        if ($e.WeekFill -and $e.WeekTrack -and $null -ne $u.SevenDayPct) {
            $w = $e.WeekTrack.ActualWidth
            if ($w -gt 0) { $e.WeekFill.Width = $w * [math]::Min(1.0, $u.SevenDayPct / 100.0) }
        }

        if ($e.TxtSub) {
            # The sync note is about the Anthropic call, so it belongs only on
            # the Claude block.
            $tail = ''
            if ($primary) { $tail = $state.SyncNote }
            if (-not $tail) { $tail = ('{0} {1}' -f $u.Source, (Format-Age $u.FetchedAgeMin)) }
            $e.TxtSub.Text = ('{0} tok / {1} req / {2}' -f `
                (Format-Tokens $u.WindowBilled), $u.WindowRequests, $tail)
        }
    }.GetNewClosure()

    # --- redraw from local files (cheap, runs every pollSeconds) ---
    $refresh = {
        if ($state.Both) {
            $c = $null; $x = $null
            try { $c = Get-ClaudeUsage -WindowHours ([double]$cfg.windowHours) } catch { }
            try { $x = Get-CodexUsage  -WindowHours ([double]$cfg.windowHours) } catch { }
            if ($c) { & $paint $c $ui  $true  } elseif ($ui.TxtMain)  { $ui.TxtMain.Text  = '!' }
            if ($x) { & $paint $x $ui2 $false } elseif ($ui2.TxtMain) { $ui2.TxtMain.Text = '!' }
            $cp = $(if ($c -and $null -ne $c.FiveHourPct) { '{0:0}%' -f $c.FiveHourPct } else { '--' })
            $xp = $(if ($x -and $null -ne $x.FiveHourPct) { '{0:0}%' -f $x.FiveHourPct } else { '--' })
            $win.ToolTip = ('claude {0}   codex {1}' -f $cp, $xp)
            return
        }

        try {
            $u = Get-Usage -WindowHours ([double]$cfg.windowHours)
        } catch {
            if ($ui.TxtMain) { $ui.TxtMain.Text = '!' }
            return
        }

        & $paint $u $ui $true

        $win.ToolTip = ('window from {0}   billed {1}   cache read {2}   source {3}' -f `
            $u.WindowStart.ToString('HH:mm'),
            (Format-Tokens $u.WindowBilled),
            (Format-Tokens $u.WindowCacheRead),
            $u.Source)
    }.GetNewClosure()

    # --- talk to Anthropic ---
    # A failed sync is not fatal: the note goes on the widget and the local
    # sources still drive the display.
    #
    # Called directly only. A scriptblock wired to an event is handed
    # (sender, args) positionally, so a typed parameter like this one would
    # try to cast a DispatcherTimer to [int] and throw inside the handler -
    # silently, since nothing surfaces an exception raised in a tick. That is
    # how auto-sync and Sync now both stopped working while the widget went on
    # looking healthy.
    $doSync = {
        param([int]$MinAgeSeconds)
        # Codex writes its rate limits to the session log every turn, so there
        # is nothing to fetch - just redraw from the files. A both skin always
        # shows Claude too, so it still needs the sync.
        if ($cfg.tool -eq 'codex' -and -not $state.Both) { $state.SyncNote = ''; & $refresh; return }
        $status = Sync-ClaudeUsage -MinAgeSeconds $MinAgeSeconds
        if ($status -eq 'ok') { $state.SyncNote = '' } else { $state.SyncNote = $status }
        & $refresh
    }.GetNewClosure()

    # Event-facing wrapper: takes no parameters, so the arguments an event
    # supplies land harmlessly in $args.
    $sync = { & $doSync 0 }.GetNewClosure()

    # --- timers ---
    # The poll tick also closes the gap at a window rollover. Without it the
    # widget sits grey, showing no percentage, until the next scheduled sync -
    # up to syncSeconds of looking broken right when the number matters.
    # MinAgeSeconds 60 is what stops that from turning into a retry storm: once
    # a sync has written the cache, the next ticks return without a call.
    $tick = {
        & $refresh
        if ($state.WindowExpired) { & $doSync 60 }
    }.GetNewClosure()

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [timespan]::FromSeconds([double]$cfg.pollSeconds)
    $timer.Add_Tick($tick)

    $state.SyncTimer = New-Object System.Windows.Threading.DispatcherTimer
    $state.SyncTimer.Interval = [timespan]::FromSeconds([double]$cfg.syncSeconds)
    $state.SyncTimer.Add_Tick($sync)

    # --- context menu ---
    $menu = New-Object System.Windows.Controls.ContextMenu

    # Switching tool rebuilds the window - the account line and every number
    # come from the other source - so it relaunches like a skin change.
    foreach ($t in @('claude','codex')) {
        $name = $t
        $mi = Add-MenuItem $menu "Tool: $name" ({
            param($item, $e)
            Set-OnlyChecked $state.ToolItems $item
            if ($cfg.tool -ne $name) {
                $cfg.tool = $name
                $state.Relaunch = $true
                $win.Close()
            }
        }.GetNewClosure())
        $mi.IsCheckable = $true
        $mi.IsChecked = ($cfg.tool -eq $name)
        # A both skin shows Claude and Codex regardless, so the choice is moot.
        $mi.IsEnabled = -not $state.Both
        $state.ToolItems += $mi
    }
    Add-Separator $menu

    foreach ($s in $Skins) {
        $name = $s
        $mi = Add-MenuItem $menu "Skin: $name" ({
            param($item, $e)
            Set-OnlyChecked $state.SkinItems $item
            if ($cfg.skin -ne $name) {
                $cfg.skin = $name
                $state.Relaunch = $true
                $win.Close()
            }
        }.GetNewClosure())
        $mi.IsCheckable = $true
        $mi.IsChecked = ($cfg.skin -eq $name)
        $state.SkinItems += $mi
    }
    Add-Separator $menu

    foreach ($o in @(0.55, 0.75, 0.92, 1.0)) {
        $val = $o
        $mi = Add-MenuItem $menu ("Opacity {0:0}%" -f ($o * 100)) ({
            param($item, $e)
            Set-OnlyChecked $state.OpacityItems $item
            $cfg.opacity = $val
            $win.Opacity = $val
        }.GetNewClosure())
        $mi.IsCheckable = $true
        $mi.IsChecked = ([math]::Abs([double]$cfg.opacity - $val) -lt 0.01)
        $state.OpacityItems += $mi
    }
    Add-Separator $menu

    $miTop = Add-MenuItem $menu 'Always on top' ({
        param($item, $e)
        $win.Topmost = [bool]$item.IsChecked
    }.GetNewClosure())
    $miTop.IsCheckable = $true
    $miTop.IsChecked = $win.Topmost

    $miAuto = Add-MenuItem $menu 'Auto sync' ({
        param($item, $e)
        $cfg.autoSync = [bool]$item.IsChecked
        if ($cfg.autoSync) { $state.SyncTimer.Start() } else { $state.SyncTimer.Stop() }
    }.GetNewClosure())
    $miAuto.IsCheckable = $true
    $miAuto.IsChecked = [bool]$cfg.autoSync

    Add-MenuItem $menu 'Sync now'    $sync    | Out-Null
    Add-MenuItem $menu 'Refresh now' $refresh | Out-Null
    Add-MenuItem $menu 'Exit' ({ $state.Relaunch = $false; $win.Close() }.GetNewClosure()) | Out-Null

    if ($ui.Root) { $ui.Root.ContextMenu = $menu } else { $win.ContextMenu = $menu }

    # The local poll starts first and unconditionally. It is what keeps the
    # countdown moving, so nothing that happens during a sync may prevent it:
    # a widget frozen on its first frame still looks alive while showing a
    # reset time that quietly drifts an hour out of date.
    $win.Add_SourceInitialized({
        $timer.Start()
        & $refresh
        if ($cfg.autoSync) {
            try {
                # Reuse a cache younger than one sync interval instead of
                # refetching it just because the widget restarted.
                & $doSync ([int]$cfg.syncSeconds)
                $state.SyncTimer.Start()
            } catch { $state.SyncNote = 'sync start failed' }
        }
    }.GetNewClosure())

    # Width and height come from the skin's own layout, so the first-run corner
    # placement has to wait until that layout has actually happened.
    $win.Add_ContentRendered({
        if ($cfg.left -lt 0 -or $cfg.top -lt 0) {
            $wa = [System.Windows.SystemParameters]::WorkArea
            $win.Left = $wa.Right  - $win.ActualWidth  - 24
            $win.Top  = $wa.Bottom - $win.ActualHeight - 24
        }
    }.GetNewClosure())

    $win.Add_Closing({
        $timer.Stop()
        $state.SyncTimer.Stop()
        $cfg.left = [int]$win.Left
        $cfg.top  = [int]$win.Top
        Write-Config $cfg
    }.GetNewClosure())

    $win.ShowDialog() | Out-Null
    return $state.Relaunch
}

# Switching skins rebuilds the window, so the whole thing runs in a loop.
if ($Standalone) {
    while (Show-Widget $cfg.skin) { }
}
