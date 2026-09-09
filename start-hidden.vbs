' Starts the widget with no console window at all.
' powershell -WindowStyle Hidden still flashes a console for a moment; this does not.
Set sh = CreateObject("WScript.Shell")
dir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -File """ & dir & "widget.ps1""", 0, False
