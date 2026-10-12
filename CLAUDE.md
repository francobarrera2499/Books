# Books — notas para agentes IA

Fuente de verdad del usuario: `design.md` (leerlo). Resumen de reglas duras:
- PROHIBIDO leer/escribir/listar nada fuera de `C:\Dev\books` (ni AppData, ni Temp del sistema, ni scratchpad, ni ~/.gitconfig). Temporales -> `C:\Dev\books\.work\`.
- PROHIBIDO acceder a repos de github.com/francobarrera2499 salvo https://github.com/francobarrera2499/Books.git.
- Internet permitido (Gutenberg, wikis Holmes, docs Godot, game design). Prohibición > permiso; ante ambigüedad, preguntar/reportar, nunca asumir.
- Godot: usar SIEMPRE `./godot.sh` (desde la raíz; hace cd a game/ y redirige APPDATA/TEMP a .work). Nunca el .exe directo.
- Código: solo lo leen IAs; no hace falta prolijidad. Features principales con tests.
- Commits por milestone (los hace el orquestador).
- Corridas de Godot con ventana (capturas) PERMITIDAS por el usuario.

Layout: `game/` proyecto Godot 4.7 · `docs/` diseño · `tools/` Godot exe (ignorado) · `.work/` temporales (ignorado).

Fuentes (aprobadas por el usuario, en `game/assets/fonts/`, con licencias): IMFeENrm28P.ttf / IMFeENit28P.ttf (IM Fell English, imprenta), SpecialElite-Regular.ttf (máquina de escribir), HomemadeApple-Regular.ttf (manuscrito). Cubren español completo. PROHIBIDO SystemFont (leería C:\Windows\Fonts).
