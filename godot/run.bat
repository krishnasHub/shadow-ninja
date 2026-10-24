@echo off
rem Runs Shadow Ninja (Godot version) fullscreen. Double-click it, or run it from a terminal.
rem In the game: F11 toggles fullscreen, Esc pauses, Q (while paused) quits.
rem Extra arguments are passed to Godot, e.g.  run.bat -e   opens the project in the editor.

set "GODOT_DIR=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
set "GODOT="
for %%f in ("%GODOT_DIR%\Godot_v*_win64.exe") do set "GODOT=%%f"

if not defined GODOT (
  echo Godot was not found in %GODOT_DIR%
  echo Install it with:  winget install GodotEngine.GodotEngine
  pause
  exit /b 1
)

start "" "%GODOT%" --path "%~dp0." --fullscreen %*
