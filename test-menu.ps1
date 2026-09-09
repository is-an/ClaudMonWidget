# Checks the context-menu mechanics widget.ps1 depends on, using its real
# helpers. Two things here are easy to get wrong and silent when wrong:
#
#   - WPF MenuItem has no radio mode, so an opacity group behaves like
#     checkboxes unless the siblings are cleared on every click.
#   - A scriptblock with GetNewClosure() runs against a cloned scope. It cannot
#     see $script: variables assigned by its creator, nor functions defined
#     inside the enclosing function. Shared state has to travel by reference.
#
# Run:  powershell -File test-menu.ps1

# Without this an error while evaluating a Check argument kills that one line
# and lets the run finish with "all checks passed" having silently skipped it.
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
. (Join-Path $PSScriptRoot 'widget.ps1')

# Dot-sourcing drags in widget.ps1's own -Skin parameter, empty and still
# carrying its ValidateSet. GetNewClosure() snapshots every visible variable and
# re-applies that attribute, which then rejects the empty value. Drop it.
Remove-Variable Skin -ErrorAction SilentlyContinue

$state = @{ Items = @(); Chose = $null }
$menu = New-Object System.Windows.Controls.ContextMenu

foreach ($v in @(0.55, 0.75, 0.92, 1.0)) {
    $val = $v
    $mi = Add-MenuItem $menu "Opacity $val" ({
        param($item, $e)
        Set-OnlyChecked $state.Items $item
        $state.Chose = $val
    }.GetNewClosure())
    $mi.IsCheckable = $true
    $mi.IsChecked = ($val -eq 0.92)
    $state.Items += $mi
}

$fail = @()
function Check($n, $a, $e) {
    if ($a -ne $e) { $script:fail += "$n : expected $e, got $a" } else { Write-Host "ok   $n = $a" }
}

function Click($mi) {
    $mi.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.MenuItem]::ClickEvent)))
}

Check 'menu built'    $menu.Items.Count 4
Check 'starts on one' (@($state.Items | Where-Object IsChecked).Count) 1

Click $state.Items[0]
Check 'handler ran, shared state visible' $state.Chose 0.55
Check 'exactly one checked'               (@($state.Items | Where-Object IsChecked).Count) 1
Check 'clicked one is checked'            $state.Items[0].IsChecked $true
Check 'starting one cleared'              $state.Items[2].IsChecked $false

# The real bug this guards: without Set-OnlyChecked a second click leaves two
# opacities selected at once.
Click $state.Items[3]
Check 'still exactly one checked' (@($state.Items | Where-Object IsChecked).Count) 1
Check 'second click wins'         $state.Items[3].IsChecked $true
Check 'first click cleared'       $state.Items[0].IsChecked $false
Check 'value followed the click'  $state.Chose 1.0

Add-Separator $menu
Check 'separator added' $menu.Items.Count 5

# --- event handler argument binding -----------------------------------------
# A scriptblock wired to an event is handed (sender, args) positionally, so a
# typed parameter gets the sender - a DispatcherTimer, say - and the cast throws
# inside the handler, where nothing surfaces it. That is how the widget's
# auto-sync and Sync now both died while the widget went on looking healthy: the
# cache stopped refreshing, the session window rolled over, and the percentage
# went grey until a restart. Handlers take no parameters; a wrapper passes the
# real argument on.
$seen = @{ Typed = 'never ran'; Wrapped = 'never ran' }

$typedHandler = { param([int]$MinAgeSeconds) $seen.Typed = "ran $MinAgeSeconds" }.GetNewClosure()
$innerWork    = { param([int]$MinAgeSeconds) $seen.Wrapped = "ran $MinAgeSeconds" }.GetNewClosure()
$wrapped      = { & $innerWork 60 }.GetNewClosure()

# What an event does to a typed handler, without needing a dispatcher for it.
$timerLike = New-Object System.Windows.Threading.DispatcherTimer
try { $typedHandler.Invoke($timerLike, $null) } catch { }
Check 'typed handler never runs' $seen.Typed 'never ran'

# The wrapper, driven by a real tick.
$t = New-Object System.Windows.Threading.DispatcherTimer
$t.Interval = [timespan]::FromMilliseconds(50)
$t.Add_Tick($wrapped)
$t.Add_Tick({
    $t.Stop()
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
}.GetNewClosure())
$t.Start()
try { [System.Windows.Threading.Dispatcher]::Run() } catch { }

Check 'wrapped handler runs on tick' $seen.Wrapped 'ran 60'

if ($fail.Count) {
    Write-Host ''
    $fail | ForEach-Object { Write-Host "FAIL $_" -ForegroundColor Red }
    exit 1
}
Write-Host "`nall checks passed" -ForegroundColor Green
