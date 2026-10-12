#!/bin/sh
# Wrapper: keeps ALL Godot user/config/cache data inside C:\Dev\books\.work (rule: never touch files outside the repo dir)
# LOAD LIMIT (user's PC rebooted under load): at most GODOT_SLOTS (default 2) Godot processes at once,
# and at most 1 windowed (GPU) process. Extra callers WAIT for a free slot (message on stderr).
ROOT="$(cd "$(dirname "$0")" && pwd)"
export APPDATA="$(cygpath -w "$ROOT/.work/appdata" 2>/dev/null || echo "$ROOT/.work/appdata")"
export LOCALAPPDATA="$(cygpath -w "$ROOT/.work/localappdata" 2>/dev/null || echo "$ROOT/.work/localappdata")"
export TEMP="$(cygpath -w "$ROOT/.work/temp" 2>/dev/null || echo "$ROOT/.work/temp")"
export TMP="$TEMP"
mkdir -p "$ROOT/.work/appdata" "$ROOT/.work/localappdata" "$ROOT/.work/temp" "$ROOT/.work/locks"
LOCKDIR="$ROOT/.work/locks"
SLOTS="${GODOT_SLOTS:-2}"
HELD=""
release() { for d in $HELD; do rm -rf "$d"; done; HELD=""; }
trap 'release' EXIT
trap 'release; exit 130' INT TERM HUP
stale() { # $1 = lock dir. stale if owner pid dead, or no pid after 60s, or older than 40 min
  p=$(cat "$1/pid" 2>/dev/null)
  if [ -n "$p" ]; then kill -0 "$p" 2>/dev/null || return 0; fi
  [ -z "$p" ] && [ -n "$(find "$1" -maxdepth 0 -mmin +1 2>/dev/null)" ] && return 0
  [ -n "$(find "$1" -maxdepth 0 -mmin +40 2>/dev/null)" ] && return 0
  return 1
}
acquire() { # $1 = prefix, $2 = slots
  waited=0
  while :; do
    i=0
    while [ "$i" -lt "$2" ]; do
      d="$LOCKDIR/$1.$i"
      if mkdir "$d" 2>/dev/null; then echo $$ > "$d/pid"; HELD="$HELD $d"; return 0; fi
      if stale "$d"; then rm -rf "$d"; continue; fi
      i=$((i+1))
    done
    [ "$waited" -eq 0 ] && echo "godot.sh: esperando turno ($1: $2 en uso; límite de carga del PC)..." >&2
    waited=$((waited+1)); sleep 3
  done
}
case " $* " in
  *" --headless "*) ;;
  *) acquire gpu 1 ;;
esac
acquire slot "$SLOTS"
cd "$ROOT/game"
"$ROOT/tools/Godot_v4.7.2-stable_win64_console.exe" "$@"
rc=$?
release
exit $rc
