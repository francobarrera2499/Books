@echo off
rem Lanza "Fe de erratas". Guarda partidas/config dentro de C:\Devooks\.work (regla del proyecto).
set "ROOT=%~dp0"
set "APPDATA=%ROOT%.workppdata"
set "LOCALAPPDATA=%ROOT%.work\localappdata"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
start "" "%ROOT%tools\Godot_v4.7.2-stable_win64.exe" --path "%ROOT%game"
