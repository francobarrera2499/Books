@echo off
rem Lanza "Fe de erratas". Guarda partidas y config dentro de esta carpeta (.work), por la regla del proyecto.
set "ROOT=%~dp0"
set "APPDATA=%ROOT%.work\appdata"
set "LOCALAPPDATA=%ROOT%.work\localappdata"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
start "" "%ROOT%tools\Godot_v4.7.2-stable_win64.exe" --path "%ROOT%game"
