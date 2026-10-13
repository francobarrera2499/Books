@echo off
rem Lanza "Fe de erratas". Partidas y config del jugador en .work\jugador (separadas de las pruebas automaticas), dentro de esta carpeta por la regla del proyecto.
set "ROOT=%~dp0"
set "APPDATA=%ROOT%.work\jugador\appdata"
set "LOCALAPPDATA=%ROOT%.work\jugador\localappdata"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
start "" "%ROOT%tools\Godot_v4.7.2-stable_win64.exe" --path "%ROOT%game"
