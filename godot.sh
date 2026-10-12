#!/bin/sh
# Wrapper: keeps ALL Godot user/config/cache data inside C:\Dev\books\.work (rule: never touch files outside the repo dir)
ROOT="$(cd "$(dirname "$0")" && pwd)"
export APPDATA="$(cygpath -w "$ROOT/.work/appdata" 2>/dev/null || echo "$ROOT/.work/appdata")"
export LOCALAPPDATA="$(cygpath -w "$ROOT/.work/localappdata" 2>/dev/null || echo "$ROOT/.work/localappdata")"
export TEMP="$(cygpath -w "$ROOT/.work/temp" 2>/dev/null || echo "$ROOT/.work/temp")"
export TMP="$TEMP"
mkdir -p "$ROOT/.work/appdata" "$ROOT/.work/localappdata" "$ROOT/.work/temp"
cd "$ROOT/game"
exec "$ROOT/tools/Godot_v4.7.2-stable_win64_console.exe" "$@"
