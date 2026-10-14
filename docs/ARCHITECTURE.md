# FE DE ERRATAS — ARQUITECTURA TÉCNICA

> **Lectores:** sólo agentes IA. Denso a propósito. **Diseño:** `docs/GDD.md` (citado GDD§n). **Usuario:** `design.md`. **Reglas duras:** `CLAUDE.md`.
> Si este documento choca con el GDD en **contenido**, gana el GDD; en **técnica**, gana este documento. Ambigüedad → no asumir: reportar en la respuesta final.
> Motor: Godot **4.7.2**, Forward+, GDScript, **sin `class_name`**. Todo bajo `C:\Dev\books`. Godot **sólo** vía `./godot.sh` desde la raíz.
> **v3 (Expediente Holmes):** `docs/GDD_v3.md` prevalece sobre GDD/GDD_v2 y sobre lo que aquí describa conclusiones, pares, plantillas o libro mayor (ya no existen). Mapa v3: preguntas y respuestas en `data/dossier.json` + `core/deduction/dossier.gd` (`Dossier.check/view`; acciones `dq_answer`, `dq_proof`, `dq_confirm`, `clip_drop`); crónicas activas en `data/corpus.json`; la carpeta en `ui/expediente/*` (panel `dossier`, tecla E); el lector v3 (papel flotante, `ui/reader/backdrop.gdshader`, tijera suelta, paginación abajo, notas al margen) con su contrato en las cabeceras de `ui/reader/document_reader.gd` y `page_view.gd`; intrusiones en `data/reactions/*` + variantes de `data/places/L1.json`; guardado `v: 3` (un guardado anterior sólo ofrece «Partida nueva»). Partida real de punta a punta: `devtools/drivers/v3integ_partida.gd`.

## 0. Uso

- Cada archivo tiene **un dueño** (paquete de trabajo **WP**, §10). Prohibido editar archivos ajenos: si hace falta, proponer el diff en la respuesta final.
- Las firmas de §3 y los esquemas de §4 son **contrato**. Cambiarlos es decisión del orquestador.
- En JSON se permiten campos extra que empiecen con `_` (notas de autor); el motor los ignora.
- IDs del GDD se usan tal cual: `D05`, `L4`, `C2`, `C2.R2`, `HC01`, `HA1`, `HB4`, `M7`, `K-BM`, `T03`.
- Convención de IDs nuevos: recortes `RC0001`, pares `PR001`, folios `FO001`, asientos `AS001`, instancias de documentos generados `R.<reacción>.<n>` / `AD.<n>` (anuncio) / `TG.<n>` (telegrama) / `LT.<n>` (carta) / `RP.<n>` (informe), visitas/escenas `S.<lugar>.<día>.<franja>`, láminas `PL.<lugar>.<día>.<franja>`, actos `act.<seq>`.

---

## 1. Árbol de carpetas (dueño por WP)

```
C:\Dev\books\
  godot.sh  design.md  CLAUDE.md
  docs/  GDD.md  ARCHITECTURE.md  research/  concepts/
  .work/                       temporales; .work/shots (capturas), .work/tests (archivos de tests), .work/appdata (user:// de Godot)
  tools/                       Godot exe (ignorado)
  game/
    project.godot              W1-ENG (creado por el arquitecto)
    main.tscn                  única escena empaquetada (Node + main.gd)            W3-SHELL
    main.gd                    arranque, args, crea Shell                           W3-SHELL
    autoload/
      theme_installer.gd       W1-THEME
      data.gd                  W1-ENG
      audio.gd                 W1-AUDIO
      game.gd                  W2-SIM
    core/                      LÓGICA PURA: estática o RefCounted; headless; sin Node/Input/autoloads/Time/randi
      util/      j.gd det.gd log.gd cond.gd timekey.gd                           W1-ENG
      data/      data_repo.gd schema.gd                                          W1-ENG
      text/      markup.gd clip_rules.gd                                         W1-ENG
      save/      event_log.gd                                                    W1-ENG
      sim/       game_sim.gd game_state.gd actions.gd player_actions.gd
                 clock.gd world_model.gd diary.gd tutorial.gd                    W2-SIM
                 endings.gd                                                      W2-SCENES
      deduction/ clipper.gd index.gd ledger.gd validator.gd                      W2-DED
      react/     reaction_db.gd sensors.gd latency.gd holmes_agent.gd
                 moran_agent.gd director.gd effects.gd                           W2-REACT
      scenes/    dialogue.gd confrontation.gd composers.gd                       W2-SCENES
      graph/     route_db.gd availability.gd cut_model.gd invariant.gd feasibility.gd   W2-GRAPH
    data/                      contenido JSON; dueños en §4.1
    ui/
      shell.gd layers.gd input_router.gd                                         W3-SHELL
      kit/       theme_builder.gd widgets.gd paper.gd                            W1-THEME
      reader/    document_reader.gd page_view.gd text_builder.gd selection_mapper.gd
                 ruler.gd lens.gd fx_remington.gd rasante.gdshader               W2-READER
      desk/      game_screen.gd desk_hud.gd tray.gd dawn.gd                      W3-SHELL
      drag/      drag_layer.gd drop_catcher_3d.gd chips.gd                       W3-SHELL
      map/       map_screen.gd map_draw.gd                                       W3-SHELL
      menus/     title.gd options.gd                                             W3-SHELL
      notebook/  notebook.gd tab_clips.gd tab_index.gd tab_pairs.gd tab_diary.gd
                 tab_marginalia.gd clip_card.gd                                  W3-NOTEBOOK
      ledger/    ledger.gd ledger_model.gd picker.gd rules_page.gd folio_page.gd entry_view.gd seal.gd     W3-LEDGER
      scene/     scene_panel.gd ask_panel.gd present_bar.gd confrontation_view.gd W3-SCENEUI
      compose/   ad_composer.gd telegram_composer.gd report_composer.gd          W3-SCENEUI
      epilogue/  epilogue_screen.gd credits.gd blue_pencil.gd                    W4-EPILOGUE
    world/
      world_root.gd diorama_builder.gd camera_rig.gd picker.gd rect_clip.gd materials.gd   W1-3D
      props/     furniture.gd architecture.gd street.gd small.gd                 W1-3D
                 l1.gd l2.gd l3.gd l4.gd l5.gd l6.gd l7.gd l8.gd plates.gd       WP del lugar (W2-PLACES-*)
      characters/ mannequin.gd crowd.gd                                          W1-3D
      lighting.gd                                                                W1-POST (W4-STYLE en ola 4)
      post/      engraving_post.gd looks.gd looks/{aguada,grabado}.{gdshader,json}   W1-POST (W4-STYLE en ola 4)
    audio/
      synth.gd proc_audio.gd sound_bank.gd                                       W1-AUDIO
    assets/fonts/              IMFeENrm28P.ttf IMFeENit28P.ttf SpecialElite-Regular.ttf HomemadeApple-Regular.ttf + licencias (ya existen)
    devtools/
      shot.gd (existe) blank.tscn lint.gd data_report.gd                         W1-ENG
      play_cli.gd  bots/{bot_base.gd, bot_*.gd, run_bots.gd}                     W3-BOTS
      drivers/<wp>_<nombre>.gd   drivers de captura, uno o más por WP            cada WP
    tests/
      run_tests.gd test_base.gd test_harness_selfcheck.gd test_t00_compile_all.gd   W1-ENG
      test_u_<modulo>.gd  test_tNN_<nombre>.gd                                   dueño según §9
      content_gate.json        {"strict": false} → true en ola 4                 W4-QA
      fixtures/data_min/       mini dataset de motor (todas las formas de §4)     W1-ENG
      fixtures/<wp>/           fixtures propios de cada WP                       cada WP
      fixtures/canon/*.txt     textos de dominio público de Doyle (T7)           W1-BIBLE
      fixtures/audio_hashes.json                                                 W1-AUDIO
```

Dirección de dependencias en `core/` (nunca al revés; prohibido el ciclo de `preload`):
`util ← text ← data ← {deduction, graph, react} ← scenes ← sim` (§12.2: `data/data_repo.gd` y `data/schema.gd` precargan `text/markup.gd`; `text/` sólo depende de `util/`). `sim/game_sim.gd` es el único que precarga todos. Los módulos reciben `st` (GameState) y `repo` (DataRepo) **por parámetro** y no precargan `game_state.gd`.
Hacia «arriba» sólo se llega con `load()` en tiempo de llamada (nunca `preload`), y esto es lo único admitido: `deduction/clipper.gd` → `sim/world_model.gd` (fuentes y accesibilidad) · `deduction/validator.gd` → `sim/clock.gd` (pasadas) · `react/effects.gd` → `sim/world_model.gd` (documentos runtime) · `react/director.gd` → `graph/{cut_model,invariant}.gd` (D1) · `react/moran_agent.gd` → `deduction/{clipper,validator}.gd` (report_cats) · `scenes/deps.gd` → `deduction/*`, `react/{director,effects,moran_agent}.gd`.

---

## 2. Autoloads, escena principal y flujo

### 2.1 Reglas

- Orden en `project.godot`: `ThemeInstaller`, `Data`, `Audio`, `Game`. **Ya registrados** con stubs válidos (firmas definitivas).
- Ningún autoload hace trabajo pesado ni `push_error` en `_ready` (el runner de tests los instancia; un ERROR del motor es fallo).
- `core/` jamás referencia autoloads. `ui/`, `world/`, `audio/` y `main.gd` sí.
- Configs de autoload que se leen sin DataRepo (excepción documentada): `data/fonts.json` (ThemeInstaller) y `data/audio.json` (Audio), con `JSON.parse_string(FileAccess.get_file_as_string(p))`.

### 2.2 API de autoloads (stubs en `game/autoload/`)

```gdscript
# ThemeInstaller (W1-THEME) — §6.2
signal theme_changed
const SLOTS := ["imprenta", "maquina", "manuscrito", "ui"]
var theme: Theme; var text_scale := 1.0; var high_contrast := false
func install() -> void                      # en _ready: arma Theme, instala en ThemeDB.get_default_theme() y ThemeDB.fallback_font
func font(slot: String, italic := false) -> Font
func set_slot(slot: String, path: String) -> void   # "embedded" o res://assets/fonts/x.ttf; re-instala y emite theme_changed
func set_text_scale(f: float) -> void       # 0.8..1.6
func set_high_contrast(on: bool) -> void
func px(kind: String) -> int                # tamaños base: "doc","ui","small","title","caption" × text_scale

# Data (W1-ENG)
func repo()                                 # DataRepo compartido (perezoso) de res://data
func reload() -> void

# Audio (W1-AUDIO) — §8
signal subtitle(text: String, seconds: float)
var subtitles_on := true
func warm() -> void                         # genera TODO el banco (determinista). Lo llama main.gd tras el título; nunca en tests salvo T28
func play(id: String, volume_db := 0.0) -> void
func play_amb(id: String, fade_s := 1.0) -> void
func stop_amb(fade_s := 1.0) -> void
func set_place_ambience(place: String, slot: String) -> void   # según data/audio.json
func stream(id: String) -> AudioStream

# Game (W2-SIM) — sesión
signal sim_changed(kind: String, payload: Dictionary)   # reexpide GameSim.changed
signal session_started
signal session_ended
var sim                                     # GameSim o null
func has_save() -> bool
func new_session(seed: int = 0) -> bool     # seed 0 → semilla derivada de hash del contenido (determinista, sin Time)
func continue_session() -> bool             # EventLog.load + GameSim.replay
func act(action: Dictionary) -> Dictionary  # sim.apply; si ok y Actions.is_commit(t): EventLog.write ANTES de retornar
func end_session() -> void
```

`Game.act` es el **único** camino de la UI para mutar estado. Persistencia: acción comprometida → escritura atómica inmediata; acciones libres → escritura diferida (debounce 2 s, y en `NOTIFICATION_WM_CLOSE_REQUEST`).

### 2.3 Escena principal y flujo de pantallas

`main.tscn` (Node, `main.gd`) → `main.gd` lee `OS.get_cmdline_user_args()`:
`--new` · `--continue` · `--seed=N` · `--script=res://…jsonl` (aplica acciones en orden, para capturas) · `--screen=<title|game|reader:D05|notebook|ledger|map|place:L4|epilogue>` (salta a una pantalla) · `--fast` (sin fundidos).
Luego instancia `Shell` (`ui/shell.gd`, Node) que crea y posee:

| Capa | Nodo | Contenido | Afectada por grabado |
|---|---|---|---|
| 3D | `WorldRoot` (Node3D, `world/world_root.gd`) | diorama actual, rig de cámara, quad de grabado colgado de la cámara | sí |
| 5 | `DropCatcher3D` | recibe lo que se suelta sobre el 3D (presentar); sólo activo durante un arrastre (§6.3) | no |
| 10 | `CanvasLayer` HUD | calendario de escritorio (fecha/franja), monedas | no |
| 20 | Libros | Cuaderno, Libro mayor | no |
| 30 | Lector | `DocumentReader` a pantalla completa | no |
| 40 | Escena | panel de personaje, preguntar/afirmar/presentar, confrontación | no |
| 50 | Mapa | mapa + página Baedeker | no |
| 60 | Modal | compositores (anuncio/telegrama/carta/informe), confirmaciones de dos pasos | no |
| 90 | Subtítulos | `Audio.subtitle` | no |
| 100 | Fundido | transiciones | no |
| 120 | Arrastre | `DragLayer` (vista previa del chip arrastrado) | no |

Pantallas (las crea Shell; una activa): `Title` → `GameScreen` → `Epilogue` → `Credits` → `BluePencil` → `Title`.
`GameScreen` decide su modo leyendo `Game.sim.q_clock().phase` en cada `sim_changed("clock")`:

| phase | 3D | UI |
|---|---|---|
| `prologue` | lámina del prólogo + hub (escritorio) | instructores (Pell/Harris), verbos guiados (§3.2 tutorial) |
| `desk` | hub L1: encuadres escritorio/ventana/pared; tienda de Crane accesible | HUD, bandeja, objetos del escritorio, Tab/L/M |
| `visit` | diorama del lugar (órbita) | panel de escena si hay personajes |
| `scene` | lámina fija (M6, M7) | líneas de la escena; recortables |
| `night` | hub de noche | chico de Pell en la puerta → compositor de informe; dormir |
| `confront` | tienda de Crane, librero | `ConfrontationView` |
| `final_report` | hub | libro mayor (lote de 1) y compositor del informe final |
| `parklane` | L7 día 10 18 h (luz dorada; única animación) | líneas; recortable |
| `night_choice` | hub | elegir: Baker Street o casa |
| `epilogue` | — | `Epilogue` (oct. 1903), créditos, lápiz azul |

Amanecer: `sleep` resuelve el director dentro de `apply`; la UI (`ui/desk/dawn.gd`) reproduce el ritual (campanas, lechero, golpe de Crane; fundido) y después muestra la bandeja. Sin sonidos de alerta.

---
## 3. Núcleo headless (simulación)

### 3.1 Principios

- **Una sola puerta:** `GameSim.apply(action: Dictionary) -> Dictionary`. UI, tests y bots la usan igual. Acciones = diccionarios planos `{"t": tipo, ...args}` (§3.5). El registro de acciones ES la partida.
- **Estado canónico:** `GameState` contiene sólo `Dictionary/Array/String/int/float/bool/null`. Al serializar: claves ordenadas. Al iterar diccionarios en lógica: `keys()` + `sort()` siempre.
- **Determinismo (D7):** prohibidos en `core/`: `randi`, `randf`, `randomize`, `RandomNumberGenerator`, `Time.`, `OS.get_ticks` (lint). Aleatoriedad = `Det.pick(seed, [partes])` (hash md5, sin estado).
- **Módulos estáticos:** todo módulo de `core/` salvo `GameSim`, `GameState`, `DataRepo` y `EventLog` es una biblioteca de `static func` que recibe `st` y `repo`.
- **Errores esperados** (acción ilegal, fase incorrecta) devuelven `{"ok": false, "err": código}`, **no** mutan y **no** se registran. `push_error` sólo ante una invariante interna rota (bug).
- **Ceguera (T8):** `react/` sólo recibe eventos públicos (§3.6). Nunca lee `st.ded`.

### 3.2 Tiempo y fases (`core/util/timekey.gd`, `core/sim/clock.gd`)

- Días: `0` = P (lun 26-mar, noche); `1..10` = mar 27-mar … jue 5-abr; `11` = E (oct. 1903). Fechas y día de semana salen de `schedule.json`.
- Franjas: `dawn`, `M`, `T`, `N`, `night` (22 h). **TimeKey** `tk = día*10 + ORD`, `ORD = {dawn:0, M:1, T:2, N:3, night:4}`. Texto: `"4.dawn"`, `"7.N"`, `"P.N"` (= 3).
- **Índice de franja jugable** (máscaras de bits, 29 posiciones): `P.N, 1.M, 1.T, 1.N, …, 5.N, 6.T, 7.M, …, 9.N, 10.M, 10.T, 10.N` → `TimeKey.idx(day, slot)` (−1 si no existe). Bit `i` = franja `i`.

| phase | qué es | acciones (además de las libres*) | sale con |
|---|---|---|---|
| `prologue` | P, noche; tutorial (GDD§3.2, T24) | las del paso actual de `Tutorial` | `sleep` (con el tutorial completo) |
| `desk` | escritorio de la franja `slot`; `outing_done` dice si ya salió | `pass_clean` (si quedan), `compose_*`, `go` (si `!outing_done` y abierto), `end_slot` | `go`, `end_slot` |
| `visit` | en un lugar; escena `S.<L>.<d>.<s>` | `slip`, `order_copy`, `ask`, `assert`, `present`, `pay`, `task`, `leave` | `leave` |
| `scene` | escena fija en L1 (M6 al amanecer del 5; M7 a las 22 h del 7) | `leave` | `leave` |
| `night` | 22 h, tras la franja N | `report_submit` (días 2, 5, 8; obligatorio antes de dormir; vale «Sin novedad»), `sleep` | `sleep` |
| `confront` | día 10, 9:30, tienda de Crane | `confront` | fin de la confrontación |
| `final_report` | día 10, antes de las 12 h | `pass_clean` (lote 1), `report_submit` final | `report_submit` |
| `parklane` | día 10, 18 h | `leave` | `leave` |
| `night_choice` | día 10, noche | `night_choice` | `night_choice` |
| `epilogue` | oct. 1903 | `publish_errata`, `leave` | `leave` → `done` |

\* Libres (toda fase salvo `done`): `clip_*`, `link`, `unlink`, `folio_open`, `entry_*`, `practice`. Recortar exige que la fuente sea accesible ahora (§5.1).

- `end_slot`: con `!outing_done` equivale a «quedarse en casa». Envía telegramas y cartas pendientes. Avanza a la franja siguiente del día o a `night`. Día 6: sólo `T`.
- `sleep`: `Director.on_time(night)` → `dawn(d+1)` (resuelve colas, entrega la bandeja y la columna) → `desk(M)` (día 6: `desk(T)`), o `scene` (M6, día 5), o `confront` (día 10).
- **Pasadas:** `schedule.passes` (1 por franja; `9.N`: 2; `10.M` = `final_report`: 1 con lote 1; prólogo: 0, sólo práctica guiada de C1). Se usan antes o después de salir, dentro de la misma franja. `st.clock.passes_used` vuelve a 0 en `end_slot`.
- **Anuncios:** `compose_ad` sólo en `desk` con `slot ∈ {M, T}` (la oficina cierra a las 18 h), uno por día; se publica en el siguiente día con *Times* (sáb → lun). El del prólogo sale el día 1. El evento `ad` se emite **al amanecer del día de publicación** (GDD§7.5: la latencia cuenta desde la publicación).

### 3.3 GameState (`core/sim/game_state.gd`, W2-SIM)

```gdscript
extends RefCounted
var seed: int
var clock := {}    # W2-SIM    {day, slot, phase, outing_done, passes_used, ads_by_day:{}, d10:{}}
var world := {}    # W2-SIM    {visit, visits:[], plates:{}, docs:{}, tray:[], copies:{}, closures:[], silhouettes:{}, diary:[],
                   #            questions:{}, slips:{}, seat, mem_clips:{}, outbox:[], tutorial:{}, eggs:{}, coins_d}
var ded := {}      # W2-DED    {clips:{}, pairs:{}, folios:{}, entries:{}, index:{}, sealed:{}, practice:[], passes:[]}
var react := {}    # W2-REACT  {queue:[], delivered:[], holmes:{}, moran:{}, strong_days:{}, channels_seen:{}, inactivity:{}}
var scenes := {}   # W2-SCENES {dialogue:{}, confront:{}, mycroft:{}, reports:{}, final:{}, ending:{}}
var flags := {}    # registro §3.9 (un escritor por flag)
var events := []   # eventos públicos numerados (append-only; W2-SIM)
var seq := {}      # contadores de ids: clip, pair, folio, entry, inst, ev
var notes := []            # TRANSITORIO: avisos para la UI (fuera de canon())
var pending_events := []   # TRANSITORIO: eventos encolados por módulos durante apply
func canon() -> Dictionary                              # todo salvo notes/pending_events; claves ordenadas
func next_id(kind: String, prefix: String, width: int) -> String   # ("clip","RC",4) → "RC0001"
func note(kind: String, payload := {}) -> void
func push_event(ev: Dictionary) -> void                 # módulo → evento público (GameSim lo numera y despacha)
```

Cada sub-diccionario lo inicializa su dueño con `init_state(st, repo)` y sólo él lo escribe; los demás leen por funciones del dueño.

### 3.4 GameSim (`core/sim/game_sim.gd`, W2-SIM)

```gdscript
extends RefCounted
signal changed(kind: String, payload: Dictionary)
# kinds: clock tray clip pair folio entry pass index diary visit scene line report confront flag egg ending
# (NUNCA "reaction": no existe registro de reacciones)
var repo        # DataRepo
var st          # GameState
func _init(p_repo, p_seed: int) -> void                 # init_state de todos los módulos; phase = prologue
static func replay(p_repo, p_seed: int, actions: Array) # -> GameSim; aplica en orden; push_error si alguna da ok:false (save corrupto)
func apply(a: Dictionary) -> Dictionary
#   1 Actions.normalize + shape_error   2 fase permitida   3 Tutorial.allowed   4 PlayerActions.dispatch
#   5 numerar st.pending_events → st.events; por cada uno: Diary.on_event, Director.on_public_event
#   6 por cada tk cruzado (Clock.crossed_tks): Director.on_time(tk)   7 log; emitir changed por cada st.notes; vaciar notes
func can(a: Dictionary) -> Dictionary                   # {ok, err} sin mutar (dry-run sobre copia de canon)
func actions_log() -> Array                             # acciones aceptadas, normalizadas
func canon() -> Dictionary
func state_hash() -> String                             # md5(J.stringify_canon(canon()))
# azúcar 1:1 sobre apply (nombre = tipo; args en el orden de §3.5):
func clip_text(src: Dictionary, from: int, length: int) -> Dictionary
func clip_plate(plate: String, hits: Array, touched: Array, area_frac: float) -> Dictionary
func clip_measure(src: Dictionary) -> Dictionary
func link(a: String, b: String, note := "") -> Dictionary
func folio_open(clip: String) -> Dictionary
func entry_new(folio: String, template: String) -> Dictionary
func entry_set(entry: String, line: int, field: String, value: String) -> Dictionary
func entry_support_add(entry: String, line: int, item: String) -> Dictionary
func pass_clean(entries: Array) -> Dictionary
func go(place: String, area := "", seat := 0) -> Dictionary
func slip(doc: String) -> Dictionary
func ask(char_id: String, topic: String) -> Dictionary
func assert_claim(char_id: String, assertion: String) -> Dictionary    # acción "assert"
func present(char_id: String, kind: String, id: String) -> Dictionary
func leave() -> Dictionary
func end_slot() -> Dictionary
func sleep() -> Dictionary
func compose_ad(form: String, fields: Dictionary) -> Dictionary
func report_submit(mode: String, items: Array) -> Dictionary
func confront(step: int, kind := "", id := "") -> Dictionary           # kind "" = callar
# consultas q_*: §3.7
```

### 3.5 Acciones (completa; **C** = comprometida: `Game.act` la escribe a disco antes de devolver el resultado)

| t | args | C | evento | handler | resultado / errores |
|---|---|---|---|---|---|
| `clip_text` | `src:{kind,ref,part?,block?}`, `from:int`, `len:int` | no | — | Clipper.act_clip_text | `{clip}` · `vacio`, `cruza_oracion`, `mas_de_40`, `inaccesible`, `memoria_agotada` |
| `clip_plate` | `plate`, `hits:[{node,cover:float,tight:bool}]`, `touched:[node]`, `area_frac:float` | no | — | Clipper.act_clip_plate | `{clip}` · `rect_grande`, `demasiados_nodos`, `inaccesible` |
| `clip_measure` | `src:{kind:"doc"|"scene",ref}` | no | — | Clipper.act_clip_measure | `{clip}` (texto «Mide … por … milímetros.») |
| `link` | `a`, `b`, `note` | no | — | Clipper.act_link | `{pair}` · `anidado` |
| `unlink` | `pair` | no | — | Clipper.act_unlink | `{}` |
| `folio_open` | `clip` | no | — | PlayerActions.act_folio_open (único llamador de `Ledger.create_folio`, T14) | `{folio}` |
| `entry_new` | `folio` (`"varios"` o id), `template` (`T1`…`T9`) | no | — | Ledger | `{entry}` |
| `entry_set` | `entry`, `line:int`, `field`, `value` (`""` borra) | no | — | Ledger | `{}` · `no_indexado`, `fuera_de_lista`, `en_tinta` |
| `entry_support_add` / `_remove` | `entry`, `line:int`, `item` (recorte o par) | no | — | Ledger | `{}` · `en_tinta` |
| `entry_delete` | `entry` (sólo lápiz) | no | — | Ledger | `{}` |
| `practice` | `entry` (C1, de a uno) | no | — | Validator.act_practice | `{inked, msg}` |
| `pass_clean` | `entries:[id]` (exactamente `lot_size`) | sí | — (privado, D6) | Validator.act_pass_clean | `{inked, msg, sealed:[cid]}` · formal → `ok:false, err:"formal", formal:[{entry,code}]` (no gasta) · `sin_pasada`, `lote` |
| `go` | `place`, `area?`, `seat?:int` (L2: obligatorio) | sí | `go` | Clock.act_go | `{visit, plate}` · `cerrado`, `ya_salio` |
| `slip` | `doc` | sí | `slip` | WorldModel.act_slip | `{view}` · `sin_papeletas` (3/visita), `no_esta` |
| `order_copy` | `doc` (L6) | sí | `order_copy` | WorldModel.act_order_copy | `{arrives_tk}` |
| `ask` | `char`, `topic` (entidad del índice) | sí | `say` | Dialogue.act_ask | `{line}` · `sin_preguntas`, `no_indexado` |
| `assert` | `char`, `assertion` (lists.assertions) | sí | `say` | Dialogue.act_assert | `{line}` |
| `present` | `char`, `item:{kind:"clip"|"entry", id}` | sí | `show` | Dialogue.act_present | `{line, outcome}` |
| `pay` | `char`, `amount_d:int` | sí | `pay` | Dialogue.act_pay | `{line}` |
| `task` | `char`, `task` (`seguir_chico_pell`, `seguir_parker`) | sí | `task` | Dialogue.act_task | `{line}` |
| `leave` | — | sí | — | Clock.act_leave | `{phase}` |
| `end_slot` | — | sí | `telegram`/`letter` pendientes | Clock.act_end_slot | `{clock}` · `informe_pendiente` |
| `compose_ad` | `form`, `fields:{slot→valor}` | sí | `ad` (al publicarse) | Composers.act_compose_ad | `{ad, text, pub_day}` · `oficina_cerrada`, `uno_por_dia`, `forma` |
| `compose_telegram` / `compose_letter` | `to`, `parts:[...]` | sí | `telegram`/`letter` (al enviarse) | Composers | `{id, text}` |
| `report_submit` | `mode:"items"|"nada"|"quemar"|"errata"`, `items:[{kind,id}]` (0–3) | sí | `report` | Composers.act_report_submit | `{report}` · `errata_no_ofrecida`, `quemar_solo_final` |
| `sleep` | — | sí | — | Clock.act_sleep | `{clock, arrivals:int}` · `informe_pendiente`, `tutorial` |
| `confront` | `step:int`, `item:{kind,id}` o `{}` (callar) | sí | — (en persona) | Confrontation.act_confront | `{hit:bool, line, errors, done}` |
| `night_choice` | `where:"baker_street"|"casa"` | sí | — | Clock.act_night_choice | `{}` |
| `publish_errata` | `yes:bool` | sí | — | Clock.act_publish_errata | `{}` |

`src` de `clip_text`: `{"kind":"doc","ref":<vista>,"part":<página>,"block":<i>}` (vista = ejemplar `D05@BM` o instancia `R.HA1.3`); `{"kind":"line","ref":<uid de línea dicha>}`; `{"kind":"diary","ref":<id de línea>}`; `{"kind":"node","ref":"<lámina>/<nodo>"}` (texto de examen = recorte ajustado de ese nodo; da accesibilidad, T29).
`Actions.normalize` castea enteros (el JSON los trae como float), ordena claves y descarta claves desconocidas.

### 3.6 Eventos públicos (lo único que ve `react/`)

Comunes: `seq:int, tk:int, day:int, slot, type, act:"act.<seq>"`. `act` es además una **entidad runtime** (`kind: act_ref`, etiqueta legible «asiento 214, mar. 27») que aparece en la línea del diario y en toda reacción que cite ese acto: así ancla y diario quedan enlazados por claves (C6).

| type | se emite en | campos | lo ve |
|---|---|---|---|
| `go` | `go` | `place, area, streets:[...], hour:"10:00"` | K-S (día ≥3), K-H (L3 interior), Parker (L3/L8 → M10), hombre de M11 |
| `slip` | `slip` | `seat:int, doc, title, hour, topic` (lists.slip_topics) | K-BM |
| `say` | `ask`/`assert` | `char, kind:"ask"|"assert", topic, assertion?, bait_topic?, canary?, phrase, ents:[...]` | K-W (watson), K-H (hudson), con filtros §5.4 |
| `show` | `present` | `char, item:{kind, doc_ids, ents, origins, src_types, entry_values?}` (sólo lo visible) | K-W, K-H, inmediatas de escena |
| `pay` / `task` | `pay`/`task` | `char, amount_d` / `char, task` | Wiggins (HB8, HB8b) |
| `ad` | amanecer de publicación | `ad, form, text, assertion?, bait_topic?, canary?, to_s:bool, says_alive:bool, pub_day` | K-T (Mycroft lee), Moran (columna, desde día 5) |
| `telegram` / `letter` | `end_slot` | `to, text` | ciego (respuestas fijas D27, D28) |
| `order_copy` | `order_copy` | `doc` | ciego |
| `report` | `report_submit` | `n:1..4, mode, items:[{kind, cats:[...], values?:{}, copies:[...], cls:[...]}]` | Moran |

No son públicos: recortes, pares, folios, asientos, pasadas, práctica, confrontación, elección nocturna.

### 3.7 Consultas (`q_*` en GameSim; sólo lectura; devuelven copias)

| consulta | devuelve |
|---|---|
| `q_clock()` | `{day, slot, phase, date_label, weekday, outing_done, passes_left, lot_size, report_due}` |
| `q_places()` | `[{id, area, name, open, reason, streets}]` (cerrado → persiana, no elegible; T26) |
| `q_tray(day := -1)` | `[{view, title, stamp:"Recibido: 30-mar, amanecer", how}]` |
| `q_accessible()` | `[{view, doc, title, holder, via}]` legible ahora |
| `q_view(view)` | `{view, title, src_line, paper, paper_mm, font, machine, pages:[[{doc, origin, copy, parsed}]]}`. Un número del Times con inserciones (§4.4) trae **un bloque por parte**, con `segs:[{from, to, doc}]` (`WorldModel._merge_inserts`): cada inserción va en una posición `Det.h32(seed, número, iid)` entre la unidad 3 y la penúltima de la columna (en noticias, entre la primera y «El tiempo»); `Clipper.seg_block` atribuye el recorte al documento runtime del tramo |
| `q_catalog(entity)` | `[{doc, label}]` ≤5, mezclado con ruido de época |
| `q_clips()` / `q_clip(id)` | `{id, text, ents:[{id,label}], caption, src_line, origin, chron_date, thumb?}` (**sin etiquetas ocultas**) |
| `q_index()` | `[{id, label, kind}]` ordenado |
| `q_pairs()` / `q_diary()` / `q_marginalia()` | listas visibles |
| `q_ledger()` | `{rules_title, rules_page, varios:[id], erratas:[id], folios:[{id, head_clip, entries:[id]}]}` (`erratas` = página «Erratas inocentes», §12.2) |
| `q_entry(id)` | `{id, template, ink:"lapiz"|"tinta", lines:[{fields:{}, support:[]}], formal:[codes]}` |
| `q_templates()` / `q_lists()` | T1–T9 y listas cerradas (iguales para todas las conclusiones) |
| `q_scene()` | `{id, place, chars:[{id, label, trait, can_ask}], lines:[{uid, who, parsed}], present_ok}` |
| `q_topics(char)` / `q_assertions()` | lo preguntable / afirmable ahora |
| `q_preview(action)` | frase exacta de Lisle o texto final (anuncio, telegrama, informe) |
| `q_visit_plate()` / `q_plate(id)` | `{id, place, area, day, slot, variant, nodes:[ids], chars:[{id,pose,trait}], silhouettes:[ids], frame}` |
| `q_report_status()` | `{due, n, offered_erratum}` |
| `q_slips_used()` (W4) | papeletas gastadas en la visita en curso (con o sin ejemplar servido) |
| `q_confront()` | `{step, statement, errors, done, patience:["paquete","sombrero"]}` |
| `q_ending()` / `q_epilogue()` / `q_blue_pencil()` | sólo después del informe final |
| extensiones (ola 2) | `q_act(id)` (entidad runtime `act.<n>`), `q_line(uid)` (línea dicha con `parsed`), `q_hub_plate()` (buhardilla ahora: siluetas, variante «registrada»), `q_tutorial()` `{step, taught, complete}`; `q_clock()` además trae `tk, slot_label, scene, coins_d, report_n, tutorial` y `q_places()` trae `area_name, free, can_go, needs_seat` |

### 3.8 Módulos y firmas (contrato; W1-ENG crea TODOS como stubs que compilan con estas firmas)

```gdscript
# core/util/j.gd
static func parse_file(path: String)                    # Variant o null; float entero (|x|<2^53) → int, recursivo
static func parse_str(s: String)
static func stringify_canon(v) -> String                # claves ordenadas, sin espacios; ints sin ".0"
static func write_atomic(path: String, text: String) -> bool   # path.tmp → (path → path.bak) → rename
# core/util/det.gd
static func h32(parts: Array) -> int                    # md5_text("|".join(parts)) → 8 hex → int
static func rand01(seed: int, parts: Array) -> float
static func pick(seed: int, parts: Array, arr: Array)
static func shuffle(seed: int, parts: Array, arr: Array) -> Array
# core/util/log.gd (logger estático, sin autoload)
static var level := 1                                   # 0 debug, 1 info, 2 warn, 3 error
static var captured: Array = []
static var capturing := false
static func d(tag: String, msg: String) -> void
static func i(tag: String, msg: String) -> void
static func w(tag: String, msg: String) -> void
static func e(tag: String, msg: String) -> void         # printerr; NO push_error
static func bug(tag: String, msg: String) -> void       # push_error: sólo invariante interna rota
# core/util/cond.gd
static func eval(cond, ctx: Dictionary) -> bool         # DSL §4.18; ctx = {st, repo, ev?, anchor?, char?}
# core/util/timekey.gd
static func tk(day: int, slot: String) -> int
static func parse(s: String) -> int                     # "4.dawn", "P.N"
static func label(tk: int) -> String
static func idx(day: int, slot: String) -> int          # 0..28 o -1
static func idx_count() -> int                          # 29
static func from_idx(i: int) -> Dictionary              # {day, slot}

# core/data/data_repo.gd (instancia; cacheada por root)
static func load_dir(root := "res://data")
var root: String
func errors() -> Array                                  # errores de carga/esquema (nunca push_error)
func doc(id: String) -> Dictionary
func docs() -> Dictionary
func copy(copy_id: String) -> Dictionary                # {copy, doc}
func parsed(doc_id: String, part_id: String) -> Dictionary
func entity(id: String) -> Dictionary
func entities() -> Dictionary
func lists() -> Dictionary
func template(id: String) -> Dictionary
func conclusion(id: String) -> Dictionary
func conclusions() -> Array                             # orden por id
func reaction(id: String) -> Dictionary
func reactions() -> Array
func schedule() -> Dictionary
func place(id: String) -> Dictionary
func places() -> Dictionary
func plate(id: String) -> Dictionary
func dialogue(char_id: String) -> Dictionary
func scene(id: String) -> Dictionary
func canon() -> Array
func endings() -> Dictionary
func eggs() -> Array
func catalog() -> Dictionary                            # entidad → [doc] + ruido
func text(key: String, vars := {}) -> String            # ui_text
func content_hash() -> String                           # md5 del canon de data/ (cabecera del guardado)
# core/data/schema.gd
static func check(dataset: String, value) -> Array      # ["ruta: mensaje"]; dataset ∈ nombres de §4.1
# core/text/markup.gd
static func fill(src: String, vars: Dictionary) -> String
static func parse(src: String) -> Dictionary            # ParsedText §4.3
static func lint(src: String) -> Array
# core/text/clip_rules.gd
static func snap(parsed: Dictionary, from: int, length: int) -> Dictionary   # {ok, err, from, to, text, words}
static func inherit(parsed: Dictionary, from: int, to: int) -> Dictionary    # {tramo, tags, ents, date, place}
static func max_legal_clips(parsed: Dictionary) -> Array                     # T4: [{from, to}]
# core/save/event_log.gd (instancia)
func _init(path: String) -> void
func write(header: Dictionary, actions: Array) -> bool  # JSONL canónico, escritura atómica
static func read(path: String) -> Dictionary            # {ok, header, actions, err}; última línea truncada → se descarta

# core/sim/actions.gd
const SPEC := {}                                        # t → {args:{nombre: TYPE_*}, commit: bool, phases: [...]}
static func normalize(a: Dictionary) -> Dictionary
static func shape_error(a: Dictionary) -> String
static func is_commit(t: String) -> bool
# core/sim/player_actions.gd
static func dispatch(st, repo, a: Dictionary) -> Dictionary
static func act_folio_open(st, repo, a: Dictionary) -> Dictionary
# core/sim/clock.gd
static func init_state(st, repo) -> void
static func place_open(repo, st, place: String, area: String, day: int, slot: String) -> Dictionary   # {open, reason}
static func passes_left(st, repo) -> int
static func crossed_tks(before: Dictionary, after: Dictionary) -> Array
static func act_go(st, repo, a) -> Dictionary
static func act_leave(st, repo, a) -> Dictionary
static func act_end_slot(st, repo, a) -> Dictionary
static func act_sleep(st, repo, a) -> Dictionary
static func act_night_choice(st, repo, a) -> Dictionary
static func act_publish_errata(st, repo, a) -> Dictionary
# core/sim/world_model.gd
static func init_state(st, repo) -> void
static func accessible(st, repo) -> Array
static func view_accessible(st, repo, view: String) -> bool
static func view(st, repo, view: String) -> Dictionary
static func start_visit(st, repo, place: String, area: String) -> Dictionary
static func snapshot(st, repo, place: String, area: String, variant: String) -> Dictionary
static func instantiate_doc(st, repo, tpl: Dictionary, vars: Dictionary, meta: Dictionary) -> String   # "R.HA1.3"
static func deliver(st, repo, view: String, how: String) -> void   # how: correo | en_mano | mostrador_crane | columna | noticias
static func act_slip(st, repo, a) -> Dictionary
static func act_order_copy(st, repo, a) -> Dictionary
# core/sim/diary.gd
static func on_event(st, repo, ev: Dictionary) -> void
static func on_arrival(st, repo, view: String) -> void
static func on_line(st, repo, line: Dictionary) -> void   # línea dicha; conserva el origen de su escena
# core/sim/tutorial.gd
static func init_state(st, repo) -> void
static func allowed(st, a: Dictionary) -> bool
static func after(st, repo, a: Dictionary, res: Dictionary) -> void
static func step(st) -> Dictionary                      # {id, instructor, line_id, verb}
static func verbs_taught(st) -> Array                   # T24

# core/deduction/clipper.gd
static func init_state(st, repo) -> void
static func act_clip_text(st, repo, a) -> Dictionary
static func act_clip_plate(st, repo, a) -> Dictionary
static func act_clip_measure(st, repo, a) -> Dictionary
static func act_link(st, repo, a) -> Dictionary
static func act_unlink(st, repo, a) -> Dictionary
static func get_clip(st, id: String) -> Dictionary      # interno, CON etiquetas (validator, confrontación)
static func visible(st, id: String) -> Dictionary       # lo que ve el jugador (diálogo T20b, informes, UI)
# core/deduction/index.gd
static func add_entities(st, repo, ents: Array) -> void
static func known(st, repo) -> Array
static func has(st, ent: String) -> bool
# core/deduction/ledger.gd
static func init_state(st, repo) -> void
static func create_folio(st, repo, head_clip: String) -> String   # SÓLO desde player_actions.gd (T14)
static func act_entry_new(st, repo, a) -> Dictionary
static func act_entry_set(st, repo, a) -> Dictionary
static func act_entry_support_add(st, repo, a) -> Dictionary
static func act_entry_support_remove(st, repo, a) -> Dictionary
static func act_entry_delete(st, repo, a) -> Dictionary
static func formal_check(st, repo, entry_id: String) -> Array     # [] o ["falta_segun","una_fuente","demasiado_papel"]
static func entry_clips(st, entry_id: String) -> Array            # recortes únicos (pares expandidos)
# core/deduction/validator.gd
static func values_match(repo, entry: Dictionary, cid: String, sealed: Dictionary) -> bool
static func which_conclusion(repo, entry: Dictionary, sealed: Dictionary) -> String
static func entry_ok(st, repo, entry_id: String) -> Dictionary    # {ok, cid, failed:[1..5]} (failed: sólo tests y lápiz azul)
static func lot_size(st, repo) -> int
static func entry_tags(st, entry_id: String) -> Array
static func act_pass_clean(st, repo, a) -> Dictionary
static func act_practice(st, repo, a) -> Dictionary

# core/react/reaction_db.gd
static func compile(repo) -> Dictionary                 # índices por tipo de evento y canal (cache en repo)
static func candidates(repo, ev_type: String) -> Array
# core/react/sensors.gd
static func observe(st, repo, ev: Dictionary) -> Array  # [{channel, sensor, to_holmes, to_mycroft, content}] ya filtrado (D10, Mary)
# core/react/latency.gd
static func due_tk(st, repo, rule: Dictionary, act_tk: int) -> int
static func voice_b_day(repo, act_day: int) -> int
# core/react/holmes_agent.gd
static func init_state(st, repo) -> void
static func observe(st, repo, obs: Dictionary, ev: Dictionary) -> Array   # instancias candidatas
# core/react/moran_agent.gd
static func init_state(st, repo) -> void
static func observe(st, repo, ev: Dictionary) -> Array
static func report_cats(st, repo, item: Dictionary) -> Array             # categorías visibles (§5.4)
static func has_credit(st) -> bool
# core/react/director.gd
static func init_state(st, repo) -> void
static func on_public_event(st, repo, ev: Dictionary) -> void
static func on_time(st, repo, tk: int) -> void
static func immediate(st, repo, ev: Dictionary) -> Array                  # reacciones en escena → [{line?, effects}]
static func debug_queue(st) -> Array                                      # sólo tests/devtools
# core/react/effects.gd
static func apply(st, repo, inst: Dictionary, soft: bool) -> void
static func instance_text(st, repo, inst: Dictionary) -> String

# core/graph/route_db.gd
static func routes(repo, cid: String) -> Array    # [{id, star, deps, from_idx, frags:[{ref, copy, kind, cls, place, area, mask}]}]
static func frag(repo, ref: String) -> Dictionary # {ref, kind, tags, ents, origin, cls, copies}
# core/graph/availability.gd
static func open_mask(repo, place: String, area: String) -> int
static func frag_mask(repo, frag: Dictionary) -> int
static func from_mask(idx: int) -> int            # bits ≥ idx
# core/graph/cut_model.gd
static func cuts_for(repo, rid: String, soft := false) -> Array   # [{target:{copy|access|place|char}, from_idx, to_idx}]
static func apply_cuts(masks: Dictionary, cuts: Array) -> Dictionary
# core/graph/invariant.gd
static func check(repo, cid: String, from_idx: int, cuts: Array, clipped := {}) -> Dictionary   # {ok, intact, star, reason}
static func runtime_guard(st, repo, extra_cuts: Array) -> Dictionary                         # D1: {ok, violated:[cid]}
static func t3(repo, opts := {}) -> Dictionary                                                # {ok, states, failures, ms}
# core/graph/feasibility.gd
static func plan(repo, from_idx: int, cuts: Array, need: Array) -> Dictionary                # {ok, plan:[{idx, place}], unmet}

# core/scenes/dialogue.gd
static func init_state(st, repo) -> void
static func respond(st, repo, char_id: String, visible: Dictionary) -> Dictionary   # capas §5.7; SÓLO propiedades visibles
static func preview(st, repo, a: Dictionary) -> String
static func topics(st, repo, char_id: String) -> Array
static func act_ask(st, repo, a) -> Dictionary
static func act_assert(st, repo, a) -> Dictionary
static func act_present(st, repo, a) -> Dictionary
static func act_pay(st, repo, a) -> Dictionary
static func act_task(st, repo, a) -> Dictionary
# core/scenes/confrontation.gd
static func init_state(st, repo) -> void
static func start(st, repo) -> void
static func act_confront(st, repo, a) -> Dictionary
static func status(st) -> Dictionary
# core/scenes/composers.gd
static func forms(repo) -> Array
static func preview_ad(st, repo, form: String, fields: Dictionary) -> Dictionary   # {ok, text, err}
static func act_compose_ad(st, repo, a) -> Dictionary
static func act_compose_telegram(st, repo, a) -> Dictionary
static func act_compose_letter(st, repo, a) -> Dictionary
static func act_report_submit(st, repo, a) -> Dictionary
# core/sim/endings.gd (W2-SCENES)
static func evaluate(st, repo) -> Dictionary            # {ending, rank, variants:[...], card}
static func blue_pencil(st, repo) -> Array              # [{entry|cid, note}]
```

**Extensiones compatibles (ola 2; §12.2).** Toda firma de arriba existe tal cual (verificado por el integrador); algunas
aceptan parámetros opcionales y varios módulos exponen funciones extra. Las firmas del contrato no cambian:
- `Markup.parse(src, ctx := {})` / `Markup.lint(src, ctx := {})`: `ctx.names` (superficie por defecto de `[[ent]]`), `ctx.abbrev` (= `lists.abbrev`), `ctx.act` (reemplaza `@act`), `ctx.allow_placeholders`, `ctx.entities` (lint de existencia); además `escape`, `empty_tags`, `sentences_of`, `words_of`, `count_words`, `is_word_char`, `sentence_index`, constantes `PREFIXES`, `FONT_SLOTS`. El lint informa además «artículo duplicado» (§12.2).
- `Schema.check(dataset, value, ctx := {}, col = null)`: `ctx.abbrev` y `col` (DataRepo recoge los campos con marcado para verificar entidades).
- `DataRepo`: `fresh(root)`, `clear_cache(root)`, `conclusions_meta()`, `plates()`, `scenes()`, `dialogues()`, `map()`, `fonts()`, `audio()`, `texts()`, `files()`, `markup_ctx()`, `parse_text(src, vars, act)`, `doc_tramo(doc, tid)` y `cache` (diccionario libre: `ReactionDB.compile`, `Availability`). `errors()` incluye además los cruces de contenido: entidades inexistentes en todo marcado y etiqueta, `q:` sin `src_en`, `src_type`/`slip_topic` fuera de `lists`, y **todo tramo del contrato §4.8 de un documento que exista** («el documento no tiene el tramo #x»).
- `WorldModel.start_visit(…, opts := {})`, `MoranAgent.observe(st, repo, ev, opts := {})`, `Validator.evaluate(st, repo, entry, opts)` (`exclude_origins` para HB12), `Ledger.ledger_view/entry_view`, `Clipper.inject` (sólo tests), `Director.debug_queue`. El detalle de cada extensión está en la cabecera de su archivo.

### 3.9 Registro de flags (`st.flags`; un escritor por flag)

| flag | tipo | escribe | significado |
|---|---|---|---|
| `watson_avisado` | bool | Effects (HB9, 1.ª) | primera entrega de `watson_privado`, avisada |
| `watson_expuesto` | bool | Effects (HB9, 2.ª) | bloquea F1; voz B calla salvo HB10 |
| `consulta_cerrada_hasta` | int día | Effects (HB4, 2.ª) | consulta de L4 cerrada (la visita del domingo no) |
| `hb4_veces` | int | HolmesAgent | conteo de HB4 |
| `hudson_cerrada` | bool | Effects (HB6) | no muestra recibos ni habla del alquiler |
| `forasteros_cerrada` | bool | Dialogue (HB12, 2.º error) | Sala de Forasteros cerrada; portería y D31 siguen |
| `errata_ofrecida` | `""`, `"mycroft"`, `"librero"` | Dialogue (HB12) / Confrontation | habilita `report_submit` modo `errata` |
| `wiggins_aliado` / `wiggins_quemado` | bool | Effects (HB8 / HB8b) | — |
| `canal_cerrado.K-H` (y K-W, K-T, K-BM, K-S) | bool | Effects (HB11) | sin reacciones **opcionales** nuevas en ese canal |
| `pell_despedido` | bool | Effects (M4) | informes a lista de correos «a nombre de H.» |
| `moran_credito` | bool | MoranAgent | algún informe 1–3 con dato verdadero comprobable |
| `moran_credito_perdido` | bool | MoranAgent (M9) | — |
| `holmes_entregado` | bool | MoranAgent | M12 o regreso/lugar/Camden informados: bloquea F1 |
| `informes_vacios` | int | MoranAgent | erosión (variante de M7) |
| `seguido_por_cochero` | bool | Effects (M11) | segunda silueta |
| `confront_estado` | `""`, `"completa"`, `"incompleta"` | Confrontation | variantes del epílogo |
| `noche_final` | `""`, `"baker_street"`, `"casa"` | Clock | HC09 |
| `publica_errata` | bool | Clock | epílogo |
| `informe_final` | `""`, `"items"`, `"nada"`, `"quemar"`, `"errata"` | Composers | finales |
| `vio_libros_park` | bool | Clipper (`on_clip_flag` del nodo `PARK.libros`) | V.C12: vio los libros caídos en Park Lane (§12.2 del GDD) |

Un flag nuevo se propone (fila completa) en la respuesta final del WP; no se inventa en silencio.

---
## 4. Datos (`game/data/`)

### 4.1 Archivos, forma y dueños

| dataset | ruta | forma / merge | dueño |
|---|---|---|---|
| fonts | `fonts.json` | objeto | W1-THEME |
| audio | `audio.json` | objeto | W1-AUDIO → W4-AUDIO |
| ui_text | `ui_text/<wp>.json` | `{"text":{clave:valor}}`; merge de claves (duplicada = error) | cada WP su archivo |
| lists | `lists.json` | objeto | W1-BIBLE |
| entities | `entities/<nombre>.json` | `{"entities":[...]}` concatenadas; id único global | `core.json` W1-BIBLE; `<wp>.json` cada WP de contenido |
| canon_bible | `canon_bible.json` | `{"facts":[...]}` | W1-BIBLE |
| docs | `docs/**/*.json` | **un documento por archivo**; nombre = id (`D05.json`, `D01/SCAN.json`, `D15/0330.json`) | WPs de contenido (§10) |
| catalog | `catalog/*.json` | `{"noise":[...]}` + campo `catalog` de cada doc | W3-CT-TIMES |
| schedule | `schedule.json` | objeto | W2-STRUCT |
| conclusions | `conclusions.json` | objeto | W2-STRUCT |
| reactions | `reactions/{columna,mycroft,holmes,moran,respuestas}.json` | `{"reactions":[...]}` concatenadas | W2-STRUCT |
| endings | `endings.json` | objeto | W2-STRUCT |
| easter_eggs | `easter_eggs.json` | `{"eggs":[...]}` | W2-STRUCT |
| scenes | `scenes/<id>.json` | una escena por archivo | W3-CT-DLG-A / W3-CT-DLG-B |
| dialogue | `dialogue/<char>.json` | un personaje por archivo | W3-CT-DLG-A / W3-CT-DLG-B |
| places | `places/L1.json` … `L8.json` | un lugar por archivo | W2-PLACES-A/B/C |
| plates | `plates/<id>.json` | una lámina fija por archivo (prólogo, M7, Reichenbach, Park Lane) | W2-PLACES-A/B/C |
| map | `map.json` | objeto | W3-SHELL |

### 4.2 Lectura

- Sólo `DataRepo` lee `data/` (excepción: `fonts.json`, `audio.json`, §2.1). Nadie más usa `FileAccess` sobre `data/`.
- `J.parse_file`: todo float entero pasa a int. Código que divide números de datos usa `float(x)`.
- Texto en UTF-8 NFC. **Glifos prohibidos** (no existen en alguna fuente o el GDD los veda): `† ‡ ⅓ ℔`. Lint T21 verifica cobertura con `has_char` de la fuente de cada ranura.
- Tipografía: comillas «» (primer nivel) y “” (segundo); raya — en diálogos e incisos; dinero «2s. 6d.»; fechas «27 de marzo de 1894»; versalitas sólo con `<sc>`.
- Abreviaturas que **no** cortan oración: lista `lists.abbrev` + toda inicial de una letra mayúscula seguida de punto. Punto literal que no corta: `\.`.

### 4.3 Marcado de texto (todos los campos de texto de `data/`) y parser (`core/text/markup.gd`)

```
texto        := ( plano | tramo | mencion | estilo | placeholder | "\n" | escape )*
tramo        := "{{" ( "#" id " " )? tag (" " tag)* "|" contenido "}}"     # no anidable; contenido = plano|mencion|estilo
mencion      := "[[" entidad ( "|" superficie )? "]]"                       # superficie por defecto = entities[id].name
estilo       := "<i>" … "</i>" | "<b>" … "</b>" | "<sc>" … "</sc>" | "<del>" … "</del>"
              | "<f=" ranura ">" … "</f>"        # imprenta | maquina | manuscrito | ui
              | "<ink=" tinta ">" … "</ink>"     # negra | lapiz | azul | roja | tenue
              | "<rasante>" … "</rasante>"       # surcos (D29b): sólo visibles con luz rasante; seleccionables
placeholder  := "${" nombre "}"                  # se resuelve con Markup.fill ANTES de parse (sólo plantillas runtime)
escape       := "\{" | "\}" | "\[" | "\]" | "\<" | "\\" | "\."
tag          := prefijo ":" valor
```

| prefijo | significado | visible | se hereda al recorte |
|---|---|---|---|
| `a:` | afirmación (grupo de conclusión, `acto_*`, `ancla_*`, `refuta_*`) | no | sí (del tramo ganador) |
| `e:` | entidad implícita del tramo (p. ej. `fusil_de_aire` en «Of air-guns») | sí (epígrafe) | sí (del tramo ganador) |
| `c:` | categoría de contenido para informes (lo que el texto DICE): `holmes_vive`, `regreso_jueves`, `baker_street`, `camden`, `watson_privado`, `paradero_extranjero`, `verdadero`, `moran_autor` | no (la lee Moran) | sí |
| `f:` | marca: `refutado`, `secreto_camden`, `afirma_que_vive`, `privado_kw`, `ruido` | no | sí |
| `d:` | fecha de la crónica `AAAA-MM-DD` (filtros del cuaderno) | sí (filtro) | sí |
| `p:` | lugar de la crónica (entidad) | sí (filtro) | sí |
| `q:` | id de cita de Doyle en `src_en` del doc (T7) | no | no |
| `h:` | hecho de `canon_bible` (T7, `fecha_conocible`) | no | no |
| `w:` | dato ⚠ a verificar (T7: ninguna ruta/refutación lo usa) | no | no |
| `x:` | huevo de pascua (T13) | no | sí |

**Reglas de autoría (lint = error):** tramo dentro de una sola oración y ≤40 palabras; `#id` obligatorio si una ruta o refutación lo referencia (§4.8); prefijo desconocido; `{{`, `[[` o estilo sin cerrar; tramo anidado; entidad inexistente; glifo prohibido; `${x}` sin resolver en documentos estáticos.

**ParsedText** (salida de `Markup.parse`, índices = índices de `String` de GDScript sobre `plain`, fin exclusivo):

```json
{
  "plain": "texto sin marcas",
  "mentions": [{"from": 0, "to": 5, "ent": "watson"}],
  "tramos": [{"id": "corniche", "from": 10, "to": 80, "tags": {"a": ["cornisa_existe"], "e": [], "c": [], "f": [], "d": [], "p": [], "q": [], "h": [], "w": [], "x": []}}],
  "styles": [{"from": 0, "to": 5, "kind": "i|b|sc|del|font|ink|rasante", "val": ""}],
  "sentences": [[0, 120]],
  "words": [[0, 5], [6, 11]],
  "errors": []
}
```

- **Palabra:** corrida máxima de caracteres `c` con `c.to_upper() != c.to_lower()` o dígito, más `'` `’` `-` internos. La puntuación pegada no es palabra.
- **Oración:** termina tras `.` `?` `!` `…` (más comillas/paréntesis de cierre pegados) seguido de espacio, `\n` o fin, salvo abreviatura/inicial/`\.`; `\n` siempre corta.
- El *builder* del lector (§6.4) produce exactamente `plain` (test: `rtl.get_parsed_text() == parsed.plain`).

### 4.4 `docs/**/*.json` (un documento por archivo)

```json
{
  "id": "D05",
  "entity": "journal_de_geneve",
  "title": "Journal de Genève, miércoles 6 de mayo de 1891",
  "src_type": "prensa_extranjera",
  "class": "I",
  "origin": "D05",
  "date": "1891-05-06",
  "chron_date": "1891-05-04",
  "knowable": "1891-05-06",
  "font": "imprenta",
  "paper": "diario_hueso",
  "paper_mm": [300, 420],
  "machine": null,
  "clip_entities": [],
  "measure": null,
  "clip_mode": "normal",
  "slip_topic": "holmes_prensa_1891",
  "visible_cats": [],
  "catalog": {"label": "Journal de Genève, mayo de 1891", "entities": ["journal_de_geneve", "reichenbach", "meiringen"]},
  "copies": [
    {"id": "D05@BM", "holder": "BM", "area": "periodicos", "class": "I", "via": "slip", "from": "1.M", "to": "9.N"}
  ],
  "parts": [
    {"id": "p1", "text": "MEIRINGEN, 5 de mayo. — {{#viajeros d:1891-05-04 p:reichenbach|Dos viajeros ingleses subieron ayer por el sendero de la [[reichenbach|cascada del Reichenbach]]; uno solo volvió a la posada.}} {{#aucun_corps a:refuta_rio_cuerpo e:cuerpo|Los [[guias|guías]] no hallaron ningún cuerpo: «on n'a retrouvé aucun corps».}} {{#baton a:refuta_baston|El [[baston|bastón]] herrado seguía apoyado contra [[roca|la roca]], «le bâton ferré appuyé contre le rocher».}} {{#corniche a:cornisa_existe a:refuta_reuter e:reichenbach|Más arriba hay [[cornisa|una cornisa]] que no se ve desde [[sendero|el sendero]], «une corniche que l'on ne voit pas du sentier»; sólo un [[nidero|cazador de nidos]] temerario subió alguna vez.}} {{#marque a:raspadura_registrada e:raspadura|En [[pared|la pared]], «une marque récente».}} {{#pastor|Un [[pastor|pastor]] oyó caer piedras «à la tombée de la nuit».}}\n<f=manuscrito><ink=lapiz>marque = marca, raspadura</ink></f>"}
  ],
  "src_en": {},
  "words": 110
}
```

| campo | obligatorio | notas |
|---|---|---|
| `id` | sí | corpus `D01.<CÓDIGO>` (p. ej. `D01.SCAN`); notas de los tomos `D01N`; *Times* `D15.<MMDD>`; FINA impreso `D03` (sus ejemplares incluyen el del tomo) |
| `entity` | sí | entidad que representa al documento; **todo recorte la lleva** (permite enlazar por claves «FINA», «Journal») |
| `title`, `src_type`, `date` | sí | componen la línea de fuente (`lists.src_types[src_type]` = «prensa extranjera», «registro», «papel privado», «dicho por …») |
| `class` | sí | I / P / C por defecto; cada ejemplar puede redefinirla |
| `origin` | no | por defecto `id`. Todo lo impreso en un mismo número (noticias, columna, inserciones runtime) comparte origen `D15.<MMDD>` |
| `font`, `paper`, `paper_mm` | sí / sí / no | ranura y estilo de papel (§6.3); `paper_mm` = [ancho, alto] para la regla |
| `machine` | no | `"remington_cotter"`: FX de la máquina + entidad visible `remington_s_alzada` en todo recorte |
| `clip_entities` | no | entidades agregadas a todo recorte del doc |
| `measure` | no | `{"entity":"papel_corto","tags":["me_vigila_de_cerca"]}`: la regla genera un recorte de medida (C7.R1) |
| `clip_mode` | no | `"normal"` o `"memoria"` (testamentos de L6: máx. 3 recortes por visita) |
| `slip_topic` | si está en BM | `lists.slip_topics` (HA1, HB14) |
| `visible_cats` | no | categorías por procedencia visible (`watson_privado` en D01N, D29) |
| `catalog` | si está en BM | entradas del catálogo general (≥2 entidades puente obtenibles antes de necesitarlo, GDD§15.3) |
| `copies[]` | sí | `holder`: `L1` (posesión: escritorio/bandeja) · `tomo` (dentro de D01 en L1) · `Crane` (tienda) · `BM` · `L3`…`L8`; `area` opcional; `via`: `desk` · `tome` · `shelf` · `slip` · `counter` · `place`; `from`/`to`: ventana `"d.S"` (además del horario del lugar) |
| `parts[]` | sí | páginas de 300–600 palabras (tomos: una historia por doc); `parts[].when` opcional (DSL §4.18: p. ej. la entrada del jueves de D33 sólo tras HC07) |
| `inserts` | no (sí en `D15.*`) | **a nivel de documento**: `{"columna": "<id de parte>", "noticias": "<id de parte>"}` = dónde WorldModel agrega los bloques runtime (avisos de Lisle, columnas «—S.», noticias). Sin `inserts`, van a la última parte. Claves sólo `columna`/`noticias`; el valor debe ser una parte existente (Schema). Por compatibilidad también se acepta dentro de una parte |
| `src_en` | si hay `q:` | `{"<id q>": "texto inglés exacto de Gutenberg"}` (T7 lo busca en `tests/fixtures/canon/`) |
| `plate` | no | `"RB.foto"`: el documento se ve como lámina 3D (D07, frontispicio de D10) |
| `words` | sí | presupuesto declarado (GDD§6); `devtools/data_report.gd` compara |

Ejemplo con cita de Doyle (fragmento de D03; el texto final lo escribe W3-CT-REICH):

```json
{
  "id": "D03", "entity": "fina", "title": "«El problema final», The Strand Magazine, diciembre de 1893",
  "src_type": "cronica", "class": "I", "date": "1893-12-01", "chron_date": "1891-05-04", "font": "imprenta", "paper": "strand",
  "slip_topic": "holmes_cronicas",
  "catalog": {"label": "The Strand Magazine, vol. VI", "entities": ["fina", "strand", "reichenbach"]},
  "copies": [
    {"id": "D03@tomo", "holder": "tomo", "class": "P", "via": "tome", "from": "P.N", "to": "10.N"},
    {"id": "D03@Crane", "holder": "Crane", "class": "I", "via": "shelf", "from": "1.M", "to": "10.M"},
    {"id": "D03@BM", "holder": "BM", "class": "I", "via": "slip", "from": "1.M", "to": "9.N"}
  ],
  "parts": [{"id": "p7", "text": "{{#sheer a:fina_impreso_sin_raspadura a:fina_a_pique q:sheer e:reichenbach|Era un [[sendero|sendero]] de tres pies, con una [[pared|pared]] [[a_pique|a pique]] a un lado y un precipicio a pique al otro.}}"}],
  "src_en": {"sheer": "three-foot path, with sheer wall on one side and sheer drop on the other"},
  "words": 2300
}
```

Documentos generados en runtime (cartas, columna, notas de Pell, telegramas de respuesta) **no** viven en `docs/`: su plantilla está en la reacción (`doc` + `rastro`, §4.9) y `WorldModel.instantiate_doc` crea la instancia `R.<rid>.<n>` en `st.world.docs`.

### 4.5 `entities/*.json`

```json
{"entities": [
  {"id": "watson", "kind": "persona", "name": "el doctor Watson", "index": "Watson, John H., doctor", "noun": "médico", "aliases": ["Watson", "el doctor"]},
  {"id": "cornisa", "kind": "concepto", "name": "la cornisa", "index": "cornisa", "noun": "cornisa"},
  {"id": "journal_de_geneve", "kind": "documento", "name": "el Journal de Genève", "index": "Journal de Genève (6-may-1891)", "noun": "diario", "doc": "D05"},
  {"id": "perro_perdido", "kind": "objeto", "name": "un perro perdido", "index": "perro perdido", "noun": "perro", "_ruido": true}
]}
```

- `kind ∈ {persona, lugar, documento, objeto, fecha, concepto, suceso}`; `act_ref` sólo en runtime (`act.<seq>`).
- `index`: etiqueta en el índice (orden alfabético por este campo). `noun`: sustantivo para epígrafes automáticos de láminas («mesa, cesto, mozo con gorra»).
- Ids ASCII minúscula `snake_case`, sin prefijo. Personas sin nombre conocido: `librero`, `chico_del_agente`, `hombre_de_la_canastilla`; el nombre aparece en `index` sólo cuando el personaje se presenta (Dialogue lo agrega al índice).
- Antes de crear una entidad: buscar en `entities/*.json` (grep). Duplicado = error de esquema.

### 4.6 `lists.json` (listas cerradas iguales para todas las conclusiones; W1-BIBLE)

```json
{
  "verbos": ["ceder", "vender", "comprar", "matar", "disparar", "ocultar", "suprimir", "vigilar", "pagar", "escribir", "dictar", "volver", "preparar", "separarse_de", "seguir", "hallar"],
  "relaciones": ["lee_a", "paga_a", "vigila_a", "obedece_a", "usa_a", "busca_a"],
  "medios": [
    {"id": "sala_lectura", "label": "la Sala de Lectura", "ch": "kbm", "entities": ["hombre_de_la_canastilla"]},
    {"id": "consultorio", "label": "el consultorio de Watson", "ch": "kw", "entities": ["watson"]},
    {"id": "221b", "label": "221B", "ch": "kh", "entities": ["mrs_hudson"]},
    {"id": "la_calle", "label": "la calle", "ch": "ks", "entities": ["muchacho_de_gorra"]},
    {"id": "columna", "label": "la columna del Times", "ch": "kt", "entities": ["times"]}
  ],
  "estados": ["vivo", "muerto", "desconocido"],
  "templates": {
    "T5": {"name": "Hecho", "lines": [
      {"fields": [{"id": "persona", "label": "Persona: ___", "accept": {"kinds": ["persona"]}}, {"id": "hizo", "label": "Hizo: ___", "accept": {"list": "verbos"}}, {"id": "que", "label": "Qué o a quién: ___", "accept": {"kinds": ["persona", "objeto", "documento", "concepto", "lugar"]}}]},
      {"optional": true, "fields": [{"id": "a", "label": "A o contra: ___", "accept": {"kinds": ["persona", "lugar", "objeto"]}}]},
      {"optional": true, "fields": [{"id": "con", "label": "Con: ___", "accept": {"kinds": ["objeto", "concepto"]}}]},
      {"optional": true, "fields": [{"id": "donde", "label": "Dónde: ___", "accept": {"kinds": ["lugar", "concepto", "suceso"]}}]},
      {"optional": true, "fields": [{"id": "cuando", "label": "Cuándo: ___", "accept": {"kinds": ["fecha", "suceso", "concepto"]}}]}
    ]},
    "T6": {"name": "Relación", "lines": [
      {"fields": [{"id": "persona", "label": "Persona: ___", "accept": {"kinds": ["persona"]}}, {"id": "relacion", "label": "Relación: ___", "accept": {"list": "relaciones"}}, {"id": "a_quien", "label": "A quién: ___", "accept": {"kinds": ["persona"]}}, {"id": "por_medio", "label": "Por medio de: ___", "accept": {"list": "medios"}}]},
      {"optional": true, "fields": [{"id": "y_de", "label": "Y de: ___", "accept": {"list": "medios"}}]}
    ]}
  },
  "assertions": [
    {"id": "as.pared", "kind": "cebo", "topic": "pared", "requires": ["reichenbach", "pared"], "ad_text": "la pared era a pique", "phrase": "La pared era a pique, ¿no, ${addr}?", "about_holmes": true},
    {"id": "as.vive", "kind": "vive", "topic": "vive", "requires": ["holmes"], "ad_text": "Holmes vive", "phrase": "Holmes vive, ${addr}.", "says_alive": true},
    {"id": "cn.chelsea", "kind": "canario", "topic": "lisle_mudanza", "requires": [], "ad_text": "", "phrase": "Me mudo a Chelsea la semana que viene, ${addr}.", "channels": ["kh", "kw"]}
  ],
  "ad_forms": [
    {"id": "testigo", "text": "Se busca testigo de ${suceso}. Escribir a E. L., Holywell Street.", "slots": {"suceso": {"options": ["suceso_reichenbach", "suceso_park_lane", "suceso_vere_street"]}}},
    {"id": "a_proposito", "text": "A propósito de ${fuente}: ${afirmacion}. —E. L.", "slots": {"fuente": {"kinds": ["documento"]}, "afirmacion": {"assertions": ["cebo", "vive"]}}, "forbid_tags": ["secreto_camden"], "forbid_kinds_lugar_londres": true}
  ],
  "src_types": {"cronica": "crónica", "prensa_extranjera": "prensa extranjera", "prensa_londres": "prensa de Londres", "registro": "registro", "libro": "libro", "papel_privado": "papel privado", "carta_recibida": "carta recibida", "escena": "dicho en ${lugar}", "lugar": "lugar u objeto", "diario": "diario"},
  "slip_topics": {"holmes_cronicas": "holmes", "holmes_prensa_1891": "holmes", "holmes_monografia": "holmes", "sigerson": "holmes", "coronel": "silencio", "moran": "silencio", "otros": "silencio"},
  "topic_groups": {"roca": ["pared", "a_pique", "raspadura", "cornisa", "roca", "reichenbach", "fina"], "mary": ["mary_watson", "duelo", "crespon"], "221b": ["221b", "cuartos", "alquiler", "mycroft"]},
  "sensors": {
    "K-W": {"topics": ["roca", "mary"], "to_holmes_exclude": ["mary"]},
    "K-H": {"topics": ["221b"]},
    "K-S": {"fields": ["streets", "hour"]},
    "K-BM": {"fields": ["seat", "title", "hour"]},
    "K-T": {"fields": ["text"]},
    "strip_tags": ["secreto_camden"]
  },
  "abbrev": ["Mr.", "Mrs.", "Dr.", "St.", "Sr.", "Sra.", "Cnel.", "Col.", "vol.", "vols.", "cap.", "pág.", "n.º", "a.", "p.", "m.", "etc."],
  "diary": {
    "go": {"text": "${fecha}, ${franja}: [[@act|${lugar}]].", "tags": ["a:acto_ks"]},
    "go.L3": {"text": "${fecha}, ${franja}: [[@act|Baker Street]], visita al 221B.", "tags": ["a:acto_ks", "a:acto_kh"]},
    "slip": {"text": "${fecha}, ${franja}: Sala de Lectura, [[@act|asiento ${seat}]]. Pedí ${titulo}.", "tags": ["a:acto_kbm"]},
    "say.watson": {"text": "${fecha}, ${franja}: Kensington. Le dije al doctor: [[@act|«${frase}»]]", "tags": ["a:acto_kw"]},
    "ad": {"text": "${fecha}, amanecer: sale mi aviso en el Times: [[@act|«${texto}»]]", "tags": ["a:acto_kt"]},
    "arrival": {"text": "${fecha}, ${franja}: Recibido: ${que}.", "tags": []}
  },
  "report_cats": [
    {"cat": "holmes_vive", "entry_match": [{"tpl": "T7", "all": {"persona": ["holmes"], "estado": ["vivo"]}}], "clip_tags": ["c:holmes_vive"]},
    {"cat": "regreso_jueves", "entry_match": [{"tpl": "T8", "all": {"persona": ["holmes"], "dia": ["jueves", "jueves_5_abril"]}}, {"tpl": "T5", "all": {"persona": ["holmes"], "hizo": ["volver"]}}], "clip_tags": ["c:regreso_jueves"]},
    {"cat": "camden", "entry_match": [{"tpl": "*", "all": {"*": ["camden_house", "casa_vacia"]}}], "clip_tags": ["c:camden"]},
    {"cat": "watson_privado", "clip_doc_cats": ["watson_privado"]},
    {"cat": "original_p", "clip_copy_class": ["P"]},
    {"cat": "moran_autor", "entry_match": [{"tpl": "T4", "all": {"redacto": ["moran", "autor_heavy_game", "harris"]}}, {"tpl": "T5", "all": {"persona": ["moran", "autor_heavy_game", "harris"], "hizo": ["matar", "disparar"]}}, {"tpl": "T9", "all": {"persona": ["moran", "autor_heavy_game", "harris"]}}, {"tpl": "T3", "all": {"es": ["moran", "autor_heavy_game", "harris"]}}]},
    {"cat": "paradero_extranjero", "clip_tags": ["c:paradero_extranjero"], "entry_template_values": {"T8": {"lugar": ["montpellier", "grenoble", "paris"]}}},
    {"cat": "verdadero", "entry_conclusions": ["C2", "C3", "C4", "C5", "C14"], "entry_ink": true, "clip_tags": ["c:verdadero"]},
    {"cat": "falso_verificable", "entry_template_values": {"T8": {"lugar": ["@londres_falso"]}}}
  ]
}
```
W4 (`report_cats`): `entry_match: [{tpl: "T#"|"*", all: {campo|"*": [valores]}}]` = el asiento cae en la categoría si **lo que afirman sus campos visibles** casa con alguna regla (todas las claves de `all`; `"*"` = cualquier plantilla o cualquier campo), sin mirar si es correcto; `entry_ink: true` = la categoría (sólo `verdadero`, el crédito) exige el asiento en tinta.

Plantillas T1–T9 completas según GDD§8.4 (lint T6: el artículo va dentro del rótulo «Campo: ___»; ningún rótulo presupone un hecho).

### 4.7 `catalog/*.json`

```json
{"noise": [
  {"label": "Tratado de las abejas (1889)", "entities": ["abejas", "reichenbach"]},
  {"label": "Guía del Oberland bernés (1886)", "entities": ["meiringen", "oberland"]}
]}
```
`q_catalog(entity)` = hasta 5 resultados: docs cuyo `catalog.entities` contiene la entidad + ruido, mezclados por `Det.shuffle(seed, [entity])`. Sólo se pueden pedir por papeleta los docs con ejemplar `@BM`.

### 4.8 `conclusions.json` (W2-STRUCT) y contrato de fragmentos

```json
{
  "mandatory": ["C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10", "C11", "C12", "C13"],
  "lot_counts": ["C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10", "C11", "C12", "C13", "C14"],
  "alias_rules": [{"when_sealed": "C10a", "equiv": ["harris", "moran"]}],
  "conclusions": [
    {
      "id": "C2", "kind": "obligatoria", "template": "T2", "_resumen": "FINA impreso calla la raspadura",
      "answers": {"fuente": ["fina"], "calla": ["raspadura", "marca_en_la_roca"], "consta_en": ["galerada", "pruebas_americanas", "journal_de_geneve", "pruebas_de_watson", "notas_de_los_tomos"]},
      "constraints": [],
      "groups": [
        {"id": "sin_raspadura", "line": 0, "tags": ["fina_impreso_sin_raspadura"]},
        {"id": "registrada", "line": 1, "tags": ["raspadura_registrada"]}
      ],
      "tags_extra": [],
      "keys": {"entities": ["fina", "reichenbach", "roca", "pared", "raspadura"], "kinds": []},
      "validate": {"from": "P.N", "until": null},
      "routes": [
        {"id": "C2.R1", "star": false, "deps": "fija", "from": "P.N", "frags": [{"ref": "D02#clausula", "copy": "D02@L1"}, {"ref": "D03#sheer", "copy": "D03@tomo"}], "cut_by": ["M1"]},
        {"id": "C2.R2", "star": true, "deps": "fija", "from": "1.M", "frags": [{"ref": "D05#marque", "copy": "D05@BM"}, {"ref": "D03#sheer", "copy": "D03@Crane"}], "cut_by": []},
        {"id": "C2.R3", "star": true, "deps": "fija", "from": "1.M", "frags": [{"ref": "D04#clausula", "copy": "D04@Crane"}, {"ref": "D03#sheer", "copy": "D03@BM"}], "cut_by": []}
      ],
      "blue_pencil": {"missing": "Falta: lo que el impreso calla.", "wrong": "Dele: el impreso calla una marca, no una opinión."}
    },
    {
      "id": "C6", "kind": "obligatoria", "template": "T6",
      "answers": {"persona": ["holmes", "mycroft", "corresponsal_s"], "relacion": ["lee_a"], "a_quien": ["lisle"], "por_medio": {"list": "medios"}, "y_de": {"list": "medios"}},
      "constraints": [{"distinct": ["por_medio", "y_de"]}],
      "groups": [
        {"id": "acto_x", "line": 0, "tags": ["acto_${ch:por_medio}"]},
        {"id": "ancla_x", "line": 0, "tags": ["ancla_${ch:por_medio}"]},
        {"id": "acto_y", "line": 1, "tags": ["acto_${ch:y_de}"]},
        {"id": "ancla_y", "line": 1, "tags": ["ancla_${ch:y_de}"]}
      ],
      "keys": {"entities": [], "kinds": ["act_ref"]},
      "validate": {"from": "4.dawn", "until": null},
      "subroutes": {
        "K-S": {"star": true, "deps": "columna", "from": "3.M", "frags": [{"ref": "J:go"}, {"ref": "N:*.sil_wiggins"}]},
        "K-T": {"star": true, "deps": "columna", "from": "4.dawn", "frags": [{"ref": "AD:prologo", "copy": "D15.0327@L1"}, {"ref": "R:HC10.texto", "copy": "D15.0330@L1"}]},
        "K-BMx": {"star": true, "deps": "columna", "from": "8.T", "frags": [{"ref": "J:slip"}, {"ref": "S:HC06.b_kbm"}]},
        "K-BM": {"star": false, "deps": "garantizada", "from": "2.dawn", "frags": [{"ref": "J:slip"}, {"ref": "R:HA1.*"}], "cut_by": ["M1"]}
      },
      "routes": [
        {"id": "C6.R1", "star": true, "pair": ["K-S", "K-T"], "from": "4.dawn"},
        {"id": "C6.R2", "star": true, "pair": ["K-T", "K-BMx"], "from": "8.T"}
      ]
    },
    {
      "id": "C10", "kind": "obligatoria", "template": "T9",
      "answers": {"persona": ["moran", "autor_heavy_game", "@alias:harris"], "usa_a": ["lisle"], "como": ["cebo", "cabrito", "cabrito_atado"], "para": ["hallar"], "a_quien": ["holmes"]},
      "groups": [
        {"id": "identidad", "line": 0, "tags": ["harris_es_moran"]},
        {"id": "cebo", "line": 1, "tags": ["cebo"]},
        {"id": "busca", "line": 2, "tags": ["busca_a_holmes"]}
      ],
      "keys": {"entities": ["harris", "moran", "bigote", "cabrito", "donde"], "kinds": []},
      "subroutes": {
        "Ia": {"star": true, "from": "8.dawn", "frags": [{"ref": "N:PRO.harris", "copy": "PL.prologo"}, {"ref": "D16#moran", "copy": "D16@BM"}]},
        "Ib": {"star": true, "from": "7.night", "frags": [{"ref": "S:M7.inteligente"}, {"ref": "D10#adjetivos", "copy": "D10@Crane"}]},
        "Ca": {"star": true, "from": "5.dawn", "frags": [{"ref": "D10#cabrito_atado", "copy": "D10@BM"}, {"ref": "S:M6.donde"}]},
        "Cb": {"star": true, "from": "7.night", "frags": [{"ref": "D11#no_bala", "copy": "D11@BM"}, {"ref": "S:M7.donde_duerme"}]}
      },
      "routes": [
        {"id": "C10.R1", "star": true, "pair": ["Ia", "Ca"], "from": "8.dawn"},
        {"id": "C10.R2", "star": true, "pair": ["Ib", "Cb"], "from": "7.night"}
      ]
    }
  ]
}
```

- `answers[campo]`: lista de valores aceptados (entidades o ids de lista) · `{"list": nombre}` (cualquiera de la lista; para `medios` también valen sus `entities`) · `"@alias:x"` (vale sólo bajo `alias_rules`). Campos ausentes en `answers` = libres (no se validan; p. ej. el móvil de C11).
- `groups[].tags`: basta **una** etiqueta del grupo en algún recorte del «según» de esa línea. `${ch:campo}` = código de canal del medio elegido en ese campo.
- `tags_extra`: etiquetas que también cuentan como «de la conclusión» (condición 4) sin ser grupo.
- `keys`: entidades (o `kinds`) que enlazan el fundamento (condición 5).
- `validate.until`: `"10.M"` para C12 y C13 (sólo en el libro mayor, antes del informe final).
- `deps`: `fija` (documentos, lugares, escenas fijas) · `columna` · `garantizada` · `opcional` (T3 sólo usa las tres primeras).
- C1: ocho entradas `C1.01`…`C1.10` (`kind: "practica"`), una por par INC, grupos `inc_a`/`inc_b`, `practice_origins: "pasajes"` (dos pasajes distintos bastan).

**Sintaxis de `ref` de fragmento** (el contrato entre datos, motor y contenido):

| ref | qué | dónde se define |
|---|---|---|
| `D05#corniche` | tramo `#corniche` de un documento | `docs/` |
| `N:L8.guillotina` | nodo de un lugar; `N:PRO.harris` nodo de lámina fija; `N:*.sil_wiggins` silueta en cualquier lámina con día ≥3 | `places/`, `plates/` |
| `S:M7.donde_duerme` | línea de escena fija; `S:HC06.b_kbm` línea generada por canal | `scenes/` |
| `L:hudson.mycroft_paga` | línea de diálogo (respuesta) | `dialogue/` |
| `R:HC10.texto` | rastro de una reacción (`R:HA1.*` = cualquier plantilla) | `reactions/` |
| `J:go`, `J:slip`, `J:say.watson`, `J:go.L3`, `J:ad` | línea del diario (D36) de ese tipo de acto | `lists.diary` |
| `AD:prologo` | el aviso de testigos del prólogo, impreso en `D15.0327` | composers |
| `M:D46`, `M:HA1.carta` | recorte de medida con la regla | `measure` + `paper_mm` del doc (`M:D46`), del doc de la reacción (`M:HA1.carta`: la carta entregada) o de la escena (`M:<escena>.<x>`) |

**Contrato de fragmentos por ruta (GDD§10.4; los dueños de cada fuente DEBEN crear estos ids con estas etiquetas):**

| ruta | fragmentos (ref → ejemplar) |
|---|---|
| C1 | `D43#hombro`/`D44#pierna` (inc01) · `D43#john_h`/`D01.TWIS#james` (inc02) · `D01.SPEC#hudson`/`D01.SCAN#turner` (inc03) · `D01.SCAN#boda`/`D44#conoce_mary` (inc06) · `D01.FIVE#madre`/`D44#madre_muerta` (inc07) · `D01.FIVE#una_mujer`/`D01.SCAN#marzo_1888` (inc08) · `D44#july7`/`D44#septiembre` (inc09) · `D01.REDH#abril`/`D01.REDH#octubre` (inc10, tutorial) |
| C2.R1–R5 | `D02#clausula`→D02@L1 · `D05#marque`→D05@BM · `D04#clausula`→D04@Crane · `D29a#tachadura`→D29a@L4 · `D01N#fina_fo`→D01N@tomo · siempre con `D03#sheer` (→@tomo/@Crane/@BM según ruta) |
| C3.R1–R4 | `D05#corniche` · `N:RB.foto.linea` (D07@Crane) · `D08#kanzel`→D08@BM · `R:D27.texto` (P) · con `D03#sheer` |
| C4.R1–R5 | `D03#a_mycroft` (@Crane/@BM) con: `D18#calendars`→D18@L6 · `D19#indice`→D19@BM · `D30#recibo`→D30@L3 · `D29b#surcos`→D29b@L4 · `L:hudson.mycroft_paga` |
| C5.R1–R4 | `D09#desague`@BM + `D11#desague`@BM · `D09#cruel`@Crane + `D10#cruel`@Crane · `R:D28.anglo` + `D10#portada`@BM · `D09#nota_redactor`@BM + `D10#frontispicio`@BM |
| C6 | subrutas K-S (`J:go` + `N:*.sil_wiggins`), K-T (`AD:prologo` + `R:HC10.texto`), K-T' (`AD:<n>` + `R:HB1.col`), K-BM/K-W/K-H vía `S:HC06.b_k*` (columna) o `R:HA1.*` / `R:HB1.carta` / `R:HB4.carta` / `L:hudson.ordenes` (garantizada u opcional) |
| C7.R1–R8 | `M:HA1.carta`/`M:HA0.carta` + `M:D46` (el pliego del club de HC06 (f), D46@L5) o `R:HC04.tarjeta` · `S:HC06.b_*` + `D31#para_mholmes`@L5 · `R:HA0.*`/`R:HA1.*` + `D30#recibo` · `N:L2.cotter_canastilla` + `N:L2.cesto_tiras` + `D01.GREE#founders`@BM · `L:watson.escribi_mycroft`/`R:HB5.recibo` + `R:HB1.carta` · `R:HC01.sobre` + `D01.GREE#pall_mall` · `L:wiggins.vieja_tarifa` + `D01.GREE#whitehall` · `R:HA1.giro` + `S:HC06.a` |
| C8.R1–R4 | `D13#muestra97`+`D12#n97` · `D14#opusculo`+`D44#oficios_mano`@Crane · `S:HC06.c`+`D31#telegramas` · `R:HC01.no_lo_es`+`D12#dedicatoria` · apoyo `D13#jartum`+`D34#ruinas`/`D35#califa` |
| C9.R1–R5 | `S:HC05.jueves_a`+`N:L3.ventanas_abiertas`/`N:L3.shag` · `S:HC06.e`+`N:L3.cajon` · (R3: sellos y `R:HB*.col`, no cuenta) · `S:HC05.jueves_a`+`D31#ruta` (apoyo) |
| C10 | Ia `N:PRO.harris`+`D16#moran` · Ib `S:M7.inteligente`+`D10#adjetivos`@Crane · Ic `D23#cruel`+`D10#adjetivos` · Id `L:wiggins.conduit`+`D17#moran_conduit` · Ca `D10#cabrito_atado`@BM+`S:M6.donde` · Cb `D11#no_bala`+`S:M7.donde_duerme` · Cc `R:HB7.col`+`D10#cabrito_atado` · Cd `R:M2.nota`/`R:HB9.carta`+`D11#hacerlo_balar` |
| C11.R1–R2 | `D15.0403#whist`+`D15.0403#nadie_oyo`+`D03#air_guns`@BM+`D10#bala_blanda`@BM · `N:L7.linea_de_tiro`+`D11#mejor_tiro`@BM+`D16#moran`@BM+`D03#air_guns`@Crane |
| C12.R1–R4 | `N:L1.librero_dedos`+`D14#amarillo`+`N:L1.librero_sombra` · `D33#direccion`+`D17#church_street`@Crane+`D12#dedicatoria` · `R:D37.precio`+`D12#dedicatoria`+`N:L1.librero_sombra` · R2 `N:PARK.libros`+`D33#tree_worship` (sólo epílogo) |
| C13.R1–R5 | `N:L8.guillotina`+`N:L8.ceniza`+`S:M7.trichinopolis` · `S:AGENTE.militar`+`S:PRO.cace_india` (+`D10#apostarse`@BM) · `D32#llave_harris`+`N:PRO.harris` · `R:M10.linea`+`D10#apostarse`. Todos con `f:secreto_camden` |
| C14.R1–R3 | `D01N#mi_james`/`D01N#nov93`+`D18#mary` (⚠ `w:`) · `D20#subasta`@BM+`D45#duelo`@BM · `N:L4.hueco_estante`/`N:L4.crespon`+`D01N#nov93` |
| Pistas falsas (§10.5 GDD) | refutaciones: `D03#baston`/`D05#baton` · `D03#hopeless`/`D19#presume` · `D03#steiler`/`R:D27.texto` · `D18#calendars`/`D19#indice` · `D04#cajista`/`D01N#fina_fo` · `D34#ruinas`/`D35#califa` · `D05#corniche` · `D15.0403#nada_falta`/`N:L7.azafranes` · `N:L3.cajon`/`D15.0405#meunier` |

### 4.9 `reactions/*.json` (campos de GDD§9.1; W2-STRUCT)

```json
{"reactions": [
  {
    "id": "HA1", "tipo": "garantizada_por_acto", "lado": "mycroft", "voz": "A", "nivel": 1, "canal": "K-BM",
    "actor": ["cotter", "mycroft"],
    "disparador": {"evento": "slip", "match": {"topic_group": "holmes"}, "una_vez_por": ["topic"]},
    "condiciones": {"all": [{"day": {"gte": 1, "lte": 9}}, {"not": {"weekday": "dom"}}]},
    "ancla": ["seat", "title", "hour"],
    "latencia": {"tipo": "voz_a"},
    "efecto": [{"op": "carta", "plantilla_por": "topic"}],
    "doc": {"title": "Carta a máquina, matasellos S.W.", "src_type": "carta_recibida", "class": "P", "font": "maquina", "machine": "remington_cotter", "paper": "diogenes_recortado", "paper_mm": [203, 244], "measure": {"entity": "papel_corto", "tags": ["me_vigila_de_cerca"]}, "firma": "Un amigo de la exactitud"},
    "rastro": [
      {"tpl": "holmes_prensa_1891", "texto": "{{#ancla a:ancla_kbm a:me_vigila_de_cerca|[[@act|Asiento ${seat}]]: los guías hablaron al Journal, el Journal a Reuter y el doctor no habló con nadie.}} Tres fuentes que son una. {{#giro a:me_vigila_de_cerca e:giro_ahorrare|Le ahorraré el trabajo: lea a Reuter.}}"},
      {"tpl": "holmes_cronicas", "texto": "{{#ancla a:ancla_kbm a:me_vigila_de_cerca|[[@act|Asiento ${seat}]]: el doctor se equivoca dos veces por página; no pierda la vista con la tercera.}}"},
      {"tpl": "holmes_monografia", "texto": "{{#ancla a:ancla_kbm a:me_vigila_de_cerca|[[@act|Asiento ${seat}]]. La ceniza no es su ramo, señor.}}"},
      {"tpl": "sigerson", "texto": "{{#ancla a:ancla_kbm a:me_vigila_de_cerca|[[@act|Asiento ${seat}]]. Los noruegos escriben de montañas, no de usted.}}"}
    ],
    "corta": [], "agrega": ["C6", "C7.R1", "C7.R3"], "variante_blanda": null, "exento_d2": false
  },
  {
    "id": "HC10", "tipo": "columna", "lado": "holmes", "voz": "B", "nivel": 1, "canal": "K-T",
    "actor": ["holmes", "cotter"],
    "disparador": {"evento": "tiempo", "tk": "4.dawn"},
    "condiciones": {},
    "ancla": ["text"], "ancla_de": {"evento": "ad", "match": {"ad": "AD:prologo"}},
    "latencia": {"tipo": "fija", "tk": "4.dawn"},
    "efecto": [{"op": "columna"}],
    "rastro": [{"tpl": "texto", "texto": "AL LECTOR DE HOLYWELL STREET. — {{#ancla a:ancla_kt a:corresponsal_s|[[@act|Busca usted testigos del 4 de mayo.]]}} {{#fuente a:remite_journal e:journal_de_geneve|Hubo tres guías, un pastor y un médico; los cuatro primeros hablaron en francés, y lo dijeron en Ginebra.}} —S."}],
    "corta": [], "agrega": ["C6", "C9.R3"], "variante_blanda": null, "exento_d2": true
  },
  {
    "id": "HB1", "tipo": "opcional", "garantizada_si": {"canal": "K-T", "n": 1}, "lado": "holmes", "voz": "B", "nivel": 1, "canal": "*",
    "actor": ["holmes", "cotter"],
    "disparador": {"evento": ["ad", "say"], "match": {"bait": true}, "contador": "bait_topic", "n_in": [1, 2]},
    "condiciones": {"not": {"flag": "watson_expuesto"}},
    "ancla": ["phrase"],
    "latencia": {"tipo": "voz_b"},
    "efecto": [{"op": "columna", "si_canal": "K-T"}, {"op": "carta", "si_canal": ["K-W", "K-H"], "firma": "—S."}],
    "rastro": [
      {"tpl": "pared.1", "texto": "{{#ancla a:ancla_${ch} a:corresponsal_s|[[@act|«A pique»]]: dele.}} {{#fuente a:remite_journal e:journal_de_geneve|Véase el Journal de Genève del 6 de mayo de 1891.}} —S."},
      {"tpl": "pared.2", "texto": "{{#ancla a:ancla_${ch} a:corresponsal_s|[[@act|Quien fotografía la cascada desde la otra orilla]] ve lo que no ve quien camina el sendero.}} —S."}
    ],
    "corta": [], "agrega": ["C6", "C9.R3"], "variante_blanda": null, "exento_d2": true
  },
  {
    "id": "M1", "tipo": "opcional", "lado": "moran", "voz": "M", "nivel": 3, "canal": "informe",
    "actor": ["hombres_de_moran"],
    "disparador": {"evento": "report", "match": {"cat": "original_p"}},
    "condiciones": {},
    "ancla": [],
    "latencia": {"tipo": "siguiente_salida"},
    "efecto": [{"op": "retirar", "copias": "informadas", "dias": 1}, {"op": "alterar_lugar", "place": "L1", "variant": "registrada"}],
    "rastro": [{"tpl": "ceniza", "nodo": "N:L1.ceniza_registro", "tags": ["a:tirador", "e:cheroot"]}],
    "corta": [{"copias": "informadas", "ventana": {"dias": 1}}],
    "agrega": ["C10", "C13"],
    "variante_blanda": {"efecto": [{"op": "alterar_lugar", "place": "L1", "variant": "registrada"}], "corta": []},
    "exento_d2_desde_dia": 8
  }
]}
```

| campo (GDD§9.1) | forma |
|---|---|
| `id`, `tipo` | `columna` · `garantizada_por_acto` · `opcional` · `respuesta` (D27, D28, copia de L6) · `silencio` (HB14, sólo documental) |
| `lado`, `voz` | `holmes` (voz `B`), `mycroft` (voz `A`, órdenes permanentes por Cotter), `moran` (`M`), `respuesta` |
| `disparador` | `{"evento": tipo|[tipos]|"tiempo", "match": {...}, "una_vez_por": [...], "contador": nombre, "n_in": [...], "tk": "d.S"}`; `match` sobre campos del evento (o `cat` de informe) |
| `condiciones` | DSL §4.18 |
| `canal`, `actor` | canal K-xx (o `informe`, `*` = el del acto); actores que existen físicamente en ese lugar y fecha (T12) |
| `ancla` | campos del evento que la reacción cita (`seat`, `title`, `hour`, `phrase`, `streets`, `text`, `act_day`); `ancla_de` para columnas que citan un acto concreto |
| `latencia` | `voz_a` · `voz_b` · `fija {tk}` · `inmediata` · `siguiente_salida` · `siguiente_comunicacion` · `dias {n}` |
| `efecto[]` | ops: `carta` · `columna` · `noticia` · `escena {scene}` · `linea {char,line}` · `retirar {copias|copy, dias|null}` · `cerrar {target, dias|null}` · `silueta {who, desde}` · `flag {name,value}` · `alterar_lugar {place,variant}` · `devolver` · `paga {amount_d}` · `arrancar {copy}` · `linea_siguiente_comunicacion {text}` · `evento_mundo {id}` |
| `rastro[]` | plantillas `{tpl, texto|nodo, tags?, when?, tono?:{alto,bajo}}`; placeholders: `${seat} ${title} ${hour} ${phrase} ${streets} ${act_day} ${ch} ${addr}`; `[[@act|…]]` = entidad del acto ancla |
| `doc` | meta del documento runtime (como §4.4 sin `parts`) |
| `corta[]` | `{"ref": ruta | "copy": id | "copias": "informadas" | "acceso": "L4.consulta"|"L5.forasteros"|"canal:K-H", "ventana": {"dias": n} | {"permanente": true}}` |
| `agrega[]` | conclusiones o rutas que el rastro alimenta (documental; T5 usa las etiquetas reales del rastro) |
| `variante_blanda` | `{efecto, corta}` que D1 aplica si el corte violaría la invariante; **obligatoria** si `corta` no está vacío |
| `nivel`, `exento_d2`, `exento_d2_desde_dia` | D2 (§5.3) |

### 4.10 `schedule.json` (W2-STRUCT)

```json
{
  "days": [
    {"day": 0, "key": "P", "date": "1894-03-26", "weekday": "lun", "label": "Lunes de Pascua", "slots": [], "mail": false, "times": false},
    {"day": 1, "key": "1", "date": "1894-03-27", "weekday": "mar", "slots": ["M", "T", "N"], "mail": true, "times": true},
    {"day": 6, "key": "6", "date": "1894-04-01", "weekday": "dom", "slots": ["T"], "mail": false, "times": false},
    {"day": 10, "key": "10", "date": "1894-04-05", "weekday": "jue", "slots": ["M", "T", "N"], "mail": true, "times": true, "fixed": true},
    {"day": 11, "key": "E", "date": "1903-10-01", "weekday": "jue", "slots": [], "mail": false, "times": false}
  ],
  "slot_hours": {"M": "9–13", "T": "13–18", "N": "18–22"},
  "passes": {"default": 1, "P.N": 0, "9.N": 2, "10.M": 1},
  "lot": {"default": 2, "day10": 1},
  "reports": [{"n": 1, "tk": "2.night"}, {"n": 2, "tk": "5.night"}, {"n": 3, "tk": "8.night"}, {"n": 4, "tk": "10.M", "final": true}],
  "ads": {"office_slots": ["M", "T"], "per_day": 1, "prologue_pub_day": 1},
  "places": {
    "L1": {"areas": {"buhardilla": {"open": [{"days": "all", "slots": "all"}]}, "tienda": {"open": [{"days": [1, 2, 3, 4, 5, 7, 8, 9, 10], "slots": "all"}], "free": true}}},
    "L2": {"areas": {"sala": {"open": [{"days": [1, 2, 3, 4, 5, 7, 8, 9], "slots": ["M", "T", "N"]}], "_nota": "N hasta las 20 h; domingo ⚠ (GDD§15.8)"}}},
    "L5": {"areas": {"porteria": {"open": [{"days": [1, 2, 3, 4, 5, 6, 7, 8, 9], "slots": "all"}]}, "forasteros": {"open": [{"days": [8, 9], "slots": ["T", "N"]}], "needs": {"not": {"flag": "forasteros_cerrada"}}}}},
    "L8": {"areas": {"interior": {"open": [{"from": "7.T", "to": "9.T", "slots": ["M", "T"]}]}}}
  },
  "column": [
    {"tk": "1.dawn", "r": "HC01"}, {"tk": "3.dawn", "r": "HC02"}, {"tk": "4.dawn", "r": "HC10"}, {"tk": "5.dawn", "r": "M6"},
    {"tk": "6.dawn", "r": "HC03"}, {"tk": "7.night", "r": "M7"}, {"tk": "8.dawn", "r": "HC04"}, {"tk": "8.dawn", "r": "HC05"},
    {"tk": "9.dawn", "r": "M8"}, {"tk": "10.M", "r": "HC07"}, {"tk": "10.T", "r": "HC08"}, {"tk": "10.N", "r": "HC09"}
  ],
  "voice_b": {"1": "4.dawn", "2": "5.dawn", "3": "7.dawn", "4": "8.dawn", "5": "8.dawn", "6": "10.dawn", "7": "10.dawn", "8": "10.dawn", "9": "10.M"},
  "voice_a": {"default_days": 1, "sunday": "en_mano"},
  "money_d": {"guinea": 252, "ad": 30, "cab_min": 12, "cab_max": 24, "somerset": 12},
  "baedeker": "SALA DE LECTURA DEL MUSEO BRITÁNICO. — Abierta de 9 a 20 h… (texto con marcado; página pegada en el mapa)"
}
```
Ventanas: `{"days": [..]|"all", "slots": [..]|"all", "from": "d.S", "to": "d.S"}` (AND dentro, OR entre ventanas); `needs`: condición DSL; `free: true` = no gasta franja (tienda de Crane).
`days[].weekday` = código **ASCII** `lun mar mie jue vie sab dom` (Schema lo exige; también en el átomo `weekday` de toda condición de `data/`, §12.2). `label` es el rótulo largo para la UI.

### 4.11 `places/L#.json` y `plates/*.json` (W2-PLACES-*)

```json
{
  "id": "L4", "name": "Consultorio del doctor Watson, Kensington", "streets": ["Kensington High Street", "Church Street"],
  "areas": {"consulta": {"desc": "sala de espera y consultorio"}, "estudio": {"desc": "estudio de la casa (domingo)"}},
  "observers": ["watson"], "epigraph": "—¿Sus ojos, señor Lisle?",
  "frames": [
    {"id": "puerta", "area": "*", "pos": [0.0, 1.6, 4.2], "look": [0.0, 1.2, 0.0], "fov": 42, "orbit": {"pivot": [0.0, 1.1, 0.0], "yaw": 25, "pitch": 10}},
    {"id": "estante", "area": "estudio", "pos": [1.8, 1.55, 1.0], "look": [2.6, 1.4, -1.2], "fov": 38, "orbit": {"pivot": [2.4, 1.3, -1.4], "yaw": 20, "pitch": 8}}
  ],
  "light": {"M": "dia_ventana", "T": "tarde", "N": "gas"},
  "props": [
    {"id": "cuarto", "type": "architecture.room", "pos": [0, 0, 0], "rot": 0, "p": {"w": 5.0, "d": 4.4, "h": 3.0, "openings": [{"wall": "n", "kind": "window", "x": 1.0, "w": 1.1, "h": 1.6, "sill": 0.9}, {"wall": "s", "kind": "door", "x": -1.4, "w": 0.9, "h": 2.1}]}},
    {"id": "estante2", "type": "furniture.bookshelf", "pos": [2.4, 0, -1.9], "rot": 0, "p": {"w": 1.6, "h": 2.1, "rows": 5, "fill": 0.9, "gap": {"row": 1, "from": 0.35, "to": 0.62}}},
    {"id": "escritorio", "type": "furniture.desk", "pos": [-0.8, 0, -1.2], "rot": 15, "p": {"w": 1.4, "d": 0.7}},
    {"id": "perchero", "type": "furniture.coat_stand", "pos": [-2.0, 0, 1.6], "rot": 0, "p": {"hat": "bowler_crepe"}}
  ],
  "nodes": [
    {"id": "hueco_estante", "prop": "estante2", "noun": "estante", "anchor": {"c": [2.4, 1.45, -1.85], "s": [0.45, 0.3, 0.25]}, "examine": "En el segundo [[estante]] falta una hilera de cinco tomos; el polvo marca el lugar de los lomos.", "tags": ["a:tomos_de_watson", "e:tomos", "c:watson_privado"], "cls": "C", "area": "estudio", "when": {}},
    {"id": "crespon", "prop": "perchero", "noun": "sombrero", "anchor": {"c": [-2.0, 1.75, 1.6], "s": [0.3, 0.15, 0.3]}, "examine": "Un [[bombin|bombín]] con una banda de [[crespon|crespón]].", "tags": ["a:duelo", "c:watson_privado"], "cls": "C", "area": "*", "when": {}}
  ],
  "characters": [
    {"id": "watson", "area": "*", "pos": [-0.6, 0, -0.3], "rot": 200, "pose": "de_pie", "trait": "bombin_crespon", "when": {"any": [{"slot": ["M"]}, {"day": 6}]}}
  ],
  "silhouettes": {
    "wiggins": {"frame": "puerta", "pos": [3.6, 0, 5.5], "rot": 180},
    "m3_hombres": {"frame": "puerta", "pos": [4.0, 0, 6.5], "rot": 180},
    "cochero": {"frame": "puerta", "pos": [-3.2, 0, 6.0], "rot": 160}
  },
  "variants": {}
}
```

- Unidades: metros, Y arriba, origen = centro del piso; `rot` en grados (eje Y). `type` = `"<módulo>.<función>"` → `res://world/props/<módulo>.gd`, `static func build_<función>(p: Dictionary) -> Node3D` (§7.2).
- `nodes[]`: `anchor` = AABB explícita (`c` centro, `s` tamaño) usada para recorte y oclusión; `examine` = hecho observable en marcado (sin colores como única pista, T29); `tags` misma gramática que los tramos; `cls` I/P/C; `area`; `when` DSL (día, franja, flags: p. ej. `{"day": {"gte": 8}}` para las ventanas abiertas de L3).
- `nodes[].on_clip_flag` (W4, opcional): recortar el nodo escribe ese flag (escritor: Clipper; hoy `PARK.libros` → `vio_libros_park`).
- `epigraph_by_area` (W4, opcional): `{área: epígrafe}` gana sobre `epigraph` en esa área (L4 estudio el domingo).
- `silhouettes.<who>.talk` (W4, opcional): áreas donde a la silueta se le habla (Wiggins: sólo exteriores — L1 tienda, L3 calle, L5 portería, L7 exterior; `[]` en L2, L4, L6, L8). En las demás se ve por la ventana, sin panel: `WorldModel.start_visit` no la suma a los personajes y `Availability._sil_char_srcs` recorre sólo esas áreas. Sin `talk`: toda área.
- `silhouettes`: posición garantizada **sin tapar** en el encuadre `frame` (T29: Wiggins visible en ≥1 encuadre de cada lugar desde el día 3). El nodo de silueta se llama `sil_<who>` y lleva `a:ancla_ks` + entidad del acto `go` de esa visita; su examen neutro es `ui_text` `sim.sil.<who>` (§12.2 D15).
- `characters[].trait`: rasgo de silueta (§7.4).
- `variants`: `{"registrada": {"add_nodes": [...], "move": {"prop_id": {"pos": [...]}}}}` (M1).
- Láminas fijas (`plates/*.json`): mismo esquema + `"fixed": true`, `"origin": "PL.prologo"`; Reichenbach: `"variants": {"fina": …, "journal": …, "foto": …}` y `"doc_variant": {"D03": "fina", "D05": "journal", "D07": "foto"}` (la variante se elige con el documento abierto).

### 4.12 `dialogue/<char>.json` (respaldo por capas; T20, T20b)

```json
{
  "char": "watson", "label": "el doctor Watson", "intro": "Dr. J. H. Watson", "addr": "doctor", "sensor": "K-W",
  "max_questions": 3, "trait": "bombin_crespon",
  "closing": "Tengo pacientes, señor Lisle.",
  "ask_phrase": {"default": "¿Qué sabe usted de ${topic}, ${addr}?"},
  "lines": [
    {"id": "pared", "layer": "tema", "match": {"topic": ["pared", "a_pique", "reichenbach"]}, "when": {}, "text": "Palidece. —Era un sendero estrecho, señor Lisle. Lo escribí como lo vi."},
    {"id": "escribi_mycroft", "layer": "tema", "match": {"topic": ["mycroft", "fina"]}, "when": {"event_count": {"type": "say", "where": {"char": "watson", "topic_group": "roca"}, "gte": 1}}, "text": "{{#escribi a:vinculo_mycroft e:mycroft|Le escribí al señor Mycroft, como cuando lo de las pruebas.}}"},
    {"id": "herida", "layer": "tema", "match": {"topic": ["herida", "hombro", "pierna"]}, "text": "{{#bala x:EE02|La bala no leyó mis crónicas, señor.}}"},
    {"id": "doc.galerada", "layer": "documento", "match": {"doc": ["D02", "D04"]}, "text": "Mira la prueba largo rato. —¿De dónde ha sacado usted esto?"},
    {"id": "tipo.persona", "layer": "tipo", "match": {"kind": ["persona"]}, "text": "No lo conozco lo bastante para opinar, señor Lisle."},
    {"id": "gen.1", "layer": "generica", "text": "Un hombre puede ser herido más de una vez, señor Lisle."},
    {"id": "gen.2", "layer": "generica", "text": "Lo que imprimí, lo imprimí de buena fe."}
  ]
}
```

Capas (orden): `afirmacion` (match `assertion`) → `tema` (match `topic` = entidad preguntada, o entidad visible del recorte presentado) → `documento` (match `doc` visible del recorte) → `entidad` (alguna entidad visible) → `tipo` (kind de la entidad) → `generica` (`Det.pick`). `match` **sólo** sobre propiedades visibles; `when` sobre estado del mundo (nunca sobre etiquetas ocultas). Una línea puede llevar `effects` (ops de §4.9) y `reaction` (id de reacción inmediata, p. ej. HB4). La línea dicha queda en el diario con origen = escena.

### 4.13 `scenes/<id>.json` (escenas fijas y líneas automáticas)

```json
{
  "id": "M7", "place": "L1", "area": "buhardilla", "tk": "7.night", "plate": "PL.M7", "origin": "S.M7",
  "lines": [
    {"id": "inteligente", "who": "harris", "text": "{{#adjetivos a:harris_es_moran e:adjetivos_repetidos|Un trabajo inteligente, inteligente.}}"},
    {"id": "donde_duerme", "who": "harris", "text": "No me diga que vive, señor Lisle. {{#donde a:busca_a_holmes e:donde|Dígame dónde duerme [[tigre|el tigre]].}}"},
    {"id": "trichinopolis", "who": "harris", "text": "¿Le molesta el humo? {{#tri a:tirador e:cheroot f:secreto_camden|Es de [[trichinopolis|Trichinópolis]].}}"}
  ],
  "variants": [
    {"when": {"flag": "pell_despedido"}, "replace": {"inteligente": "{{#adjetivos a:harris_es_moran e:adjetivos_repetidos|Un trabajo inteligente, inteligente.}} Su procurador ya no nos sirve."}},
    {"when": {"flag_gte": {"informes_vacios": 2}}, "append": [{"id": "mudo", "who": "harris", "text": "Un cabrito mudo no me sirve, señor."}]},
    {"when": {"flag": "moran_credito_perdido"}, "append": [{"id": "exactitud", "who": "harris", "text": "Le ruego exactitud, exactitud."}]}
  ]
}
```
`auto_lines` (escenas de lugar sin pregunta): `{"id": "HC05", "place": "L3", "area": "interior", "when": {"day": {"gte": 8, "lte": 9}}, "auto": true, "lines": [{"id": "jueves_a", …}, {"id": "jueves_b", …}]}`. Líneas generadas: `{"id": "b", "gen": "acts_by_channel", "tpl": {"kbm": "…[[@act|…asiento ${seat}…]]…", "kw": "…", "kh": "…", "ks": "…", "kt": "…"}, "fallback": "…"}` produce `b_kbm`, `b_kw`, … (HC06 (b)).

- Tramos de escena: **uno por oración y un solo grupo de conclusión por tramo** (T4). `donde_duerme` cubre el grupo `busca` de C10 (subruta Cb); el grupo `cebo` lo da su pareja `D11#no_bala` (W2-STRUCT: «Ca–Cd: un fragmento con cebo y otro con busca_a_holmes»). La 1.ª oración de `donde_duerme` y de `trichinopolis` queda sin tramo.
- `place` es **opcional** (§12.2): las escenas sin lugar del mapa (finales `END.F1`–`END.F4`, epílogo `EPI`) lo omiten; el motor nunca las toma por escena fija de columna.
- `variants[].replace` cambia el texto de una línea **base** y **conserva sus tramos** (mismos `#id`, mismas etiquetas; Schema lo verifica): la ruta `S:M7.inteligente` debe valer en todas las versiones. `append` agrega líneas con ids nuevos (nunca el de una línea base).

### 4.14 `canon_bible.json` (W1-BIBLE; T7)

```json
{"facts": [
  {"id": "F.reichenbach", "event": "1891-05-04", "published": "1893-12-01", "mark": "C", "src": "EMPT", "src_en": "a ledge several feet deep and covered with soft green moss, where I could lie unseen",
   "knowable": {"publico": "1893-12-01", "holmes": "1891-05-04", "mycroft": "1891-05-04", "moran": "1891-05-04", "watson": "1894-04-05"}, "text": "Holmes no cayó: subió a una cornisa; Moran lo vio vivo."},
  {"id": "F.mary_muerte", "event": "1893-11-25", "published": "1894-02-03", "mark": "INV", "hue": "HUE-06",
   "knowable": {"publico": "1894-02-03", "watson": "1893-11-25", "mycroft": "1893-11-26", "holmes": "1894-04-05"}, "text": "Muere Mary Watson en Paddington; sin aviso en el Times; The Lancet alude al duelo."},
  {"id": "F.jartum", "event": "1893-06-01", "published": "1893-06-01", "mark": "INV", "hue": "HUE-04", "false_lead": true,
   "knowable": {"publico": "1893-06-01"}, "text": "Nota comunicada: Sigerson en Jartum, huésped del Califa (error: el Califa reside en Omdurmán)."}
]}
```
T7: un doc con `h:F.x` y `date` < `knowable.publico` falla; una línea de personaje `who` en `tk` con `h:F.x` falla si `knowable[who]` > fecha de `tk`.

### 4.15 `endings.json` (W2-STRUCT; orden de evaluación GDD§12.1)

```json
{
  "rank_note": "1 = mejor. Propuesta del arquitecto; el GDD exige rank explícito pero no fija valores (§12).",
  "endings": [
    {"id": "F1", "order": 1, "rank": 1, "name": "Al menos un lector",
     "cond": {"all": [{"sealed_all": ["C6", "C7", "C10"]}, {"sealed_count": {"of": "mandatory", "gte": 8}}, {"flag_eq": {"informe_final": "errata"}}, {"not": {"flag": "watson_expuesto"}}, {"flag": "moran_credito"}, {"not": {"flag": "moran_credito_perdido"}}, {"not": {"flag": "holmes_entregado"}}]},
     "card": "Lisle, Edmund. Lector. Sabe dónde se esconde la gente en una errata.", "scene": "END.F1"},
    {"id": "F4", "order": 2, "rank": 5, "name": "Ve, pero no observa", "cond": {"sealed_count": {"of": "mandatory", "lt": 6}}, "card": "Ve, pero no observa.", "scene": "END.F4"},
    {"id": "F2", "order": 3, "rank": 4, "name": "El informe fiel", "cond": {"report_final_cats_any": ["holmes_vive", "regreso_jueves", "baker_street", "camden"]}, "card": "Útil al bando equivocado. Vigilar.", "scene": "END.F2"},
    {"id": "F3a", "order": 4, "rank": 2, "name": "El silencio", "cond": {"any": [{"flag_eq": {"informe_final": "nada"}}, {"flag_eq": {"informe_final": "quemar"}}]}, "card": "Supo cuándo callar.", "scene": "END.F3"},
    {"id": "F3b", "order": 5, "rank": 3, "name": "El silencio (mentira)", "cond": {"always": true}, "card": "Mintió bien, y solo. Imprudente.", "scene": "END.F3"}
  ],
  "variants": [
    {"id": "V.confront_completa", "cond": {"flag_eq": {"confront_estado": "completa"}}, "card_add": "Cuatro de cuatro."},
    {"id": "V.confront_incompleta", "cond": {"flag_eq": {"confront_estado": "incompleta"}}, "card_add": "Tres errores; buen papel."},
    {"id": "V.C14", "cond": {"sealed": "C14"}, "epilogue": "tomos_devueltos"},
    {"id": "V.C11", "cond": {"sealed": "C11"}, "epilogue": "teoria_correcta"},
    {"id": "V.expuesto", "cond": {"flag": "watson_expuesto"}, "epilogue": "subraya_first_and_last"}
  ]
}
```

### 4.16 `easter_eggs.json` (W2-STRUCT; T13)

```json
{"eggs": [
  {"id": "EE01", "name": "«Mi James»", "trigger": {"clip_tag": "x:EE01"}, "note": "Mary llamaba «James» a su marido. Sic, con ternura."},
  {"id": "EE03", "name": "El 4 de mayo", "trigger": {"pairs_over": ["D43#cuatro_mayo", "D44#perlas", "D03#cuatro_mayo"]}, "note": "Tres veces el 4 de mayo. Sic."},
  {"id": "EE13", "name": "Trichinópolis", "trigger": {"pair_tags": ["e:trichinopolis", "e:ceniza_negra"]}, "note": "El autor de la monografía habría sabido de quién era."}
]}
```
Reglas: ≤1 por visita (los demás esperan a otra visita), sin contador, nunca etiquetas de C2–C13 ni rutas (T13). Se muestran en la pestaña Marginalia.

### 4.17 `fonts.json`, `audio.json`, `map.json`, `ui_text/*.json`

```json
{"slots": {
  "imprenta": {"file": "res://assets/fonts/IMFeENrm28P.ttf", "italic": "res://assets/fonts/IMFeENit28P.ttf"},
  "maquina": {"file": "res://assets/fonts/SpecialElite-Regular.ttf"},
  "manuscrito": {"file": "res://assets/fonts/HomemadeApple-Regular.ttf"},
  "ui": {"file": "res://assets/fonts/IMFeENrm28P.ttf", "italic": "res://assets/fonts/IMFeENit28P.ttf"}
}, "fallback": "embedded"}
```
`"file": "embedded"` = copia de `ThemeDB.fallback_font.data`. Las cuatro fuentes ya están aprobadas y en `assets/fonts/` (según `CLAUDE.md`); cambiar de fuente = cambiar sólo esta tabla.

`audio.json`: `{"captions": {"bells.st_clement": "campanas de St Clement Danes", …}, "ambience": {"L2": {"*": "amb.reading_room"}, "L1": {"M": "amb.street", "N": "amb.gas"}, …}, "events": {"dawn": ["bells.st_clement", "evt.milk_cart", "evt.crane_shutter"]}}`.
`map.json`: `{"size_mm": [600, 420], "places": {"L1": {"xy": [412, 238], "label": "Holywell Street"}, …}, "streets": [[[x,y], …], …], "booth_zones": [{"poly": […], "class": "C"}, …]}` (mapa dibujado por código; sin imágenes). W4: `"world_events": {<id de evento_mundo>: {"on": "salida"|"amanecer", "sound": <id de audio.json>, "veil": bool}}` — la forma en pantalla de un evento del mundo (M2: el ladrillo al salir, sonido y polvo), una sola vez.
`ui_text/<wp>.json`: `{"text": {"formal.falta_segun": "Falta un <i>según</i>.", "formal.una_fuente": "Una sola fuente no es prueba.", "formal.demasiado_papel": "Demasiado papel.", "pass.fail": "Alguno no se sostiene.", "clip.cruza_oracion": "La tira no cruza un punto."}}`.

### 4.18 DSL de condiciones (`core/util/cond.gd`)

`{}` = verdadero. Combinadores: `all:[…]`, `any:[…]`, `not:{…}`, `always:true`.
Átomos: `day:{gte,lte,eq}|int` · `slot:[…]` · `weekday:"dom"|[…]` (códigos ASCII) · `tk:{gte,lte}` · `flag:"x"` · `flag_eq:{x:v}` · `flag_gte:{x:n}` · `sealed:"C6"` · `sealed_all:[…]` · `sealed_count:{of:"mandatory"|[…], gte|lt}` · `counter:{name, gte|lte|eq}` · `event_count:{type, where:{campo:valor|topic_group}, gte}` · `visited:"L3"` · `channel_closed:"K-H"` · `report_final_cats_any:[…]` · `anchor:{campo:valor}` (selección de plantilla de rastro) · `char_present:"wiggins"` · `pencil_wrong:bool` (W4; átomo del jugador, `PLAYER_ATOMS`: hay o no algún asiento a lápiz que el lápiz azul marca; END.F1).
Un átomo desconocido es error de esquema (Schema), nunca `false` silencioso.

---
## 5. Sistemas

### 5.1 Recorte (`clip_rules.gd`, `clipper.gd`; W1-ENG / W2-DED)

Recorte de texto (`clip_text`):
1. `WorldModel.view_accessible(view)`; si no → `inaccesible`. `clip_mode:"memoria"` → máx. 3 por visita a L6 (`memoria_agotada`).
2. `ClipRules.snap(parsed, from, len)`: extiende a palabras completas (inicio de la primera palabra tocada, fin de la última más su puntuación pegada); exige ≥1 palabra (`vacio`), una sola oración (`cruza_oracion`) y ≤40 palabras (`mas_de_40`).
3. `ClipRules.inherit`: entidades = menciones que intersecan + `e:` del tramo ganador; **tramo ganador** = mayor fracción cubierta `solape/longitud_tramo` (empate → menor `from`); hereda `a: c: f: d: p: x:` sólo si la fracción ≥ 0,5.
4. Recorte = `{id, kind:"text", text, ents (+ entity del doc + clip_entities + máquina), tags, origin, copy, cls, src_line, chron_date, place, view, from, to}`. `Index.add_entities`.
5. Origen: doc → `origin` del bloque; línea dicha → escena; diario → origen de lo que copia (línea dicha → su escena; acto → `D36`); nodo → lámina.

Recorte de lámina (`clip_plate`; la geometría la resuelve `world/rect_clip.gd`, §7.6): el sim valida `area_frac ≤ 1/8`, `hits` ⊆ nodos de la instantánea (`q_plate`), toma ≤2 hits con `cover ≥ 0.5` no ocluidos; etiquetas sólo del hit de mayor `cover` y sólo si `tight`; entidades: las de los nodos capturados; epígrafe: `noun` de **todos** los `touched` («mesa, cesto, mozo con gorra»). Rectángulo vacío = recorte legal sin etiquetas.
Recorte de medida (`clip_measure`): texto «Mide ${h} por ${w} milímetros.» con `measure.entity` y `measure.tags` del doc/escena.
Pares (`link`): `{id, a, b, note}`; valen por sus dos recortes; no se anidan (`anidado`). Los recortes sobreviven a robos y retiros del original (son copias); Holmes no los ve.

- **W4 · Índice desde el instructor (única excepción).** Al decir la línea del paso «ad» del tutorial (Harris, `PRO.t_ad`: «se busca testigo de [[suceso_reichenbach|lo de Suiza]]»), `GameSim._say_tutorial_line` agrega al índice las entidades que nombra (`Index.add_entities`), para que la forma «testigo» nunca tenga el blanco vacío (`Composers.options` y `_slot_ok` leen el índice). Es la única entrada del índice que no viene de un recorte (test `test_u_tutorial::test_w4_prologue_never_blocks_real_data`).

### 5.2 Libro mayor y validador (`ledger.gd`, `validator.gd`; W2-DED)

Asiento: `{id, folio, template, lines:[{fields:{campo:valor}, support:[clip|pair]}], ink:"lapiz"|"tinta"}`. `entry_set` exige: valor ∈ índice del jugador (entidades) o ∈ lista cerrada (`accept`). Lápiz = editable y borrable gratis; tinta = inmutable.

**Chequeo formal** (visible, inmediato, no gasta): toda línea con algún campo lleno tiene ≥1 ítem en su «según» (`falta_segun`); ≥2 orígenes distintos en el fundamento (`una_fuente`; en C1 basta que sean 2 pasajes distintos); ≤4 recortes únicos con pares expandidos (`demasiado_papel`).

**Chequeo de contenido** (`entry_ok`, silencioso), para la conclusión `cid = which_conclusion(entry)` (la plantilla coincide y los valores pertenecen a `answers` + `constraints` + `alias_rules` vigentes):
1. valores válidos (lo anterior);
2. por cada grupo: la línea `group.line` tiene en su «según» ≥1 recorte con alguna etiqueta del grupo (`${ch:campo}` resuelto);
3. ≥2 orígenes distintos;
4. todo recorte lleva ≥1 etiqueta de la conclusión (unión de grupos + `tags_extra`) y ninguno `f:refutado`;
5. grafo de recortes conexo con aristas «comparten una entidad de `keys`» (o una entidad de un `kind` listado) o «mismo origen».

**Pasada** (`pass_clean`): requiere `passes_left > 0` y `len(entries) == lot_size` (`lot_size = 1` el día 10; si no `min(2, |lot_counts sin sellar|)`; nunca depende de cuántos asientos haya a lápiz). Si algún asiento falla el formal → `ok:false` (no gasta). Si no: gasta la pasada; si **todos** pasan `entry_ok` y sus `cid` son distintos y no sellados → todos a tinta, `st.ded.sealed[cid] = entry` (C10a sellada activa la regla de alias); si no → ninguno, mensaje único «Alguno no se sostiene.». `practice` (C1): de a uno, sin gastar, no cuenta para nada.
Lápiz azul (`Endings.blue_pencil`, post-créditos): por cada conclusión obligatoria no sellada, `blue_pencil.missing`; por cada asiento a lápiz con `which_conclusion` ≠ "" y `entry_ok` falso, `blue_pencil.wrong`.

### 5.3 ReactionDirector (`director.gd` + `latency.gd` + `effects.gd`; W2-REACT)

Estado (`st.react`): `queue:[inst]`, `delivered:[inst]`, `strong_days:{día:true}`, `channels_seen:{K-x: día}`, `inactivity:{slots_sin_acto:int}`, `holmes:{}`, `moran:{}`.
Instancia: `{iid:"R.<rid>.<n>", rid, due_tk, prio, channel, voice, level, strong, anchor:{…, act}, tpl, vars, soft:false, src_ev:seq, merged_into:""}`.

**`on_public_event(ev)`**
1. `Sensors.observe(ev)` → observaciones por canal (filtros §5.4; nunca `secreto_camden`, D10).
2. `HolmesAgent.observe` y `MoranAgent.observe` → instancias candidatas; `Latency.due_tk` fija `due_tk`.
3. Reacciones `latencia: inmediata` (HB4 gesto, HB6, HB12, M4 ante Pell, HB8) **no** pasan por la cola: las aplica `Dialogue` vía `Director.immediate`.
4. Encola (dedup por `una_vez_por`). Contador de inactividad: un acto observado lo pone en 0.

**`on_time(tk)`** — en `dawn`: resolver; en `M/T/N`: `siguiente_salida` (M1) al primer `go` del día o a la noche; en `night`: escenas fijas (M7) y `HB13` si `inactivity ≥ 2` franjas sin actos observados.
Resolución de la mañana (orden fijo, por `prio` y luego `iid`):
- `prio`: 0 columna (HC*, HA0, M6–M8) · 1 voz B · 2 voz A · 3 Moran · 4 respuestas (D27, D28).
- **D7**: todo valor «al azar» = `Det.pick(seed, [rid, iid, día])`.
- **D3**: si dos instancias son la **primera** de canales distintos esa mañana: si ambas son voz A → se fusionan en una carta (mismo `R.<…>`, bloques en orden de `iid`); si no → la de mayor `prio`/`iid` se difiere 1 día.
- **D2**: `strong = nivel ≥ 3 ∧ tipo ≠ columna ∧ ¬exento` (exentos: columna, toda voz B, HB10, M1 desde el día 8). Máx. 1 fuerte por mañana y mañana de calma después (`strong_days[d-1]` bloquea). Choque → diferir 1 día: primero Moran, después cortes de voz A. Diferir más allá del día 10 → fusionar con la entrega del día 10.
- **D1**: para cada instancia con `corta`: `Invariant.runtime_guard(st, repo, CutModel.cuts_for(rid))`; si viola → `soft = true` (aplica `variante_blanda`). Log `L.i("director", …)`.
- **D9/T2** (estático): ningún efecto apunta a un ejemplar I ni cierra la única fuente de un fragmento I.
- **D8** (estático T12): actor físicamente posible.
- `Effects.apply(inst, soft)`: crea el documento runtime (`instantiate_doc`) y lo entrega: voz A por correo con matasellos S.W. o, si la mañana es domingo, `en_mano` sin sello (HC03); voz B en la columna del *Times* del día si contesta algo publicado, o carta a máquina «—S.» si contesta algo privado (Ley 5); Moran por nota de Pell (o «H.» si `pell_despedido`) o efecto en el mundo. `Diary.on_arrival` agrega «Recibido: sobre, matasellos S.W.» (sin contenido).
- `channels_seen`, `strong_days`, `delivered` se actualizan. **Nunca** se emite un aviso de «reacción» a la UI: sólo `tray`, `flag`, `scene`.

Latencias (`latency.gd`): `voz_a` → `dawn` de D+1 (D = día del acto; anuncio: día de publicación) · `voz_b` → `schedule.voice_b[D]` (tabla GDD§9.3; día 9 → `10.M` en persona, que es HC07) · `fija` · `siguiente_salida` · `siguiente_comunicacion` (se adjunta a la próxima nota de Pell/«H.» o a M7/M8) · `dias {n}`.

### 5.4 Agentes (`sensors.gd`, `holmes_agent.gd`, `moran_agent.gd`; W2-REACT)

**Sensores** (`lists.sensors`): K-T ve anuncios publicados (texto); K-BM ve papeletas (asiento, título, hora), no lo leído; K-W ve lo dicho/mostrado a Watson sólo si toca `topic_groups.roca` o `mary` (Mary: `to_holmes=false`, sólo Mycroft/voz A); K-H ve visitas al interior de 221B y preguntas de `topic_groups.221b`; K-S ve calles y horas de cada `go` desde el día 3 (nunca la casa ni lo consultado). Todos quitan `secreto_camden` (T22). Contenido de K-W marcado `f:privado_kw`: nada público lo cita (T23).

**HolmesAgent** (`st.react.holmes`: `bait:{tema:n}`, `canary:{canal:n}`, `first_topic:{}`, `posture:int`, `confidence:int`, `hb4:int`, `hb8b:int`):
- Ley 2 por tema de cebo (global entre canales): n=1,2 → HB1 (`tpl "<tema>.<n>"`); n=3 → HB2 (falsa, rastro con `f:refutado`); n≥4 → nada.
- Canario por canal: 1.º → HA4; 2.º → HB11 (`canal_cerrado.K-x`; desde entonces sólo columna y garantizadas en ese canal).
- HA1: primera papeleta por `topic` con `slip_topics[topic] == "holmes"`; `silencio` → HB14 (nada).
- HA3: primer `go` desde el día 3. HB13: inactividad ≥2 franjas (texto `Det.pick`, nunca etiquetas de C2–C5/C8–C13, T16).
- `posture = max(posture, nivel)` al entregar. `confidence`: +1 si un anuncio refuta HB2/HB3 (`assertion.refutes`), +1 si tras HB9 un informe no trae `watson_privado`; −2 en HB9. Elige `tono` del rastro (`alto` si ≥1). Nunca se muestra.
- Tras `watson_expuesto`: voz B calla salvo HB10.

**Mycroft** no es agente libre: las reacciones `lado: mycroft` son órdenes permanentes ejecutadas por Cotter (voz A, una noche); no reexpide nada de Mary a Holmes.

**MoranAgent** (`st.react.moran`: `reports:[]`, `credit:bool`, `lost:bool`, `following:bool`, `delivered_holmes:bool`, `next_lines:[]`):
- `report_cats(item)`: asiento → por **valores** (`Validator.values_match` contra las conclusiones de `lists.report_cats`, aunque el fundamento sea falso); recorte → por `c:` heredadas, `visible_cats` del doc y clase del ejemplar (P → `original_p`). Nunca por `a:` ocultas.
- Disparos: `original_p` → M1 (retira **esos** originales 1 día; HB10 los devuelve) · `holmes_vive` → M2 · `watson_privado` → M3 (1.ª: HB9 aviso; 2.ª tras HB9 → `watson_expuesto`) · `moran_autor` (o presentar a Pell) → M4 · `camden`/`regreso_jueves` → M5 · `falso_verificable` → M9 (`moran_credito_perdido`) · `paradero_extranjero` → M12 (`holmes_entregado`) · `verdadero` en informes 1–3 → `moran_credito` · informe vacío → `informes_vacios += 1`.
- `go` a L3/L8 → M10 (línea en la próxima comunicación). Desde el día 5, columna con respuesta «—S.» a un anuncio de Lisle → M11 (una vez).

### 5.5 Guardado determinista (`event_log.gd` + `Game`; W1-ENG / W2-SIM)

- Archivo `user://saves/partida.jsonl` (= `.work/appdata/fe_de_erratas/saves/` por `godot.sh`). Línea 1: cabecera `{"v":1, "seed":int, "content":repo.content_hash(), "engine":"4.7.2"}`; luego una acción normalizada por línea (`J.stringify_canon`).
- Escritura: `J.write_atomic` (`.tmp` → renombrar el viejo a `.bak` → renombrar `.tmp`). `Game.act` escribe **antes** de devolver el resultado de toda acción C (Holmes no olvida, T25). Acciones libres: debounce 2 s y al cerrar.
- Carga: `EventLog.read` → `GameSim.replay(repo, seed, actions)`. Una última línea truncada se descarta (sólo puede ser una acción cuyo resultado no se mostró). `content` distinto → aviso «La partida se guardó con otra versión del texto» y se intenta igual.
- T9: `replay` dos veces → `state_hash` igual; `write → read → write` → bytes idénticos.
- W4: `GameSim.replay` aplica el registro **sin** la copia de reversión por acción (el registro ya fue aceptado; 1.500 acciones en < 3 s, T25); si alguna se rechaza, rehace todo con reversión (`_replay_safe`) y cuenta `replay_errors`. `Game.continue_session` guarda `partida.<hash12>.jsonl` (el registro tal como se leyó) antes de reescribir uno de otra versión o con rechazos. `WorldModel.check_eggs` es incremental (caché transitoria de etiquetas).

### 5.6 Invariante acotada (`core/graph/*`; W2-GRAPH; T1, T3, D1)

Modelo:
- **Fragmento** = `ref` de §4.8 resuelto por `RouteDB.frag`. **Máscara de disponibilidad** (29 bits, §3.2): bit `i` encendido si el fragmento se puede obtener en la franja `i`: ejemplar en lugar abierto en `i` (horario de `schedule.places` ∧ ventana `from/to` del ejemplar ∧ `when` del nodo/línea); lugares `free` (tienda de Crane) cuentan en cualquier franja con la tienda abierta; originales P en posesión: desde su llegada; escenas fijas: su tk; reacciones de columna: su tk en adelante (son P o I según su doc); garantizadas: desde el acto más temprano posible + latencia; diario: desde el primer acto posible del tipo.
- **Corte** = `{target, from_idx, to_idx}` derivado de `corta` + `efecto` (`CutModel.cuts_for`); un corte borra bits de la máscara. M1 (P, 1 día) borra sólo ese día; HB5 es permanente.
- Ruta intacta en `i` (peor caso: nada recortado) ⇔ cada fragmento tiene algún bit encendido en `[i, último índice útil de la conclusión]` tras los cortes. En runtime (D1) los fragmentos ya recortados por el jugador cuentan como obtenidos.
- Condiciones de T3 para cada conclusión obligatoria sin sellar en `i`: (1) ≥2 rutas intactas; (2) ≥1 sólo-I; (3) usando sólo rutas con `deps ∈ {fija, columna, garantizada}`; (4) ningún ejemplar/escena en todas las rutas usadas en (1), salvo `J:*`.

**Acotación de T3 (corre en segundos):**
1. *Monotonía:* los `agrega` no pueden romper la invariante (se ignoran); sólo cuentan cortes.
2. *Peor caso del jugador:* nada recortado.
3. *Descomposición por conclusión:* `K_C` = cortes cuyo objetivo toca algún fragmento de las rutas de C. Exigir `|K_C| ≤ 5` (si no, T3 falla y lo informa: hay que partir la conclusión o quitar cortes). Enumerar los `2^k` subconjuntos × momento de cada corte ∈ {más temprano, más tardío, más tardío + 1 por D2} → ≤ `4^5 = 1024` estados por conclusión × 23 índices de evaluación (P.N … 8.N: «hasta el día 8 inclusive», GDD§10.3; los días 9–10 los cubre D1 con los recortes reales) × ~5 rutas × ~4 fragmentos, todo con operaciones de bits sobre `int` → ~5,6 M operaciones en total para C2–C13. Control: además, la unión de todos los cortes posibles a la vez.
4. *Factibilidad global* (`feasibility.plan`): ¿existe un plan de visitas para completar ≥1 ruta ★ de **cada** conclusión con las franjas restantes? Unidades de visita = (lugar, área, ventana de franjas) requeridas por la ruta elegida (BM agrupa hasta 3 papeletas por visita; diálogos: ≤3 preguntas por personaje y visita). Búsqueda: conclusiones ordenadas por menor número de rutas ★; DFS sobre la ruta elegida por conclusión con poda; en cada nodo, *matching* bipartito incremental (Kuhn) unidades ↔ franjas abiertas; memo por (conclusión, máscara de franjas usadas). Recursos modelados: tarjeta HC04, consulta cerrada (HB4), Sala de Forasteros (HB12), chico del agente. Cota: 12 conclusiones × ≤3 rutas × ≤40 unidades × 25 franjas.
5. *Fuzzing sembrado:* `opts.fuzz` partidas con actos públicos al azar (`Det` con semilla del test), D1 activo, verificando la invariante real tras cada amanecer con el mismo código de D1. Por defecto 300 partidas (`-- --slow`: 10 000).
Presupuesto: T3 completo < 10 s en modo normal (medir `ms` y fallar si > 20 000).

D1 en runtime = paso 3 con el estado real (cortes ya aplicados + candidato; recortes del jugador como obtenidos) para las conclusiones tocadas por el candidato, desde la franja actual.

### 5.7 Diálogo, confrontación, compositores, finales (W2-SCENES)

- **Preguntar** (`ask`): tema = entidad del índice; `preview` arma la frase exacta (`ask_phrase[topic]` o `default`); ≤3 por personaje y visita (Crane: sin límite); la respuesta sale de `Dialogue.respond(char, visible)` con `visible = {topic, ents:[topic], kind}`. Al agotar: línea `closing`, sin contador visible.
- **Afirmar** (`assert`): cebos y canarios de `lists.assertions` disponibles cuando sus `requires` están en el índice; evento `say` con `bait_topic`/`canary`.
- **Presentar** (dos pasos en la UI; una acción en el sim): `visible = Clipper.visible(clip)` o, para un asiento, `{entry_values, ink, docs:[origen de sus recortes]}`; resultados especiales: Watson + `says_alive`/Mary → HB4 (1.º gesto + voz A; 2.º cierra la consulta 2 días, no el domingo); Mrs. Hudson → HB6; Pell + `moran_autor` → M4; Wiggins (pago o recorte de «the old scale of pay») → HB8; Mycroft tras su desafío (HC06 (g)) → HB12: éxito si es un asiento **sellado** de C6 o C7 que sigue siendo válido sin recortes de origen `S.HC06`; material `secreto_camden` = error sin leerlo; 1.er error tolerado, 2.º → `forasteros_cerrada`.
- **Confrontación** (GDD§8.8): 4 afirmaciones en orden con grupo refutador propio (`harris_es_moran`; `cornisa_existe|raspadura_registrada`; `ancla_*`; `librero_falso`); un ítem acierta si `Validator.entry_tags`/etiquetas del recorte contienen una del grupo; `{}` = callar (no es error); errores 1/2/3 → paquete / sombrero / se va (`confront_estado = incompleta`); 4 aciertos → nota en el tomo VI y `errata_ofrecida = librero` si Mycroft no la ofreció. Una sola vez (T18).
- **Compositores:** formas cerradas de `lists.ad_forms` (texto final visible; prohíben lugares de Londres y `secreto_camden`); telegramas/cartas con las mismas piezas (Meiringen → D27 al día siguiente; Bath → D28 a los 2 días); informes: 0–3 elementos, «Sin novedad», `quemar` (sólo final), `errata` (sólo final y con `errata_ofrecida`).
- **Finales:** `Endings.evaluate` a las 12 h del día 10 con lo sellado hasta el informe final, en el `order` de `endings.json`; variantes acumulables; `rank` para T10.

---
## 6. UI (todo construido por código; un solo Theme)

### 6.1 Reglas de UI limpia (GDD§14.1, `design.md`)

- HUD = sólo calendario de escritorio (fecha y franja) y monedas sobre la mesa. Nada más permanente en pantalla.
- **Prohibido:** brillos, contornos o resaltados de interés, contadores (tampoco preguntas restantes ni Marginalia), registro de misiones, medidor de sospecha, registro de reacciones, señal de suficiencia, *tooltips* que distingan lo importante, sonidos de alerta.
- Todo objeto visible se puede examinar y da al menos una línea neutra. Los epígrafes listan **todos** los sustantivos tocados.
- El juego explica la **forma** (chequeo formal en la voz de Lisle, `ui_text`) y nunca el **contenido**.
- Confirmación en dos pasos para todo lo comprometido que el jugador pueda lamentar (presentar, enviar, informe, sello); el texto final se ve antes de confirmar.
- Máximo 2 paneles apilados; animaciones ≤0,4 s, sin rebotes; respeta `ThemeInstaller.text_scale` y `high_contrast`; todo texto sale de `ui_text` o de datos.
- Mouse primero; atajos del input map (`fe_tijera` C, `fe_cuaderno` Tab, `fe_libro_mayor` L, `fe_mapa` M, `fe_volver` clic derecho/Esc, `fe_zoom_*` rueda, `fe_orbita_*` flechas).

### 6.2 Theme y fuentes (`autoload/theme_installer.gd`, `ui/kit/*`; W1-THEME)

- `install()`: por ranura de `fonts.json` → `FontFile.new()` + `load_dynamic_font(path)` (o `data = ThemeDB.fallback_font.data` si `"embedded"`), `allow_system_fallback = false`, `multichannel_signed_distance_field = true`, `fallbacks = []`; envuelta en `FontVariation` (máquina: `opentype_features = {"liga": 0}`; itálica sin archivo propio: `variation_transform` con inclinación 0,2). Instala `ThemeDB.get_default_theme().default_font`, `default_font_size` y `ThemeDB.fallback_font` (no `root.theme`: no se propaga bajo `CanvasLayer`/`Node3D`). `Label3D` del mundo usan `ThemeInstaller.font("imprenta")`.
- **Prohibido `SystemFont`** en `game/` (lint T21: la cadena no puede aparecer salvo en el propio lint, armada por concatenación).
- Variaciones de tipo (`theme_builder.gd`): `DocBody` (RichTextLabel: normal=imprenta, italics=imprenta itálica, bold=`FontVariation.variation_embolden = 0.6`, mono=máquina), `DocTyped`, `DocHand`, `SourceLine`, `Caption`, `PaperPanel`, `InkButton`, `InkTab`, `SlotSegun`, `Chip`, `StampLabel`, `Subtitle`.
- Papeles (StyleBoxFlat, `ui/kit/paper.gd`): `diario_hueso #ece3cf`, `strand #f0e8d6`, `diogenes_recortado #f3ead6` (crema), `telegrama #e6d3b0` (ante), `carta #f1ead9`, `registro #e9e2d0`, `libro_mayor #efe6d2` (renglones), `cuaderno #f2ecdc`. Tintas: `negra #1b1712`, `lapiz #4a4a4a`, `azul #2b4a8a` (lápiz de Holmes), `roja #8a2b22`, `tenue #8c8270`. Alto contraste: `#000` sobre `#fff`, conserva defectos de máquina y surcos (GDD§14.7).

### 6.3 Shell, entrada y arrastre (W3-SHELL)

- `ui/shell.gd`: crea capas (§2.3), `WorldRoot`, pila de pantallas (`push(panel)`, `pop()`, `top()`), escucha `Game.sim_changed`.
- `ui/input_router.gd`: `_input` → `fe_cuaderno` (Tab) salvo foco en `LineEdit/TextEdit` (se marca manejado antes del foco de la GUI); `_unhandled_input` → `fe_tijera`, `fe_libro_mayor`, `fe_mapa`, `fe_volver` (= `pop()`). W4: el **clic derecho** se toma en `_input` (antes que la GUI) y equivale a Esc; `GameScreen.front_back()` va antes de la pila (confirmación, tijera 3D, tarjeta de examen).
- Arrastrar y soltar = DnD nativo de Godot. Datos: `{"kind":"clip"|"pair"|"entry"|"ent", "id":…}`; vista previa = `Chip`. Destinos: tarjeta de recorte (→ `link`), libro mayor cerrado o pestaña «Nuevo folio» (→ `folio_open`), ranura «según» (→ `entry_support_add`), campo de plantilla (→ `entry_set`, sólo `ent`), sobre del informe, presentar.
- `DropCatcher3D` (capa 5: sobre el 3D y debajo de todo panel): `mouse_filter = IGNORE`; en `NOTIFICATION_DRAG_BEGIN` y fase `visit`/`scene`/`confront` pasa a `STOP`; `_can_drop_data` = `WorldRoot.pick_character(pos) != ""`; `_drop_data` abre la confirmación de presentar; en `NOTIFICATION_DRAG_END` vuelve a `IGNORE`.

### 6.4 Lector de documentos (`ui/reader/*`; W2-READER; GDD§14.3)

- `CanvasLayer` propio (capa 30), fuera del post-proceso. Muestra `Game.sim.q_view(view)`: título, línea de fuente, páginas; cada bloque es un `RichTextLabel` armado por `TextBuilder.build(rtl, parsed)` con `add_text`/`push_*`/`pop` siguiendo `parsed.styles` y `"\n"` como único separador (sin `[p] [ul] [table] [indent] [img]`). Test: `rtl.get_parsed_text() == parsed.plain`.
- `PageView`: geometría en milímetros (`px_por_mm × zoom`); zoom 80–300 % por `Control.scale`; la **regla** (`ruler.gd`) mide el papel (`paper_mm`) igual a cualquier zoom y, si el doc tiene `measure`, ofrece «Anotar la medida» → `clip_measure`.
- **Tijera:** sólo en modo tijera `selection_enabled = true`; siempre `drag_and_drop_selection_enabled = false`, `context_menu_enabled = false`, `shortcut_keys_enabled = false`, `threaded = false`. `SelectionMapper.map(rtl, parsed) -> {from, len}` con `from = get_selection_from()`, `len = get_selected_text().length()` (no `get_selection_to()`); verifica `parsed.plain.substr(from, len) == selected` (si no, busca la ocurrencia más cercana a `from` ±8). → `Game.act({"t":"clip_text",…})`; error → línea de Lisle (`ui_text`); éxito → la tira vuela al cuaderno.
- **Lupa** (`lens.gd`): segundo `RichTextLabel` 3× dentro de un panel recortado que sigue al mouse (mismo builder; no amplía la textura de pantalla).
- **Remington** (`fx_remington.gd`, `RichTextEffect`, `bbcode = "remington"`): estático (sin `elapsed_time`); carácter real vía `TextServerManager.get_primary_interface().font_get_char_from_glyph_index(char_fx.font, size, char_fx.glyph_index)`; «s» desplazada hacia arriba 0,08 em, «t» con alfa ×0,65, «e» girada 3°; *jitter* sembrado por `char_fx.range.x`; proporcional al tamaño; se conserva en alto contraste.
- **Luz rasante** (`rasante.gdshader`, `canvas_item`): *emboss* sobre la alfa del glifo con `uniform vec2 light_dir` que sigue al mouse; sólo bloques `<rasante>`; texto seleccionable; en alto contraste se muestra como texto tenue.
- Documentos con `plate` (D07, frontispicio de D10, Reichenbach) abren la lámina 3D correspondiente en vez de texto.

### 6.5 Cuaderno (`ui/notebook/*`; W3-NOTEBOOK)

Pestañas: **Recortes** (búsqueda por texto; filtros por persona, lugar y fecha **de la crónica** con chips del índice; agrupado por calendario de la crónica; tarjeta = texto o miniatura, epígrafe de entidades, línea de fuente), **Índice** (alfabético por `index`; clic filtra recortes; los chips se arrastran a campos y a preguntar), **Cotejos** (pares de recortes: tarjetas con nota libre), **Diario** (D36, recortable con tijera), **Marginalia** (notas de huevos de pascua, sin contador). Abre con Tab.

### 6.6 Libro mayor (`ui/ledger/*`; W3-LEDGER) — RETIRADO en v3: lo reemplaza el Expediente (`ui/expediente/*`, GDD_v3 §6.1)

Páginas: «Reglas del asiento» (texto fijo de GDD§8.0), «Varios», folios (encabezado = recorte que lo abrió), «Erratas inocentes» (práctica C1 con sello propio). Asiento: líneas de la plantilla con campos «Campo: ___» (soltar chips del índice; listas cerradas por menú) y una ranura «según» por línea; mensajes del chequeo formal en la voz de Lisle junto a la línea. Sello «Visto»: el jugador marca exactamente `lot_size` asientos a lápiz y estampa → animación de tinta (rasguido, secante, golpe) o golpe seco; el tampón se ve seco mientras `passes_left == 0`. Abre con L.

### 6.7 Mapa, escritorio, escenas y compositores (W3-SHELL, W3-SCENEUI)

- **Mapa** (`ui/map/*`): dibujado por código desde `map.json` (paleta de Booth, calles, Támesis); lugares cerrados con persiana y sin clic (T26); página Baedeker pegada (abre en el lector); viajar → `go` → 3 s de cascos (clic para saltar) → visita.
- **Escritorio** (`ui/desk/*`): tres encuadres (escritorio, ventana, pared); objetos clicables: bandeja, tomos (D01), cajón (D02), concordancia (D21), mapa, calendario (cerrar la franja = `end_slot`, con confirmación), tijera, lupa, regla, sello, estufa, ventana (Wiggins, el chico de Pell), escalera a la tienda de Crane (estantes → lector).
- **Escena** (`ui/scene/*`): personajes presentes (nombre sólo si se presentó); «Preguntar» (temas del índice), «Afirmar» (cebos/canarios disponibles); antes de hablar se ve la frase exacta de Lisle y se confirma; las líneas aparecen como texto recortable. «Presentar»: soltar sobre el personaje → frase → «Mostrar» / «Guardar». Mycroft: (a)–(f) automáticas, luego el desafío (g). Confrontación: afirmación del librero, ranura, «Callar», paciencia visible (paquete, sombrero).
- **Compositores** (`ui/compose/*`): formas cerradas con selectores (listas o chips) y el texto final completo antes de «Enviar»; informe: sobre con 3 ranuras, «Sin novedad»; final: «Quemar» y «Errata a medida» sólo si corresponde.
- **W4 (playtest):** nota del instructor en una capa propia (25) con *dock* junto a los libros y menciones clicables (espera a que termine la presentación); bandeja una vez por día con papeles (el día 10, antes de la confrontación); «Tijera sobre la tienda» en la confrontación (`confront` cuenta como banda); copia certificada desde la tarjeta de examen del documento de L6 («Pedir copia certificada (un chelín)», en dos pasos); catálogo: «Pedir» en toda ficha y **toda papeleta se gasta** (ficha de ruido o fuera de ventana: `{t:slip, doc:"", noise}` / view `""`, «No está en los estantes hoy, señor»); marcadores del mapa con prioridad del abierto; título sin «Continuar» cuando el registro termina en `<save>.fin`; `Shell.go_epilogue`; epígrafe por área (`places.epigraph_by_area`, p. ej. L4 estudio el domingo).

- **v2 (integración del playtest; prevalece sobre lo anterior):** sin lupa ni regla (ni en el escritorio ni en el lector: la línea de **descripción física** de cada documento, en tinta tenue, `core/text/fisica.gd`); HUD = calendario, tira «Pendientes» (viñetas; plegada a los 4 s en la primera línea, se despliega al pasar el mouse) y cintas «Cuaderno», «Libro de conclusiones» y **«Plano» (M)** con sus banderas (el plano sólo en el escritorio); la nota del instructor vive en la capa **35** (encima del lector) y con el lector abierto se acopla en su margen izquierdo, bajo la ficha del documento; el lector muestra una ayuda de la tijera hasta el primer recorte. **Nombres a la vista**: `Index.label()`/`q_index().label` = nombre natural (`Index.display`: el `name` de la entidad sin artículo, con mayúscula: «Doctor Watson», «Times del 27 de marzo»); la forma de catálogo (`index`: «Watson, John H., doctor») sólo ordena y es la que muestra y agrupa por letra la pestaña «Índice» del cuaderno (`q_index().index`). Los destinos del telegrama y la carta excluyen a Lisle. El chequeo formal del borrador usa el de la práctica (pasajes) mientras la práctica del día 1 está pendiente (`q_entry`; confirmar sigue con el normal). Las siluetas con las que se habla dicen dónde están («Muchacho con gorra (afuera)», `silhouettes.<id>.where`). La plantilla al azar de una reacción no repite la última de esa misma reacción.

---

## 7. 3D (W1-3D motor; W2-PLACES-* lugares; W1-POST estilo)

### 7.1 `WorldRoot` (`world/world_root.gd`, Node3D)

```gdscript
signal node_clicked(node_id: String)
signal character_clicked(char_id: String)
signal empty_clicked(screen_pos: Vector2)
func show_hub(frame: String, slot: String) -> void
func show_plate(snap: Dictionary, place: Dictionary) -> void      # snap = sim.q_plate()/q_visit_plate(); place = repo.place()/plate()
func set_frame(id: String, instant := false) -> void
func frames() -> Array
func set_orbit_enabled(on: bool) -> void
func pick(screen_pos: Vector2) -> Dictionary                      # {kind:"node"|"char"|"none", id}
func pick_character(screen_pos: Vector2) -> String
func rect_clip(rect: Rect2) -> Dictionary                         # {hits:[{node,cover,tight}], touched:[...], area_frac}
func prewarm(place: Dictionary) -> void                           # render una vez detrás del fundido (pipelines)
func current_plate() -> String
```

### 7.2 `DioramaBuilder.build(place: Dictionary, snap: Dictionary) -> Node3D`

Hijos: `Props` · `Occluders` (StaticBody3D, capa 1, cajas `meta.occ` de cada prop) · `Nodes` (por nodo presente en `snap.nodes`: StaticBody3D capa 2 con `BoxShape3D` = `anchor`; `meta node_id`, `noun`) · `Chars` (maniquíes, StaticBody3D capa 4, `meta char_id`) · `Lights` (preset de la franja) · `Frames` (Marker3D con `meta fov/orbit`) · `Env` (WorldEnvironment). Siluetas (`sil_<who>`) son nodos (capa 2) con maniquí.
Props: `type "<módulo>.<función>"` → `load("res://world/props/<módulo>.gd").build_<función>(p)`; devuelve Node3D con `meta "occ": Array[AABB]` (local). Sólo `PrimitiveMesh` (Box, Cylinder, Sphere, Capsule, Prism, Torus, Quad); CSG sólo para vanos y arcos: `CSGCombiner3D` → `bake_static_mesh()` → `MeshInstance3D`, y se libera el CSG. Variación determinista por `p.seed` y `Det` (sin `randf`). Materiales compartidos `Materials.get(id)`.

Biblioteca base (W1-3D):

| módulo | funciones (`build_*`) y parámetros principales |
|---|---|
| `furniture` | `desk(w,d,h,drawers)` · `table(w,d,h,round)` · `chair(style)` · `armchair(wing)` · `bookshelf(w,h,rows,fill,gap{row,from,to},seed)` · `counter(w,d,h)` · `stool` · `bed(w,d)` · `stove(h)` · `fireplace(w,h,mantel)` · `coat_stand(hat)` · `reading_desk_radial(n,r)` · `index_shelves(w,h)` · `cabinet(w,h,d)` · `crate(w,h,d,label)` |
| `architecture` | `room(w,d,h,openings[{wall,kind,x,w,h,sill}],slope?)` · `attic(w,d,h,slope)` · `sash_window(w,h,open_frac,panes)` · `door(w,h,open_frac)` · `facade(w,h,floors,bays,door_bay,shop_front,style:"stock_brick"|"estuco")` · `dome(r,ribs)` · `stairs(n,w,rise,run)` · `railing(len,h)` · `eave(len,depth)` · `arch(w,h)` |
| `street` | `gas_lamp(h,light)` · `wall_lamp` · `cab(kind:"hansom"|"growler")` · `crocus_bed(w,d)` · `lawn_strip(w,d)` · `sign_board(text_key)` (Label3D) · `kiosk` · `pavement(w,d,kind:"madera"|"granito")` · `post_box` |
| `small` | `book(w,h,t)` · `book_pile(n)` · `tome_set(n)` · `paper_stack(n)` · `letter` · `envelope` · `basket_strips` · `ash_pile` · `scissors` · `ruler` · `lens` · `stamp` · `ink_pot` · `clock_mantel` · `coins` · `tray` · `desk_calendar` · `map_board` · `tobacco_tin` · `photo_frame` · `open_ledger_book` · `lantern` |
| `plates` (W2-PLACES-C) | `reichenbach(variant:"fina"|"journal"|"foto")` (sendero, pared, precipicio, cascada, cornisa, marca) |

Materiales (`world/materials.gd`, albedo cálido casi monocromo; el grabado cuantiza): `madera_oscura #5a4632`, `madera_clara #8a7050`, `papel #e8dcc0`, `yeso #cfc6b4`, `ladrillo_stock #9a8a6a`, `ladrillo_hollin #4a4036`, `piedra_portland #bdb7a8`, `hierro #2e2c2a`, `laton #a08040`, `paño #3a3a3e`, `cuero #5a3a2a`, `vidrio` (alfa 0,25), `gas_emisivo` (emisión ámbar). `roughness 1`, `metallic 0`.

### 7.3 Lugares (GDD§5; cada WP de lugar posee su `places/L#.json`, `plates/*.json` y `world/props/l#.gd`)

Cada lugar: 2–4 encuadres (hub L1: escritorio, ventana, pared; sin órbita en el hub), todos los objetos de GDD§5 como props, cada objeto examinable con `examine`, los nodos del contrato §4.8 con sus ids exactos, siluetas (`wiggins`, `m3_hombres` en L4, `cochero`) en posición visible, personajes con `when`. Luz: L2 eléctrica fría; L5 silencio (sólo papel); L7 día 10 18 h dorada rasante; L8 farol de la calle; tienda de Crane con gas (`OmniLight3D` bajo: la sombra del librero llega al techo; su nodo lo dice en `examine`).

### 7.4 Maniquíes (`world/characters/mannequin.gd`)

`Mannequin.make(char_id: String, trait: String, pose: String) -> Node3D` (piernas cilindro o falda cono, torso cápsula, cabeza esfera, brazos cápsula; poses `de_pie`, `sentado`, `encorvado`, `apoyado`). **Un rasgo legible en silueta** (GDD§4):

| trait | quién | forma |
|---|---|---|
| `bombin_crespon` | Watson | bombín (cilindro + toro) con banda |
| `esfera_panuelo` | Mycroft | torso esférico grande, pañuelo (prisma) |
| `fajo_bajo_brazo` | Cotter | delgado, fajo de papel (caja) bajo el brazo |
| `cofia` | Mrs. Hudson | falda cono, cofia (disco) |
| `gorra_larga` | Wiggins | gorra con visera larga, joven alto |
| `chistera_bigote` | Harris/Moran | chistera de ópera, bigote enorme (dos cápsulas) |
| `cartera` | Pell | cartera (caja) en la mano |
| `mangas_ligas` | Crane | mangas abullonadas con bandas, lápiz en la oreja |
| `bajo_agachado` | Parker | 1,55 m, encorvado |
| `joroba_libros` | librero | joroba, patillas blancas, pila de libros |
| `abrigo_cochero` | hombre de M11 | abrigo con esclavina, sombrero bajo |
| `dos_bombines` | hombres de M3 | dos figuras apoyadas |

Verificación: `devtools/drivers/w13d_siluetas.gd` captura cada maniquí sobre fondo liso, binariza y exige IoU por pares < 0,85.

### 7.5 Cámara (`world/camera_rig.gd`)

Encuadres fijos con transición 0,5 s (ease in-out). En lugares: órbita corta (yaw ±`orbit.yaw`, pitch ±`orbit.pitch`, por defecto 25°/10°) alrededor del `pivot` arrastrando con el botón izquierdo sobre el vacío (umbral 6 px: si no, es clic) o con flechas; rueda = FOV ±10°. Examinar: clic en nodo → la cámara encuadra el `anchor` (distancia según tamaño) y orbita alrededor de él; `fe_volver` regresa.

**v2 (GDD_v2 §E; prevalece sobre lo anterior).** Sin chevrones. Pila de poses `[general] → [zona] → [examen]` (`push`/`back()`; clic derecho o Esc bajan un nivel; transición 0,45 s; giro y FOV suavizados `x += (obj − x)·(1 − e^(−12·dt))`). Vista general por área en `world/camera.json` (no en `data/`: DataRepo rechaza archivos desconocidos): `{"<lugar>.<área>": {overview: {pos, look, fov, yaw, pitch}, zones: {nodo: encuadre}}}`; `"yaw" ≥ 180` = **vuelta entera** (buhardilla y tienda: la puerta a la tienda y la vidriera quedan a la espalda; `rig.wraps()`), si no, tope ±yaw. Lugares sin general propia (`"*": first_frame`): cada encuadre es una **estación** (órbita de su encuadre acotada a 1,8 m de arco); empujar contra el límite `PUSH_S` = 1 s pasa a la vecina (`station_ring`) y un clic en un nodo lejano lleva a la estación que mejor lo ve. Bandas del borde (8 % / 10 %, 0,15 s, 45 °/s, nunca sobre la interfaz, con un panel, la tijera o un arrastre; opción «Girar la vista con los bordes»), arrastre, flechas y rueda hacia el cursor. La pantalla de juego (`ui/desk/game_screen.gd`) agrega: botón «‹ Alejarse» (tooltip «Clic derecho o Esc») mientras la cámara está acercada; un clic en el vacío o cerrar el panel abierto desde un objeto bajan un paso; en el prólogo, al cerrar un panel, la vista vuelve al escritorio. Afordancias (`world/affordance/*`, §D): códigos en la rugosidad leídos del canal A de `normal_roughness` (1,00 escenario · 0,9725…0,949 examinable · 0,9325…0,909 usable · 0,88 bajo el mouse; Godot 4.7 guarda la rugosidad tal cual), quad de contornos sobre el look, cursores dibujados (`ui/desk/cursors.gd`, liberados al salir) y etiqueta (`ui/desk/hover_label.gd`: no tapa el HUD ni la banda; se rearma si el mouse se mueve rápido; con Espacio, una por examinable, recalculadas mientras la vista gira). La aguada lava menos (`obj_soften` 0,5) y lleva más pluma (`obj_line` 1,3) en todo lo examinable por igual (§D.4).

### 7.6 Selección y recorte por rectángulo (`picker.gd`, `rect_clip.gd`)

- Clic: `project_ray_origin/normal` → `intersect_ray` (máscara capas 1|2|4) → primer impacto; nodo → `node_clicked`; personaje → `character_clicked`.
- Rectángulo (modo tijera en 3D): la UI limita el área a ≤1/8 del *viewport*. Por cada nodo de la instantánea: proyectar las 8 esquinas del `anchor` (`unproject_position`; descartar `is_position_behind`) → rectángulo A; `cover = área(A ∩ R) / área(A)`; oclusión: 5 puntos del `anchor` (centro y 4 centros de cara hacia la cámara), rayo desde la cámara; ocluido si en los 5 el primer impacto no es su cuerpo; `tight = área(R) ≤ 3 × área(A ∩ viewport)`. Requiere un `physics_frame` tras construir. Devuelve hits ordenados por `cover` (el sim aplica los topes).
- Headless (tests): `root.size = Vector2i(1600, 900)` fijo antes de proyectar (el headless arranca en 64×64).
- Miniatura: opcional, sólo de sesión; la lógica nunca depende de ella.

### 7.7 Iluminación por franja (`world/lighting.gd`; W1-POST)

Presets `manana_perla`, `dia_ventana`, `tarde`, `gas`, `farol_calle`, `electrica_fria`, `dorada_parklane`, `noche_viento`: `DirectionalLight3D` (color, energía, ángulo), ambiente (`Environment`), `OmniLight3D` en props con `light:true`; sombras sólo donde son pista (tienda de Crane). `noche_viento`: parpadeo de faroles (animación visual; puede usar tiempo real porque no es lógica). Tonemap lineal, sin glow ni SSAO (el grabado manda). W4-STYLE: `Lighting.preset_for(place, slot, snap)` recibe la instantánea (DioramaBuilder ya la pasa): `place.light["<día>.<franja>"]` gana sobre la franja (luz por día; noche del 5) y sin `snap` no hay excepciones por día.

### 7.8 Post-proceso de grabado (`world/post/*`; W1-POST; GDD§14.5)

`engraving_post.gd` cuelga de la `Camera3D` activa un `MeshInstance3D` con `QuadMesh` 2×2, `extra_cull_margin = 16384`, sin sombras, con el `ShaderMaterial` del look activo (por defecto `looks/aguada.gdshader`, elegido por el usuario; `looks/grabado.gdshader` = alternativa en Opciones). Lo que sigue describe el grabado; la aguada (lavados por cara, pluma en siluetas y pluma fina de cerca, hilo de papel, papel por franja y tinta por preset) está documentada en la cabecera de `looks/aguada.gdshader` y en `looks/aguada.json`:
- `shader_type spatial; render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;` vértice `POSITION = vec4(VERTEX.xy, 1.0, 1.0);`
- `hint_screen_texture`, `hint_depth_texture` (profundidad lineal vía `INV_PROJECTION_MATRIX`), `hint_normal_roughness_texture` (sólo Forward+).
- Contornos por discontinuidad de profundidad y normal (4 vecinos); trama **Bayer 8×8** procedural anclada a una esfera centrada en la cámara, celda derivada del FOV y del alto del *viewport*; grano de papel por *hash*; salida `mix(paper, ink, máscara)`.
- Uniforms: `paper` (por franja: mañana `#e8e6e0`, tarde `#efe6d2`, noche `#ecd9b4`), `ink #1b1712`, `edge_depth`, `edge_normal`, `cell_px`, `grain`. Alternativa sepia = sólo cambiar `paper/ink` (GDD§16.3).
- Looks intercambiables (`looks.gd`): cada `looks/<id>.gdshader` + `looks/<id>.json` se descubre solo ('grabado' = `"base": "lighting"`, sus parámetros siguen en `lighting.gd`); se elige con `--look=<id>` (sesión) u Opciones «Estilo de imagen» (persistente), default `Looks.DEFAULT` = `aguada` (sólo existen `aguada` y `grabado`); comparar: `LOOK=<id> ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn look res://devtools/drivers/look_compare.gd` (6 tomas fijas → `.work/shots/look_<id>_<n>.png`) y `./godot.sh --headless -s devtools/contact_sheet.gd -- <id>` (→ `sheet_<id>.png`); recorrido completo (L1-L8, láminas y franjas): `SET=todo LOOK=<id> …look_compare.gd` (30 tomas, hojas `<id>-t1…t5`).
- T27: los shaders de los looks compilan en headless (el renderer *dummy* de 4.7 sí reporta errores de shader al `Logger`); calibración con ventana del grabado: plano gris 0,5 a 5 m → gris medio esperado ±0,06 en la captura; aguada con ventana: tono monótono con blancos reservados, presets legibles, objetos del color de la mesa separados (pluma fina + hilo de papel), sin pluma falsa en piso rasante, siluetas en tono continuo ≥ 0,08, Opciones con clics reales.

---

## 8. Audio procedural (`audio/*`, `autoload/audio.gd`; W1-AUDIO; GDD§14.6)

- Todo `AudioStreamWAV` 16 bits mono 44,1 kHz generado una vez (`Audio.warm()`), determinista (RNG propio LCG sembrado por id; no `randf`). Sin `AudioStreamGenerator`. Bucles: generar duración + fundido, mezclar la cola en la cabeza con *crossfade* de igual potencia, `loop_mode = LOOP_FORWARD`, `loop_end`.
- `audio/synth.gd`: ruido blanco/rosa/marrón, biquad LP/HP/BP, envolventes (ADSR, decaimiento exponencial), osciladores (seno, sierra, FM), mezcla, normalización, `to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV`, `make_loop(samples, fade_s)`.
- `audio/proc_audio.gd`: `static func gen(id: String) -> AudioStreamWAV` (despacha a recetas). `audio/sound_bank.gd`: `const BANK = {id: {recipe, dur, loop, gain}}`.
- Autoload: buses `Amb` y `Sfx`; dos reproductores de ambiente con fundido cruzado; *pool* de 8 `AudioStreamPlayer`; eventos sueltos con `AudioStreamRandomizer`. Cada `play` emite `subtitle(caption)` si `subtitles_on` (por defecto encendido); el subtítulo describe sin interpretar («arpa de boca, lejos»).

| id | receta |
|---|---|
| `sfx.tijera` | dos transitorios: ruido BP 3–6 kHz 25 ms + anillo metálico 2,1/3,4 kHz decaimiento 60 ms |
| `sfx.papel` / `sfx.pagina` | ruido rosa en granos 10–40 ms con amplitud aleatoria, HP 800 Hz (0,6 s / 0,9 s) |
| `sfx.plumin` | ruido HP 2,5 kHz × modulación *stick-slip* 30–60 Hz, 1,2 s |
| `sfx.secante` | ruido LP 300 Hz, presión suave 0,4 s |
| `sfx.sello` / `sfx.sello_seco` | seno 70 Hz con decaimiento 120 ms + clic 5 ms + cuerpo de madera BP 400 Hz (seco: más corto y agudo) |
| `sfx.sobre` | deslizamiento de papel 0,5 s + golpecito |
| `evt.persiana_crane` | serie de 8 clics + ruido LP (el golpe de Crane al abrir) |
| `evt.lechero` | dos pasos de casco + tintineo de botellas (senos 2,4 kHz cortos), 3 s |
| `bells.st_clement` | campana aditiva inarmónica (parciales ×0,5, 1, 1,183, 1,506, 2, 2,514, 2,662, 3,011, 4,166 con decaimientos propios), repique de 4 campanas, 6 s |
| `clock.cuartos` | frase de 4 notas con timbre de campana, 4 s |
| `clock.tic` | tic 1 Hz, bucle 2 s |
| `hooves.madera` / `hooves.granito` | golpe LP 150 Hz + ruido 30 ms en pares a 3,2 Hz (granito: BP 1,5 kHz + anillo de hierro 2,8 kHz), 3 s, variantes por Randomizer |
| `harp.parker` | sierra 98 Hz por BP resonante barrido 400–1600 Hz con LFO; envolvente de pellizco; 2,5 s |
| `whistle.policia` | senos 2100/2500 Hz con trémolo 30 Hz, 1,5 s |
| `shot.silbido` | ruido HP barrido 6 kHz → 1 kHz en 150 ms |
| `glass.tintineo` | ~60 micro-campanas (parciales 3–9 kHz, 50–200 ms) dispersas en 1,2 s: «a long, silvery tinkle» |
| `evt.ladrillo` | golpe LP + granos de derrumbe (M2) |
| `evt.golpe_puerta` | tres golpes de madera |
| `amb.calle` | bucle 8 s: ruido marrón LP + murmullo AM + cascos lejanos horneados |
| `amb.gas` | bucle 4 s: siseo HP 4 kHz muy bajo con aleteo lento |
| `amb.sala_lectura` | bucle 8 s: ruido 200–800 Hz muy bajo + páginas ocasionales |
| `amb.diogenes` | bucle 6 s: tono de sala a −48 dB + papel raro |
| `amb.tienda` | bucle 6 s: reloj + calle amortiguada |
| `amb.viento` | bucle 8 s: ruido por BP con LFO 0,1–0,3 Hz (200–900 Hz) + ráfagas (noche del 5) |
| `amb.parque` | bucle 8 s: multitud lejana + gorjeos (senos con *chirp*) (Park Lane, día 10) |

T28: `md5` de `stream.data` de cada id coincide entre dos generaciones en el mismo proceso y con `tests/fixtures/audio_hashes.json`; banco completo < 2 s.

---
## 9. Tests y bots

### 9.1 Arnés (W1-ENG; `tests/run_tests.gd`, `tests/test_base.gd`)

- `_init` sólo programa `_run.call_deferred()` (los autoloads existen recién después: verificado en 4.7.2).
- `Logger` (`OS.add_logger`, subclase con `_log_error(function, file, line, code, rationale, editor_notify, error_type, script_backtrace)`): todo error de tipo ERROR/SCRIPT/SHADER durante un test lo hace fallar, salvo `expect_error(substr)`. Las advertencias no cuentan.
- *Watchdog* por test (30 s; `const TIMEOUT_S` lo cambia): cancela tests con `await` colgados. Los tests síncronos deben tener bucles acotados.
- CLI (tras `--`): `<filtro>` (subcadena del archivo) · `--list` · `--slow` (habilita `const SLOW := true` y el fuzzing completo de T3) · `--window` (sólo tests con `const WINDOW := true`; correr **sin** `--headless`). Sin `--window`, los tests `WINDOW` se saltan.
- `test_base.gd` agrega: `skip(reason)`, `expect_error(substr)`, `near(a, b, eps)`, `tmp_dir() -> String` (`.work/tests/<archivo>/`, creado y vaciado), `repo()` (data real, cacheado), `fixture_repo(name := "data_min")`, `content_strict() -> bool` (`tests/content_gate.json`), `pending_content(msg)` (= `skip` si no es estricto, `fail` si lo es).
- Salida: `PASS|FAIL|SKIP archivo::test` + `TESTS: n run, f failed, s skipped`; código de salida 0/1.

### 9.2 Mapa de tests

| test | archivo | dueño | qué verifica |
|---|---|---|---|
| T00 | `test_t00_compile_all.gd` | W1-ENG | todo `.gd` de `res://` (salvo `tests/fixtures`) carga sin null |
| T01 | `test_t01_routes.gd` | W2-GRAPH | ≥2 rutas sólo-I sin ejemplar común; ≥2 orígenes; enlace por claves; «desde» antes de la última pasada; C6 por pares |
| T02 | `test_t02_static_cuts.gd` | W2-GRAPH | ningún efecto toca un ejemplar I ni cierra la única fuente de un fragmento I (D9) |
| T03 | `test_t03_invariant.gd` | W2-GRAPH | invariante acotada §5.6 (<10 s; `--slow` 10 000 partidas) |
| T04 | `test_t04_max_clips.gd` | W2-DED | ningún recorte legal máximo (oración ≤40 palabras, par de nodos) cubre todos los grupos de una conclusión |
| T05 | `test_t05_footprint.gd` | W2-GRAPH | ley de la huella (Holmes → C6/C7/C8; Moran → C10/C13); T5' cortes derivados ⊆ `corta[]`; HB11 exige 2 reacciones previas del canal |
| T06 | `test_t06_templates.gd` | W2-DED | rótulos «Campo: ___» sin artículo/flexión fuera; sin presuposiciones; listas cerradas comunes |
| T07 | `test_t07_knowledge.gd` | W2-STRUCT | fechas y días de semana; `knowable`; Moran–Adair no antes del día 8; ningún paradero público de Holmes en 1894; poder de Mycroft no público; anacronismos; `src_en` contra `fixtures/canon`; ningún ⚠ en rutas/refutaciones |
| T08 | `test_t08_blindness.gd` | W2-REACT | mismo registro de actos públicos + distinto cuaderno → mismas entregas |
| T09 | `test_t09_determinism.gd` | W2-SIM | replay ×2 = mismo `state_hash`; guardar→cargar→guardar = bytes idénticos |
| T10 | `test_t10_bots.gd` | W3-BOTS | ningún bot supera el `rank` del deductor; pasivo → F4; pesca ≤5 %; duración del Acto III (novato) |
| T11 | `test_t11_pacing.gd` | W2-REACT | ≤1.000 palabras nuevas por mañana; ≤2 franjas sin material; ≤1 disparada fuerte por mañana (exenciones D2) |
| T12 | `test_t12_actor.gd` | W2-REACT | actor físicamente posible por lugar y fecha (D8) |
| T13 | `test_t13_eggs.gd` | W2-STRUCT | huevos sin etiquetas C2–C13 ni fragmentos de ruta |
| T14 | `test_t14_static.gd` | W1-ENG | `create_folio(` sólo en `player_actions.gd` (y su definición) |
| T15 | `test_t15_ley2.gd` | W2-REACT | contadores por tema; garantizadas deterministas, sin condiciones extra, no bloqueables |
| T16 | `test_t16_hb13.gd` | W2-REACT | HB13 sin etiquetas de C2–C5 ni C8–C13 |
| T17 | `test_t17_false_leads.gd` | W2-GRAPH | toda pista falsa con ≥2 refutaciones alcanzables, ninguna ⚠ |
| T18 | `test_t18_confrontation.gd` | W2-SCENES | un grupo por afirmación, callar no cuenta, ≤3 errores, una vez |
| T19 | `test_t19_selection.gd` (+ driver `w2reader_t19.gd`) | W2-READER | `map(from, seleccionado) → tramos`; integración con ventana 1600×900 |
| T20 | `test_t20_dialogue.gd` | W2-SCENES | todo personaje × entidad del índice → línea; T20b ceguera del diálogo |
| T21 | `test_t21_fonts.gd` | W1-THEME | lint de `SystemFont`; `allow_system_fallback = false` en runtime; cobertura de glifos |
| T22 | `test_t22_camden.gd` | W2-REACT | ninguna etiqueta `secreto_camden` llega al Holmes-agente ni a Mycroft |
| T23 | `test_t23_secret.gd` | W2-REACT | nada público con `afirma_que_vive`; nada público cita K-W; ninguna frase pública traduce «not literally true» |
| T24 | `test_t24_ramp.gd` | W3-BOTS | el novato toca cada verbo en contexto guiado o gratuito antes de su primer uso con costo |
| T25 | `test_t25_save.gd` | W2-SIM | «matar» tras pasada fallida, error ante Mycroft y respuesta en la confrontación; al recargar figuran |
| T26 | `test_t26_map.gd` | W2-SIM | ningún clic gasta franja en un lugar cerrado |
| T27 | `test_t27_shaders.gd` | W1-POST | shaders compilan (headless); calibración del grabado (`WINDOW`) |
| T28 | `test_t28_audio.gd` | W1-AUDIO | hash PCM estable |
| T29 | `test_t29_dioramas.gd` | W1-3D (lugares: W2-PLACES) | `examine` en todo nodo; Wiggins en frustum y sin tapar desde el día 3; línea de tiro recortable sola |
| T30 | `test_t30_fisica.gd` | v2 DESPEJE-UI | descripción física en todo documento y plantilla; formato fijo; sólo D46 y la Remington con etiquetas; `D46#fisica` y `R:HA1.fisica` se resuelven |
| T31 | `test_t31_ui_reveal.gd` | v2 DESPEJE-UI | revelado progresivo por vista con `q_ui()`; cinta «Plano» y Pendientes plegable |
| T32 | `test_t32_camera.gd` (+ `_window`) | v2 CÁMARA | límites, suavizado, pila de poses, bandas del borde, estaciones, alcance de nodos; puerta y plano alcanzables girando; con ventana y mouse real |
| T33 | `test_t33_style.gd` (+ `fixtures/style_exceptions.json`) | v2 TEXTOS-UI | estilo neutro/argentino: sin vosotros, peninsularismos, latinismos ni jerga; glosario §A.1 en ui_text y PRO; botones ≤3 palabras |
| T34 | `test_t34_affordance.gd` (+ `_window`) | v2 AFORDANCIAS | códigos 1/2/3 en la rugosidad; contorno, etiqueta y cursor con mouse real; «‹ Alejarse»; etiquetas que siguen el giro; §D.4 de la aguada |

Tests unitarios `test_u_<módulo>.gd`: dueño = dueño del módulo. Cada WP de ola 2 usa fixtures propios (`tests/fixtures/<wp>/`) para no depender del contenido; los T-tests sobre `res://data` informan faltantes con `pending_content`.

### 9.3 Bots (`devtools/bots/`; W3-BOTS)

```gdscript
# bot_base.gd
extends RefCounted
var sim                                  # GameSim
var seed: int
var stats := {}                          # {acts, steps, words_read, passes, sealed:[...], franjas}
func setup(p_sim, p_seed: int) -> void
func step() -> bool                      # una decisión (≥1 apply); false = terminó
func play(max_steps := 20000) -> Dictionary   # {ending, rank, sealed, words_read, est_minutes, acts, steps}
func act(a: Dictionary) -> Dictionary    # sim.apply + estadística; un ok:false es fallo del bot salvo en bots «al azar»
func read(view: String) -> void          # cuenta palabras leídas (q_view)
func clip_ref(ref: String) -> String     # sólo oráculo (deductor): recorta el fragmento de contrato §4.8 desde su ejemplar
```
Bots: `bot_deductor` (oráculo de rutas ★; mínimo de franjas; crédito ante Moran; errata a medida), `bot_novato` (sólo verbos ya enseñados; lee todo; minutos = palabras/180 × 1,3), `bot_pasivo`, `bot_pesca` (fundamentos correctos, valores al azar), `bot_fuerza_bruta`, `bot_recorta_todo` (recortes legales máximos de todo lo accesible), `bot_cebo` (cebo diario), `bot_informa_todo`, `bot_solo_bm`, `bot_confront_azar`, `bot_mycroft_azar`. Azar = `Det` con la semilla del bot.
W4: `idle_until_day`; `play_minutes` / `play_minutes_act` (minutos de juego = lectura + `T_ACT` por acto aceptado + `T_THINK_PER_SEAL` por asiento sellado); papeletas **sólo por el catálogo** (una entidad del índice cuya búsqueda lista el documento); `bot_guion` (juega un guion de `devtools/scripts/`).
CLI: `./godot.sh --headless -s devtools/bots/run_bots.gd -- <bot> <n_partidas> [semilla]` → JSON de estadísticas. `devtools/play_cli.gd -- --script res://… | --doc D05 | --state` para que los agentes jueguen el sim por texto.

### 9.4 Capturas

`./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn <prefijo> res://devtools/drivers/<wp>_<nombre>.gd` (sin `--headless`; la RTX 3060 Ti renderiza Forward+). El driver define `func drive(tool, scene) -> void`, arma lo que necesita como hijo de `scene` y llama `await tool.frames(n)` / `await tool.snap("nombre")` → `.work/shots/<prefijo>_<nombre>.png`. Revisar cada PNG con la herramienta de lectura de imágenes antes de declarar un criterio visual cumplido. Para pantallas completas: `res://main.tscn` con args de usuario `--screen=…` / `--script=…` (main.gd los lee).

---

## 10. Paquetes de trabajo

Reglas comunes: cada WP sólo crea/edita los archivos que **posee**; usa las APIs de §3 tal cual; corre la suite (`./godot.sh --headless -s tests/run_tests.gd`) y no rompe tests ajenos; entrega en su respuesta final: archivos tocados, tests corridos y resultado, rutas de capturas, diffs propuestos a archivos ajenos y flags/campos nuevos propuestos. Prohibido todo lo de `CLAUDE.md` (nada fuera de `C:\Dev\books`, sin descargas de binarios, Godot sólo vía `godot.sh`).

### Ola 1 — fundaciones (6 WPs en paralelo, sin dependencias entre sí)

**W1-ENG · Núcleo base, datos, marcado, guardado, arnés**
- Objetivo: todo lo que desbloquea a los demás.
- Posee: `core/util/*`, `core/data/*`, `core/text/*`, `core/save/*`; **stubs** de todos los demás archivos de `core/` con las firmas de §3.8 (cuerpos neutros; pasan a su dueño en ola 2); `autoload/data.gd`; `project.godot`; `tests/{run_tests,test_base,test_harness_selfcheck,test_t00_compile_all,test_t14_static,test_lint_determinism}.gd`; `tests/test_u_{j,det,log,cond,timekey,repo,schema,markup,clip_rules,event_log}.gd`; `tests/fixtures/data_min/**` (≥1 ejemplo válido de cada dataset de §4: 3 docs, 3 conclusiones incl. C6-like, 5 reacciones, 2 lugares, 1 escena, 2 diálogos); `devtools/{lint.gd, data_report.gd, blank.tscn}`; `data/ui_text/core.json`.
- Expone: §3.8 util/data/text/save completos; arnés §9.1.
- Aceptación: todos sus tests verdes; `test_u_markup` ≥30 casos (tramos, menciones, estilos, escapes, abreviaturas, `\.`, errores de lint); `test_u_clip_rules` (snap, oración, 40 palabras, herencia ≥50 % con empate); `test_u_event_log` (atómico, `.bak`, línea truncada, bytes idénticos); `test_u_schema` (válido e inválido por dataset); selfcheck del `Logger` (un `push_error` falla salvo `expect_error`), *watchdog*, `--list`, `--slow`; lint de determinismo en `core/`; `data_report.gd` imprime palabras por doc vs `words`.
- Depende: —.

**W1-THEME · Theme, fuentes y kit UI**
- Posee: `autoload/theme_installer.gd`, `ui/kit/*`, `data/fonts.json`, `data/ui_text/kit.json`, `tests/test_t21_fonts.gd`, `devtools/drivers/w1theme_*.gd`.
- Aceptación: T21 (lint; `allow_system_fallback == false` en `ThemeDB.fallback_font`, tema por defecto y las 4 ranuras; cobertura de glifos de `data/**/*.json` existente); captura `w1theme_galeria`: cada variación de tipo y papel con «», —, ñ, ¿¡, alto contraste; `set_slot("maquina", "embedded")` re-renderiza sin errores.
- Depende: —.

**W1-3D · Motor de dioramas**
- Posee: `world/{world_root,diorama_builder,camera_rig,picker,rect_clip,materials}.gd`, `world/props/{furniture,architecture,street,small}.gd`, `world/characters/*`, `tests/fixtures/places/sample.json`, `tests/{test_t29_dioramas,test_u_props}.gd`, `devtools/drivers/w13d_*.gd`.
- Aceptación: `test_u_props` construye headless cada `build_*` de §7.2 con parámetros por defecto, con `meta.occ`; T29 sobre `sample.json` (examine; `cover ≥ 0,5` y `tight` de un nodo encuadrado con `root.size` 1600×900; nodo tras ocluidor = ocluido) y sobre los `data/places/*.json` existentes; capturas `w13d_sample_<frame>` y `w13d_siluetas` (IoU < 0,85 por pares, impreso).
- Depende: — (lee `sample.json` con `JSON.parse_string` hasta que exista DataRepo).

**W1-POST · Grabado e iluminación**
- Posee: `world/lighting.gd`, `world/post/*`, `tests/test_t27_shaders.gd`, `devtools/drivers/w1post_*.gd`.
- Aceptación: T27 headless y `--window`; capturas de una escena de prueba propia (cajas, cilindros, una figura) por preset de luz × papel de franja; contornos visibles; una `CanvasLayer` con texto queda intacta.
- Depende: —.

**W1-AUDIO · Audio procedural**
- Posee: `audio/*`, `autoload/audio.gd`, `data/audio.json`, `tests/test_t28_audio.gd`, `tests/fixtures/audio_hashes.json`, `devtools/drivers/w1audio_*.gd`.
- Aceptación: T28; existen todos los ids de §8; bucles sin clic (salto de muestra en el punto de bucle < 0,02); `play` emite subtítulo; nada se genera en `_ready`.
- Depende: —.

**W1-BIBLE · Biblia, entidades y listas cerradas**
- Posee: `data/lists.json`, `data/entities/core.json`, `data/canon_bible.json`, `data/ui_text/rules.json` (reglas del asiento GDD§8.0, mensajes del chequeo formal, errores de recorte), `tests/fixtures/canon/*.txt` (texto de dominio público sin cabecera de Gutenberg, desde `.work/dl_canon/` y `.work/dl_verify/sign2.txt`).
- Aceptación: `lists.json` con todas las claves de §4.6 (T1–T9 completas; 5 temas de cebo; ≥4 canarios; formas de anuncio 1–4; `slip_topics`; plantillas de diario por tipo de evento; `report_cats`; `sensors`; `topic_groups`; `abbrev`); `entities/core.json` con toda persona, lugar, documento (D01–D45 y cada historia), concepto y valor de respuesta de GDD§10.4 (≥250); `canon_bible.json` con cada fila de GDD§2.2–2.3 y `knowable` por personaje; válidos contra §4 (y contra `test_u_schema` cuando W1-ENG lo publique).
- Depende: —.

### Ola 2 — sistemas, datos estructurales, lector y lugares (en paralelo; dependen de W1-ENG)

**W2-SIM · Simulación y sesión** — Posee `core/sim/{game_sim,game_state,actions,player_actions,clock,world_model,diary,tutorial}.gd`, `autoload/game.gd`, `tests/test_u_{actions,clock,world_model,diary,tutorial,game_sim}.gd`, `tests/{test_t09_determinism,test_t25_save,test_t26_map}.gd`, `tests/fixtures/sim/**`. Expone §3.2–3.7. Aceptación: prólogo → día 3 recorrible por un JSONL de acciones sobre fixtures; fases de §3.2 (día 6 sólo T; día 10 fijo); pasadas (9.N = 2); anuncios (oficina, sáb → lun, prólogo → día 1); T9, T25, T26, T14 verdes; `Game.act` escribe antes de devolver. Depende: W1-ENG.

**W2-DED · Recortes y libro mayor** — Posee `core/deduction/*`, `tests/test_u_{clipper,index,ledger,validator}.gd`, `tests/{test_t04_max_clips,test_t06_templates}.gd`, `tests/fixtures/ded/**`. Aceptación: las 5 condiciones de §5.2 con caso positivo y negativo; lotes (tamaño por calendario, conclusiones distintas, todo o nada, mensaje único, formal no gasta); C1 aparte; alias C10a; T4 y T6. Depende: W1-ENG.

**W2-REACT · Reacciones** — Posee `core/react/*`, `tests/test_u_{sensors,latency,holmes_agent,moran_agent,director,effects}.gd`, `tests/{test_t08_blindness,test_t11_pacing,test_t12_actor,test_t15_ley2,test_t16_hb13,test_t22_camden,test_t23_secret}.gd`, `tests/fixtures/react/**`. Aceptación: tabla de latencias GDD§9.3 caso por caso; domingo en mano; D1/D2/D3 con casos sintéticos; Ley 2 (1–2 verdaderas, 3 falsa con `refutado`, 4 silencio); canario → HA4 → HB11; T8, T12, T15, T16, T22, T23; T11 sobre un JSONL fijo. Depende: W1-ENG (usa el stub de `Invariant.runtime_guard` hasta W2-GRAPH).

**W2-GRAPH · Grafo e invariante** — Posee `core/graph/*`, `tests/test_u_{route_db,availability,cut_model,feasibility}.gd`, `tests/{test_t01_routes,test_t02_static_cuts,test_t03_invariant,test_t05_footprint,test_t17_false_leads}.gd`, `tests/fixtures/graph/**` (réplica sintética de la estructura de GDD§10.4). Aceptación: T1/T2/T3/T5/T17 verdes en fixtures y casos negativos que fallan cuando deben (falta sólo-I, corte sin `variante_blanda`, `|K_C| > 5`); T3 < 10 s con `ms` impreso; sobre datos reales informan faltantes con `pending_content`. Depende: W1-ENG.

**W2-SCENES · Diálogo, confrontación, compositores, finales** — Posee `core/scenes/*`, `core/sim/endings.gd`, `tests/test_u_{dialogue,composers,endings}.gd`, `tests/{test_t18_confrontation,test_t20_dialogue}.gd`, `tests/fixtures/scenes/**`. Aceptación: capas de respaldo; T20/T20b; HB4/HB6/HB12/M4/HB8 al presentar; T18; formas de anuncio sin lugares de Londres ni `secreto_camden`; finales en orden y variantes acumuladas. Depende: W1-ENG.

**W2-STRUCT · Datos estructurales del caso** — Posee `data/schedule.json`, `data/conclusions.json`, `data/reactions/*.json` (las 42 de GDD§9.6–9.7 + respuestas D27, D28, copia de L6, D37 de HC07; textos de voz A/B/Moran del GDD), `data/endings.json`, `data/easter_eggs.json`, `data/entities/struct.json`, `tests/{test_t07_knowledge,test_t13_eggs}.gd`. Aceptación: válidos contra §4; toda reacción que corta tiene `variante_blanda`; toda ruta de §10.4 con refs del contrato §4.8; `schedule.days` coincide con el calendario real de 1894; T7 y T13 corren (faltantes como `pending_content`). Depende: W1-ENG, W1-BIBLE.

**W2-READER · Lector de documentos** — Posee `ui/reader/*`, `tests/{test_t19_selection,test_u_text_builder}.gd`, `devtools/drivers/w2reader_*.gd`, `data/ui_text/reader.json`. Aceptación: T19 puro y de ventana (arrastre por `Input.parse_input_event` → `clip_text` correcto); `get_parsed_text() == plain` para todo doc existente; capturas: D05 de `data_min`, carta Remington con lupa, regla, rasante con luz a ambos lados, alto contraste. Depende: W1-ENG, W1-THEME.

**W2-PLACES-A** (L1 buhardilla + tienda; L2; láminas `prologo`, `M7`) · **W2-PLACES-B** (L3 calle + vestíbulo + agente; L8; L7; lámina `PARK`) · **W2-PLACES-C** (L4; L5 portería + Forasteros; L6; láminas `reichenbach` ×3)
- Posee cada uno: sus `data/places/*.json`, `data/plates/*.json`, `world/props/l#.gd` (C además `world/props/plates.gd`), `data/entities/places_<a|b|c>.json`, `devtools/drivers/w2places<a|b|c>_*.gd`.
- Aceptación: T29 verde en sus lugares; todo objeto de GDD§5 presente y examinable; ids de nodo del contrato §4.8 exactos con sus etiquetas; capturas por lugar × encuadre × franja (con grabado si W1-POST ya está); entrada al lugar sin tirón visible (precalentado).
- Depende: W1-3D.

### Ola 3 — UI, contenido y bots (en paralelo; dependen de ola 2)

**W3-SHELL** — Posee `main.gd`, `main.tscn`, `ui/{shell,layers,input_router}.gd`, `ui/desk/*`, `ui/drag/*`, `ui/map/*`, `ui/menus/*`, `data/map.json`, `data/ui_text/shell.json`, `devtools/drivers/w3shell_*.gd`. Aceptación: driver Título → nueva partida → prólogo → escritorio → mapa → visita → volver → dormir → amanecer con capturas; atajos; DnD a 3D (presentar); `--screen`/`--script`; persianas del mapa. Depende: W2-SIM, W2-READER, W1-3D, W1-THEME.

**W3-NOTEBOOK** (`ui/notebook/*`), **W3-LEDGER** (`ui/ledger/*`), **W3-SCENEUI** (`ui/scene/*`, `ui/compose/*`) — cada uno posee su carpeta, `data/ui_text/<wp>.json` y `devtools/drivers/<wp>_*.gd`. Aceptación por driver con capturas de cada pestaña/estado y un flujo completo (recortar → vincular → abrir folio → asiento → pasada en tinta y en seco; preguntar con frase previa; presentar en dos pasos; confrontación con callar y errores; compositores con texto final visible). Pueden desarrollarse con un host propio en su driver antes de que exista Shell. Dependen: W2-SIM, W2-DED, W2-SCENES, W1-THEME.

**W3-BOTS** — Posee `devtools/bots/*`, `devtools/play_cli.gd`, `tests/{test_t10_bots,test_t24_ramp}.gd`. Aceptación: 11 bots de §9.3; T10 (200 partidas de pesca ≤5 %; pasivo → F4; ninguno supera al deductor) y T24; `play_cli` funcional. Depende: ola 2 completa.

**Contenido** (redacción en español; dependen de W1-BIBLE y del contrato de W2-STRUCT). Cada uno posee sus `data/docs/…`, `data/entities/<wp>.json` y, si aplica, `dialogue/` y `scenes/`:

| WP | archivos | palabras (GDD§6, §15.1) |
|---|---|---|
| W3-CT-CORPUS-A | `docs/D01/{SCAN,REDH,IDEN,BOSC,FIVE,TWIS,BLUE,SPEC,ENGR,NOBL,BERY,COPP}.json` (vols. II–III) | 12 × ~300 |
| W3-CT-CORPUS-B | `docs/D01/{SILV,CARD,YELL,STOC,GLOR,MUSG,REIG,CROO,RESI,GREE,NAVA}.json`, `D43`, `D44`, `D01N` (notas de Watson y de Mary) | 11 × ~300 + 1.200 + 150 |
| W3-CT-REICH | `D02`, `D03` (FINA ampliado), `D04`, `D05`, `D06`, `D07` (epígrafe), `D08`, `D29a`, `D29b`, `D29c` | ≈3.400 |
| W3-CT-MORAN | `D09`, `D10`, `D11`, `D16`, `D17`, `D32`, `D39` | ≈2.040 |
| W3-CT-TRACES | `D12`, `D13`, `D14`, `D18`, `D19`, `D20`, `D22`, `D30`, `D31`, `D33`, `D34`, `D35`, `D45` | ≈1.700 |
| W3-CT-TIMES | `docs/D15/{0327…0405}.json` (columna con ~12 avisos de ruido por número; noticias [H] de london_period §1.3–1.4), `D40`, `D41`, `D42`, `catalog/noise.json` | ≈2.300 |
| W3-CT-LISLE | `D21`, `D23`, `D38`, `data/ui_text/epilogo.json` (epílogo, créditos) | ≈1.300 |
| W3-CT-DLG-A | `dialogue/{watson,mrs_hudson,wiggins,chico_agente,ujier}.json`, `scenes/{HC05,AGENTE}.json` | ≈2.000 |
| W3-CT-DLG-B | `dialogue/{mycroft,pell,harris,crane,librero,portero}.json`, `scenes/{PRO,M6,M7,HC06,HC07,HC08,HC09,END.F1,END.F2,END.F3,END.F4,EPI}.json` | ≈2.500 |

Aceptación común de contenido: `test_u_schema` y `Markup.lint` sin errores en sus archivos; tramos del contrato §4.8 presentes con sus etiquetas; T4, T7 y T21 sin fallas atribuibles a sus archivos; `data_report` dentro de ±15 % de su presupuesto; revisión con `play_cli -- --doc <id>` (recortes de prueba heredan lo esperado). **Además (§12.2):** `test_i_integration::test_real_data_loads_clean` verde (= `./godot.sh --headless -s devtools/lint.gd -- data` con 0 hallazgos) y ningún campo propio en `test_answers_indexable` / `test_walk_with_real_content`; seguir las reglas R1–R12 de §12.2.

**Guía de redacción (obligatoria para todo WP de contenido)**
- Español neutro (sin voseo ni regionalismos), registro de 1894; glosario de `research/london_period.md` §6; anacronismos de §7 de ese archivo y GDD§2.4 prohibidos.
- Doyle: traducción propia y fiel (dominio público); cada pasaje citado lleva `q:<id>` y su inglés exacto en `src_en` (copiado de `tests/fixtures/canon/`). EMPT sólo en el epílogo.
- **Uniformidad:** cada historia del corpus = escena inicial + escena central (~300 palabras), mismo formato y densidad de etiquetado; nada distingue a las que importan. Todo lo nombrable es entidad (también el ruido; ~70 % de las menciones son ruido).
- **Tramos:** dentro de una oración, ≤40 palabras (ideal 8–25); un tramo nunca lleva dos grupos de la misma conclusión (T4); las entidades clave de la conclusión aparecen en el texto del tramo (enlace por claves).
- Prohibido en texto público: afirmar que alguien vive (`afirma_que_vive`), dar el paradero de Holmes en 1894, traducir «not literally true», relacionar a Moran con Adair antes del 3-abr, mencionar Camden House en algo que llegue al bando de Holmes.
- Formato: §4.2 (comillas, rayas, fechas, dinero, abreviaturas, `\.`); glifos prohibidos `† ‡ ⅓ ℔`.
- Ritmo: ≤1.000 palabras nuevas por mañana en la bandeja (T11); páginas de 300–600 palabras.

**Voces** (GDD§4; no inventar personalidad a personajes canónicos):

| voz | rasgos | ejemplo (GDD) |
|---|---|---|
| Lisle (diario, cuaderno, chequeo formal) | precisa, seca, jerga de corrector («dele», «sic», «errata», «galerada») | «Mar. 27. Nadie corrige con lápiz blando una carta ajena si no está seguro.» |
| Voz A (Mycroft por Cotter) | seca, perezosa, una noche; firma «Un amigo de la exactitud»; giro «Le ahorraré el trabajo» | «Lea lo que quiera; no publique lo que no sabe.» |
| Voz B «—S.» (Holmes) | precisa, irónica, clave de corrector, remite a fuentes, imágenes químicas; nunca dice quién vive | «"A pique": dele. Véase el Journal de Genève…» |
| Holmes como librero | cascada, servil; se le cae al precisar | «Una ganga, señor, cada uno de ellos.» |
| Mycroft | afable, suave, irónico; ahorra esfuerzo físico, no palabras | «Le ahorraré el trabajo, señor Lisle…» |
| Cotter | monosílabos | «Por encargo.» |
| Watson | cálido, leal, herido; se cierra si lo presionan; nunca miente | «Un hombre puede ser herido más de una vez, señor Lisle.» |
| Mrs. Hudson | concreta, orgullosa; «sir» en cada frase, más cuanto más oculta (contable) | «Los cuartos están como él los dejó, sir.» |
| Wiggins | insolente, leal a un muerto; «jefe» | «La vieja tarifa, jefe.» |
| Harris / Moran | seco, cortés, metáforas de caza, adjetivos repetidos, «la forma debida» | «Un trabajo inteligente, inteligente.» |
| Pell | quisquilloso, latinajos, miedo a los pleitos | «En debida forma, señor Lisle, *in extenso*.» |
| Crane | chismoso, mercachifle; no es canal | «Lo cambiaron por un gordo que sonríe, señor.» |
| Cnel. James Moriarty | prosa militar seca | D28 |
| Steiler | telegráfico, mayúsculas sin tildes | D27 |

### Ola 4 — integración y pulido

| WP | posee | aceptación |
|---|---|---|
| W4-SLICE | `devtools/drivers/slice_*.gd`, `devtools/scripts/*.jsonl`, `tests/test_slice_*.gd` | rebanada vertical (GDD§15.6 H3: prólogo y días 1–3, HC01, HA1, HB1 desde Watson, HC02, HC10, un lote, informe 1 con M1 o M3, diario, guardado) y luego partida completa por guion, con capturas; fallas → diffs a los dueños |
| W4-EPILOGUE | `ui/epilogue/*`, `data/ui_text/epilogue_ui.json` | epílogo 1903, créditos sobre la tijera, lápiz azul; variantes de §12.2 |
| W4-STYLE | `world/lighting.gd`, `world/post/*` (heredados de W1-POST) | calibración T27; paletas por franja; noche del 5; Park Lane dorado; capturas comparativas |
| W4-AUDIO | `audio/*`, `data/audio.json` (heredados) | ambientes por lugar y franja; ritual del amanecer; noche final (cuartos, arpa que calla, silbido, vidrio, silbato) |
| W4-QA | `tests/content_gate.json` | T00–T29 verdes con `strict: true`; presupuesto de palabras; lint de anacronismos y glifos completo |
| W4-BALANCE | — (sólo propone diffs) | T10 con duración del Acto III ≤60 min (si no, GDD§15.7) |

---

## 11. Convenciones de código para agentes

- **Nombres:** archivos `snake_case.gd`; alias de `preload` en PascalCase (`const Clipper = preload("res://core/deduction/clipper.gd")`); funciones y variables `snake_case`; privadas con `_`; constantes `UPPER_SNAKE`. IDs de datos según §0 y §4.
- **Sin `class_name`** en `game/` (no resuelve en un clon limpio). Sin ciclos de `preload` (§1). Sin escenas `.tscn` salvo `main.tscn` y `devtools/blank.tscn`: todo se construye por código.
- **Tipado:** anotar parámetros y retornos salvo `st` y `repo` (sin tipo para no forzar `preload`).
- **Datos:** sólo vía `DataRepo` (`Data.repo()` en UI/mundo; parámetro `repo` en `core/`; `repo()` / `fixture_repo()` en tests). Nada hardcodea contenido del caso en código.
- **Log:** `const L = preload("res://core/util/log.gd")`; `L.i("<módulo>", "msg")`. Nada de `print` en `core/`. `push_error` sólo con `L.bug` (invariante rota): el runner lo cuenta como falla.
- **Determinismo:** en `core/` nada de RNG global, `RandomNumberGenerator`, `Time`, ni iterar diccionarios sin ordenar claves. `Det` para todo azar.
- **Archivos:** tests y devtools escriben sólo bajo `.work/` (`ProjectSettings.globalize_path("res://").path_join("../.work/…")`); `user://` ya cae en `.work/appdata/fe_de_erratas/` por `godot.sh`. Prohibidos `SystemFont`, red, descargas, `OS.execute`, *addons* y plugins de editor.
- **Correr:** tests `./godot.sh --headless -s tests/run_tests.gd [-- filtro] [-- --slow]`; con ventana `./godot.sh -s tests/run_tests.gd -- --window [filtro]`; sintaxis rápida `./godot.sh --headless --check-only -s res://ruta.gd`; juego `./godot.sh` (o `./godot.sh -- --screen=reader:D05`); capturas §9.4; bots §9.3.
- **Entrega:** respuesta final con archivos tocados, comandos corridos y resultados, capturas revisadas, diffs propuestos para archivos ajenos. Commits y push: sólo el orquestador.

---

## 12. Pendientes y ambigüedades detectadas (para el orquestador; no se asumen)

1. **Fuentes.** La nota técnica del encargo dice «por defecto la fuente embebida»; `CLAUDE.md` del repo dice que las cuatro fuentes (IM Fell, Special Elite, Homemade Apple) están **aprobadas** y existen en `assets/fonts/`. `fonts.json` las usa; volver a la embebida = cambiar 4 valores a `"embedded"`. Homemade Apple no tiene `† ‡` (prohibidos).
2. **`rank` de los finales:** el GDD exige `rank` explícito pero no fija valores. Propuesta en §4.15: F1=1, F3a=2, F3b=3, F2=4, F4=5. Confirmar.
3. **M1 sin variante blanda en el GDD** (pero §9.8 D1 exige una para toda reacción que corta). Propuesta: registrar la buhardilla sin llevarse originales.
4. **HB12 «los fragmentos de origen HC06 no cuentan»:** interpretado como «el asiento sellado debe seguir siendo válido sin los recortes de origen `S.HC06`».
5. **Sala de Lectura el domingo** (⚠ GDD§15.8): `schedule` la deja cerrada el día 6; si abría, se agrega una ventana (no afecta rutas).
6. **D33** (libro de ventas) muestra la entrada del jueves sólo después de HC07: el esquema de docs admite `parts[].when` (DSL) para esto.
7. **D07** (fotografía) y el frontispicio de **D10** se resuelven como láminas (`plate`): se recortan con rectángulo y también por su texto de examen.
8. **Caché del controlador de NVIDIA** fuera del repo (GDD§16.8): sin verificar. Mientras el usuario no decida, las corridas con ventana (capturas, `--window`) sólo en los hitos.
9. **Semilla de partida nueva:** sin `Time` en la lógica, `Game.new_session(0)` deriva la semilla del `content_hash` (todas las partidas nuevas iguales salvo semilla explícita). El azar sólo decide variantes de sabor, así que no afecta rutas.
10. **Invariante en días 9–10:** con «nada recortado» C9 y C12 no tienen 2 rutas completables a la noche del 9 (sus escenas son del 8–9 y del 10); por eso T3 evalúa hasta 8.N (como pide GDD§10.3) y D1 usa los recortes reales después. Confirmar que es la lectura buscada.

### 12.1 Resoluciones del orquestador (vinculantes)
1. **Fuentes:** aprobadas por el usuario. `fonts.json` usa IM Fell English (imprenta/itálica), Special Elite (máquina), Homemade Apple (manuscrito). SystemFont prohibido.
2. **rank de finales:** F1=1, F3a=2, F3b=3, F2=4, F4=5.
3. **M1 variante blanda:** registran la buhardilla sin llevarse originales (dejan ceniza y desorden).
4. **HB12:** el asiento sellado de C6/C7 debe seguir siendo válido sin recortes de origen `S.HC06`.
5. **Sala de Lectura el domingo:** cerrada.
6. **D33** usa `parts[].when` (DSL). **D07** y frontispicio de **D10** como láminas.
7. **Corridas con ventana:** el usuario las PERMITE (aceptó la caché del driver de GPU). Capturas libres durante el desarrollo, no sólo en hitos.
8. **Semilla:** derivada del `content_hash` salvo semilla explícita.
9. **Invariante:** T3 evalúa hasta 8.N; después D1 usa recortes reales.
10. **GDD §16:** se adoptan todos los valores por defecto (guardado por compromiso, sin señal de suficiencia, grabado a dos tintas, citas en español, lote de 2, F1 exigente, ~3 h).

### 12.2 Resoluciones de integración (ola 2) — vinculantes

> Las tomó el integrador tras verificar que las olas 1–2 encajan (sim ↔ ded ↔ react ↔ scenes ↔ graph) con una GameSim real sobre los datos estructurales reales. **Los redactores de la ola 3 leen primero las reglas R1–R12** (más abajo); las decisiones D1–D15 explican el porqué y qué cambió en el código.

**Qué se verificó (`tests/test_i_integration.gd`).** Una `GameSim` sin dobles sobre `data/` real (lists, entities, schedule, conclusions, reactions, places, plates, endings, eggs, ui_text) más el contenido mínimo de `tests/fixtures/integ/` (docs D23, D01.REDH, D03, D05, D15.0327–0330; `dialogue/watson.json`; `scenes/PRO.json`, escritos contra el contrato §4.8) recorre prólogo → amanecer del día 4: tutorial completo (práctica C1.10 en tinta), aviso del prólogo impreso en la columna del Times (`AD:prologo`), HC01, HA1 (papeleta), HB1 (cebo a Watson, carta «—S.» por K-W el día 4), HC02 (silueta de Wiggins), HB13 (dos franjas sin actos), HC10 (columna que cita el aviso), M10; diario con sus etiquetas (`J:go`, `J:slip`, `J:say.watson`, `J:ad`); pasada en limpio todo‑o‑nada (una fallida que gasta, una que sella C2 y C3); asiento C6 válido sólo con fragmentos runtime (`J:go` + `N:*.sil_wiggins` + `AD:prologo` + `R:HC10.texto`); variante con informe que lleva un original P (M1 en la primera salida, retiro de un día, buhardilla «registrada», HB10 lo devuelve por el mostrador de Crane); calendario completo de un jugador pasivo hasta el epílogo (F4); D1/T3 sin violaciones; `GameSim.replay`, `EventLog` y el autoload `Game` reproducen el estado byte a byte. Para cada fragmento recortado se comprueba que el modelo de rutas (`RouteDB.resolve`) promete las mismas etiquetas y el mismo origen que el recorte real. Capturas del lector sobre esos documentos runtime: `devtools/drivers/integ_lector.gd`.

**Decisiones (código y contrato):**

- **D1 · Dependencias de `core/`** (§1 corregido): `util ← text ← data ← {deduction, graph, react} ← scenes ← sim`; hacia arriba sólo `load()` en tiempo de llamada, con la lista cerrada de §1.
- **D2 · Extensiones compatibles** (§3.8, nota final): `Markup.parse/lint(src, ctx)`, `Schema.check(ds, v, ctx, col)`, `DataRepo` extendido (`fresh`, `clear_cache`, `conclusions_meta`, `plates`, `scenes`, `dialogues`, `map`, `fonts`, `audio`, `texts`, `files`, `markup_ctx`, `parse_text`, `doc_tramo`, `cache`), consultas `q_*` extra (§3.7). Ninguna firma del contrato cambió.
- **D3 · `inserts` a nivel de documento** (§4.4): `{"columna": "<parte>", "noticias": "<parte>"}`; Schema lo admite y valida (antes lo rechazaba aunque WorldModel lo usaba).
- **D4 · Práctica:** todo asiento creado en el prólogo o en la página `"erratas"` es de práctica (`entry.practice`): su chequeo formal pide dos **pasajes**, no dos orígenes (antes `q_entry` mostraba «Una sola fuente» en el asiento del tutorial que `practice` sí aceptaba). `q_ledger()` lista la página `erratas` (antes la perdía).
- **D5 · Líneas de diálogo recortables:** `clip_text` con `src {kind:"line", ref:<uid>}` acepta las líneas que dice `Dialogue` (`st.scenes.lines`), no sólo las de escena (`st.world.lines`); antes daba `inaccesible`. El recorte lleva origen = visita (`S.L4.1.M`) y la entidad del personaje.
- **D6 · `scenes[].place` opcional** (§4.13): finales `END.F1`–`END.F4` y epílogo `EPI` lo omiten.
- **D7 · `variants[].replace` conserva los tramos** (§4.13): mismos `#id` y mismas etiquetas; la línea reemplazada debe ser una línea base; `append` no puede reutilizar el id de una línea base; ids de línea únicos. Lo verifica Schema.
- **D8 · Días de semana ASCII:** `schedule.days[].weekday` y todo átomo `weekday` de `data/` usan `lun mar mie jue vie sab dom` (Schema y `Cond.validate`); `Cond.eval` sigue tolerando «mié»/«sáb» en runtime.
- **D9 · T14 excluye `tests/`** (confirmado): `create_folio(` sólo en `core/sim/player_actions.gd` (llamada) y `core/deduction/ledger.gd` (definición); los tests y fixtures pueden llamarla.
- **D10 · Convenciones de estado que lee `Cond`** (confirmadas contra lo que escriben los dueños; el recorrido las evalúa):

  | átomo | lee | escribe |
  |---|---|---|
  | `counter {name}` | `ctx.counters[name]` (p. ej. `n` en rastros) → `st.react.counters[name]` → `st.flags[name]` | Director: `fired.<rid>`, `delivered.<rid>`; contadores de disparador `"<nombre>=<valor>"` (`cebo=pared`, `hb5=`, `canario=K-W`, `slip_tema=holmes_cronicas`); MoranAgent: `moran.respuesta_s` |
  | `visited "L3"` | `st.world.visits`: `"S.<L>.<día>.<franja>"` (2.ª visita en la misma franja: `.2`); escenas fijas: su `origin` (`"S.M7"`, no cuenta como lugar) | WorldModel |
  | `char_present` | `st.world.visit.chars` `[{id, pose, trait, sil?}]` (siluetas con diálogo incluidas) | WorldModel |
  | `sealed*` | `st.ded.sealed` `{cid: id de asiento}` | Validator (pasada en limpio) |
  | `flag*`, `channel_closed` | `st.flags` (registro §3.9; `canal_cerrado.K-x`) | su único escritor (§3.9) |
  | `event_count {type, where}` | `st.events` (campos de §3.6; `where.topic_group` sobre `topic`; valor lista = pertenencia) | GameSim |
  | `report_final_cats_any` | evento `report` con `n` final: `items[].cats` | Composers (cats = `MoranAgent.report_cats`) |
  | `day`/`slot`/`tk`/`weekday` | `ctx.tk` si existe (Director), si no `st.clock` (fase `night` = franja `night`) | Clock |
- **D11 · Etiquetas con prefijo** (confirmado): `ClipRules.inherit` devuelve `"a:x"`, `"c:x"`, … y así se guardan en el recorte. `Validator.tag_match`: etiqueta de grupo **sin** prefijo en `conclusions.json` = `"a:<x>"`; con prefijo, exacta; `f:refutado` exacta. `MoranAgent.report_cats` compara `clip_tags` (`"c:holmes_vive"`) con prefijo; la confrontación lee `a:`; los huevos `x:EEnn`. En `conclusions.json` los `groups[].tags` y `tags_extra` van **sin** prefijo.
- **D12 · Stubs:** no queda ningún cuerpo neutro de W1-ENG en `core/`; toda función de §3.8 la implementó su dueño (verificado por firma y por cuerpo).
- **D13 · Puertas nuevas para el contenido:** `test_i_integration::test_real_data_loads_clean` (FAIL: `data/` debe cargar sin un solo error; es lo mismo que `./godot.sh --headless -s devtools/lint.gd -- data`), `test_answers_indexable` (pendiente hasta la ola 4: cada campo que el validador exige tiene ≥1 valor aceptado que algún contenido permite indexar) y `test_walk_with_real_content` (cuando `data/` traiga D23, D01.REDH, D03, D05, D15.0327–0330, `dialogue/watson.json` o `scenes/PRO.json`, el mismo recorrido valida ESE contenido; pendiente si falla, FAIL en modo estricto).
- **D14 · Pendiente de diseño (no se asume):** el valor `corresponsal_s` de C6 sólo se indexa hoy desde la nota M8 de Pell; la firma «—S.» de las columnas y cartas de voz B es texto plano. Holmes y Mycroft (también aceptados) son alcanzables. Si se quiere que «S.» sea elegible antes del día 9, la firma de los rastros de voz B debería ser `[[corresponsal_s|—S.]]` (decisión de W2-STRUCT/orquestador).
- **D15 · Siluetas examinables:** el nodo `sil_<who>` tiene examen neutro en `ui_text` `sim.sil.<who>` (wiggins, muchacho_sin_gorra, cochero, m3_hombres): se ve al examinarla y se recorta también por texto (`src {kind:"node", ref:"<lámina>/sil_<who>"}`, accesibilidad T29) con las mismas etiquetas que el recorte de lámina (`a:ancla_ks` + el acto `go` de la visita). Antes el examen era vacío y sólo servía el rectángulo. Una silueta nueva necesita su clave `sim.sil.<who>`.

**Reglas para los redactores (ola 3; obligatorias, además de la guía de §10):**

- **R1 · Tramos.** `{{#id etiqueta etiqueta|texto}}`. Un tramo = **una oración** (la oración termina en `.` `?` `!` `…` seguidos de espacio, salto o fin; no cortan las abreviaturas de `lists.abbrev` —Mr., Mrs., Dr., Sr., Sra., Cnel., Rev., núm., n.º, art., cap., días y meses abreviados («Mar.», «abr.»), etc.— ni una inicial «J.»; un punto que no debe cortar y no está en esa lista se escribe `\.`: `el Prof\. Moriarty`). ≤40 palabras (ideal 8–25). No se anidan. **Un solo grupo de una misma conclusión por tramo** (T4): si una frase prueba dos cosas, son dos oraciones y dos tramos. El tramo cubre sólo la oración que afirma el hecho; lo demás queda como texto plano (o en tramos sin `#id`, sólo `e:`). Cuidado con el diálogo: en «—¿Tiene usted miedo de algo? —le pregunté.» el `?` corta: son dos oraciones.
  - Correcto: `No me diga que vive, señor Lisle. {{#donde a:busca_a_holmes e:donde|Dígame dónde duerme [[tigre|el tigre]].}}`
  - Incorrecto (cruza oraciones; lint «tramo #donde: cruza oraciones»): `{{#donde a:busca_a_holmes|No me diga que vive. Dígame dónde duerme el tigre.}}`
  - Incorrecto (dos grupos de C10 en un tramo; T4): `{{#donde a:cebo a:busca_a_holmes|…}}`
- **R2 · Menciones y superficies.** `[[id]]` sin superficie se lee con `entities[id].name`, que **ya trae su artículo** («la roca», «una cornisa» no: «la cornisa»). Si el texto ya pone artículo o determinante delante, o la frase pide otra forma, use superficie explícita: `contra [[roca|la roca]]` o `contra la [[roca|roca]]`, nunca `contra la [[roca]]` (lint «artículo duplicado»). Recomendación: **escribir siempre `[[id|texto tal como se lee]]`**. Toda entidad debe existir: buscar en `data/entities/*.json` antes de crear; las nuevas van en `data/entities/<su_wp>.json` (`id`, `kind`, `name` con artículo, `index`, `noun`), sin duplicar ids.
- **R3 · Etiquetas.** `a:` grupo de conclusión con el nombre exacto de `groups[].tags` (tabla de grupos abajo) · `e:` entidad implícita (el recorte la gana aunque no esté mencionada) · `c:` lo que el texto dice para Moran (`holmes_vive`, `regreso_jueves`, `baker_street`, `camden`, `watson_privado`, `paradero_extranjero`, `verdadero`, `moran_autor`) · `f:` marcas (`refutado`, `secreto_camden`, `afirma_que_vive`, `privado_kw`, `ruido`) · `d:AAAA-MM-DD` · `p:<entidad lugar>` · `q:<id>` con su inglés exacto en `src_en` (copiado de `tests/fixtures/canon/*.txt`) · `h:F.<hecho>` · `w:` (⚠, nunca en rutas) · `x:EEnn`. **Pistas falsas:** el origen lleva `f:refutado a:falsa_<x>`; cada refutación lleva `a:refuta_<x>` (x = id de `_pistas_falsas` sin `falsa_`: `D05#corniche` → `a:refuta_reuter`, `D05#baton` → `a:refuta_baston`, `D19#presume` → `a:refuta_rio_cuerpo`). Todo fragmento de C13 lleva `f:secreto_camden`.
- **R4 · Lo que el asiento pide tiene que poder indexarse.** El validador sólo acepta en un campo de plantilla un valor que esté en el índice del jugador, y al índice entra lo que se recorta (menciones, `e:`, la `entity` del documento, `clip_entities`). Por eso: (a) cada valor de `answers` que su texto prueba debe aparecer **en el tramo que lo prueba** como mención o `e:` (`D03#sheer` menciona `[[a_pique|a pique]]` porque C3 pide `dice_a: a_pique`; `D05#marque` lleva `e:raspadura` porque C2 pide `calla: raspadura`); (b) las entidades de `keys.entities` de la conclusión aparecen en el texto del tramo (condición 5: enlace por claves). Faltan hoy (los cubren sus dueños): C1.01–C1.10 (fuentes y fechas de cada par INC), C4 `que: bienes` y `cuando: en_vida|antes_de_partir|antes_del_cuatro_de_mayo`, C10a `es: moran|autor_heavy_game`, C11 `persona: moran|autor_heavy_game`, `que: ronald_adair`, `con: fusil_de_aire|arma_de_aire_comprimido`, C14 `donde: subasta_de_paddington|paddington` y `cuando: tras_la_muerte_de_mary|enero_1894|muerte_de_mary` (`test_answers_indexable` lista lo que falte).
- **R5 · Ids del contrato §4.8.** El `ref` `D05#marque` exige en `docs/D05.json` un tramo `{{#marque …}}`; `S:M7.donde_duerme` una línea `"id": "donde_duerme"` en `scenes/M7.json`; `L:mrs_hudson.ordenes` una línea `"id": "ordenes"` en `dialogue/mrs_hudson.json` (el personaje es el nombre del archivo: el §4.8 escribe «hudson» = `mrs_hudson`); `M:D46` un `measure` y `paper_mm` en D46; `M:HA1.carta` `measure` y `paper_mm` en el `doc` de la reacción HA1 (también admitidos en escenas, `M:<escena>.<x>`). Ids de tramo y de línea: ASCII `snake_case`, únicos dentro del documento/escena/diálogo. Archivos: `docs/D05.json` (id `D05`), corpus `docs/D01/REDH.json` (id `D01.REDH`, ref `D01.REDH#abril`), notas `docs/D01N.json`, Times `docs/D15/0327.json` (id `D15.0327`). Cada `ref` de documento es **un** tramo; si el mismo tramo sirve a dos conclusiones lleva los grupos de ambas (`D03#sheer`: `a:fina_impreso_sin_raspadura a:fina_a_pique`, de C2 y C3), nunca dos grupos de la misma. Ejemplares: `"<doc>@<holder>"` con holder `L1` · `tomo` · `Crane` · `BM` · `L3`…`L8` (`D03@tomo`, `D03@Crane`, `D03@BM`, `D15.0327@L1`), exactamente los que cita `conclusions.json`. **Si su documento existe, DataRepo exige TODOS los tramos y ejemplares que el contrato le asigna** (error «el documento no tiene el tramo #x»): use el índice por documento de abajo.
- **R6 · El Times (W3-CT-TIMES).** `docs/D15/<MMDD>.json`: `entity` `times_<MMDD>` (existen), `src_type` `prensa_londres`, `origin` `D15.<MMDD>`, ejemplar `D15.<MMDD>@L1` (holder `L1`, `area` `buhardilla`, `via` `desk`, `from` `<día>.dawn`: llega a la bandeja al amanecer), `inserts` a nivel de documento con las partes de columna y de noticias. Los avisos de Lisle y las columnas «—S.» se agregan solos a la parte `columna`; no los escriba.
- **R7 · Escenas** (W3-CT-DLG-A/B). `place` sólo si la escena ocurre en un lugar del mapa (omitir en `END.*` y `EPI`). Escena fija de columna (M6, M7, HC07…): `place` `L1` y su `tk`. Escena automática de lugar: `auto: true` + `place` + `area` + `when`. `variants[].replace` conserva los tramos de la línea base (mismo `#id`, mismas etiquetas); `append` sólo ids nuevos. Ids `conf.*` reservados a la confrontación (HC07).
- **R8 · Prólogo** (W3-CT-DLG-B, W3-CT-LISLE, W3-CT-CORPUS-A). `scenes/PRO.json` lleva las líneas del instructor del tutorial con estos ids exactos: `t_clip`, `t_link`, `t_folio`, `t_entry`, `t_practice`, `t_sleep` (Pell) y `t_ad` (Harris); el motor las dice una por paso (no las repita en otras líneas). Lo que el jugador debe poder hacer la noche del prólogo con lo legible en L1: recortar (D23, el encargo), juntar dos recortes, abrir un folio, asentar y practicar un par INC (C1.10: `D01.REDH#abril` y `#octubre` en `D01.REDH@tomo` desde `P.N`) y redactar el aviso de testigos: **D23 debe mencionar `[[suceso_reichenbach|…]]`**, porque la forma `testigo` sólo ofrece sucesos indexados.
- **R9 · Diálogos.** `match` sólo sobre lo visible (`topic`, `assertion`, `doc`, `ent`, `kind`); `when` sobre el estado (DSL §4.18, con `weekday` ASCII). Ids especiales que el motor busca: `hb4.1`, `hb4.2`, `hb6`, `hb8`, `m4`, `hb12.ok`, `hb12.err1`, `hb12.err2` (o los que declare la reacción en su efecto `linea`: `vieja_tarifa`, `hb5_llevadas`, `hb5_pedidas`, …), `pago`, `tarea.<encargo>`, `conf.*` (reservados). Una línea dicha queda en el diario y es recortable (D5).
- **R10 · Fechas y días.** `date`, `chron_date`, `knowable` y `d:` en `AAAA-MM-DD`; día de semana en condiciones con los códigos ASCII de D8.
- **R11 · Antes de entregar:** `./godot.sh --headless -s devtools/lint.gd -- data` (0 hallazgos) y `./godot.sh --headless -s tests/run_tests.gd -- test_i_integration` (sin FAIL; mire el SKIP de `test_answers_indexable` y de `test_walk_with_real_content` por campos o documentos suyos), además de T04, T07, T21 y `data_report`.
- **R12 · Contenido del recorrido de integración.** Si escribe alguno de D23, D01.REDH, D03, D05, D15.0327–0330, `dialogue/watson.json` o `scenes/PRO.json`, el recorrido de `test_walk_with_real_content` lo usará en lugar de `tests/fixtures/integ/`: deben cumplirse las mismas expectativas que los fixtures de ese directorio (son el ejemplo de referencia de cada uno: tramos, ejemplares, menciones de R4, línea `as.pared` de Watson —capa `afirmacion`— y `escribi_mycroft` con `when` sobre `event_count`).

**Ejemplos correctos (lint limpio con las entidades reales):**

```json
{"id": "p1", "text": "MEIRINGEN, 5 de mayo. — {{#corniche a:cornisa_existe a:refuta_reuter e:reichenbach|Más arriba hay [[cornisa|una cornisa]] que no se ve desde [[sendero|el sendero]], «une corniche que l'on ne voit pas du sentier».}} {{#marque a:raspadura_registrada e:raspadura|En [[pared|la pared]], «une marque récente».}}"}
{"id": "p7", "text": "{{#sheer a:fina_impreso_sin_raspadura a:fina_a_pique q:sheer e:reichenbach|Era un [[sendero|sendero]] de tres pies, con una [[pared|pared]] [[a_pique|a pique]] a un lado y un precipicio a pique al otro.}}"}
{"id": "p2", "text": "—¿Tiene usted miedo de algo? —le pregunté. {{#air_guns a:arma_de_aire q:air_guns e:fusil_de_aire|—De los [[fusil_de_aire|fusiles de aire]].}}"}
{"id": "p1", "text": "{{#jartum f:refutado a:falsa_jartum e:jartum|Nos comunican que el señor Sigerson es huésped del Califa en [[jartum|Jartum]].}}"}
```

```json
{"id": "M7", "place": "L1", "area": "buhardilla", "tk": "7.night", "plate": "PL.M7", "origin": "S.M7",
 "lines": [{"id": "inteligente", "who": "harris", "text": "{{#adjetivos a:harris_es_moran e:adjetivos_repetidos|Un trabajo inteligente, inteligente.}}"}],
 "variants": [{"when": {"flag": "pell_despedido"}, "replace": {"inteligente": "{{#adjetivos a:harris_es_moran e:adjetivos_repetidos|Un trabajo inteligente, inteligente.}} Su procurador ya no nos sirve."}}]}
{"id": "END.F4", "lines": [{"id": "cierre", "who": "lisle", "text": "(texto del final; sin place: no ocurre en un lugar del mapa)"}]}
```

```json
{"id": "D15.0327", "entity": "times_0327", "title": "The Times, martes 27 de marzo de 1894", "src_type": "prensa_londres", "class": "I",
 "origin": "D15.0327", "date": "1894-03-27", "font": "imprenta", "paper": "diario_hueso", "paper_mm": [380, 540],
 "inserts": {"columna": "p2", "noticias": "p1"},
 "copies": [{"id": "D15.0327@L1", "holder": "L1", "area": "buhardilla", "via": "desk", "from": "1.dawn", "to": "10.N"}],
 "parts": [{"id": "p1", "text": "NOTICIAS DE LONDRES. — …"}, {"id": "p2", "text": "COLUMNA DE ANUNCIOS. — …"}], "words": 600}
```

**Índice del contrato por documento** (generado de `data/conclusions.json`, `_pistas_falsas` y `easter_eggs.json`; manda `conclusions.json`). Columna 2: tramos que el documento DEBE tener y quién los usa (conclusión, refutación `a:refuta_<x>`, pista falsa `f:refutado a:falsa_<x>`, huevo). Columna 3: ejemplares citados.

| documento | tramos | ejemplares |
|---|---|---|
| `D01.FIVE` | `#madre` (C1.07) · `#una_mujer` (C1.08) | `D01.FIVE@BM`, `D01.FIVE@tomo` |
| `D01.GREE` | `#founders` (C7) · `#pall_mall` (C7) · `#whitehall` (C7) | `D01.GREE@BM`, `D01.GREE@tomo` |
| `D01.REDH` | `#abril` (C1.10) · `#octubre` (C1.10) | `D01.REDH@BM`, `D01.REDH@tomo` |
| `D01.SCAN` | `#turner` (C1.03) · `#boda` (C1.06) · `#marzo_1888` (C1.08) | `D01.SCAN@BM`, `D01.SCAN@tomo` |
| `D01.SPEC` | `#hudson` (C1.03) | `D01.SPEC@BM`, `D01.SPEC@tomo` |
| `D01.TWIS` | `#james` (C1.02) | `D01.TWIS@BM` |
| `D01N` | `#fina_fo` (C2, refuta falsa_tachadura → `a:refuta_tachadura`) · `#mi_james` (C14) · `#nov93` (C14) | `D01N@tomo` |
| `D02` | `#clausula` (C2) | `D02@L1` |
| `D03` | `#sheer` (C2, C3) · `#a_mycroft` (C4) · `#air_guns` (C11) · `#baston` (refuta falsa_baston → `a:refuta_baston`) · `#hopeless` (refuta falsa_rio_cuerpo → `a:refuta_rio_cuerpo`) · `#steiler` (refuta falsa_posadero → `a:refuta_posadero`) · `#cuatro_mayo` (huevo EE03) | `D03@BM`, `D03@Crane`, `D03@tomo` |
| `D04` | `#clausula` (C2) · `#cajista` (refuta falsa_tachadura → `a:refuta_tachadura`) | `D04@Crane` |
| `D05` | `#marque` (C2) · `#corniche` (C3, refuta falsa_reuter → `a:refuta_reuter`) · `#baton` (refuta falsa_baston → `a:refuta_baston`) · `#aucun_corps` (refuta falsa_rio_cuerpo → `a:refuta_rio_cuerpo`) | `D05@BM` |
| `D08` | `#kanzel` (C3, refuta falsa_reuter → `a:refuta_reuter`) | `D08@BM` |
| `D09` | `#desague` (C5) · `#cruel` (C5) · `#nota_redactor` (C5) | `D09@BM`, `D09@Crane` |
| `D10` | `#cruel` (C5) · `#portada` (C5) · `#frontispicio` (C5) · `#adjetivos` (C10, C10a) · `#cabrito_atado` (C10) · `#bala_blanda` (C11) · `#apostarse` (C13) | `D10@BM`, `D10@Crane` |
| `D11` | `#desague` (C5) · `#no_bala` (C10) · `#hacerlo_balar` (C10) · `#mejor_tiro` (C11) | `D11@BM` |
| `D12` | `#n97` (C8) · `#dedicatoria` (C8, C12) | `D12@BM` |
| `D13` | `#muestra97` (C8) · `#jartum` (pista falsa → `f:refutado a:falsa_jartum`) | `D13@BM` |
| `D14` | `#opusculo` (C8) · `#amarillo` (C12) | `D14@BM` |
| `D15.0403` | `#whist` (C11) · `#nadie_oyo` (C11) · `#nada_falta` (refuta falsa_anarquistas → `a:refuta_anarquistas`) | `D15.0403@L1` |
| `D15.0405` | `#meunier` (refuta falsa_meunier → `a:refuta_meunier`) | — |
| `D16` | `#moran` (C10, C10a, C11) | `D16@BM`, `D16@L1` |
| `D17` | `#moran_conduit` (C10, C10a) · `#church_street` (C12) | `D17@BM`, `D17@Crane` |
| `D18` | `#calendars` (C4, refuta falsa_herencia → `a:refuta_herencia`) · `#mary` (C14) | `D18@L6` |
| `D19` | `#indice` (C4, refuta falsa_herencia → `a:refuta_herencia`) · `#presume` (refuta falsa_rio_cuerpo → `a:refuta_rio_cuerpo`) | `D19@BM` |
| `D20` | `#subasta` (C14) | `D20@BM` |
| `D23` | `#cruel` (C10, C10a) | `D23@L1` |
| `D29a` | `#tachadura` (C2, refuta falsa_tachadura → `a:refuta_tachadura`) | `D29a@L4` |
| `D29b` | `#surcos` (C4) | `D29b@L4` |
| `D30` | `#recibo` (C4, C7) | `D30@L3` |
| `D31` | `#para_mholmes` (C7) · `#telegramas` (C8) | `D31@L5` |
| `D32` | `#llave_harris` (C13) | `D32@L3` |
| `D33` | `#direccion` (C12) | `D33@Crane` |
| `D34` | `#ruinas` (refuta falsa_jartum → `a:refuta_jartum`) | — |
| `D35` | `#califa` (refuta falsa_jartum → `a:refuta_jartum`) | — |
| `D43` | `#hombro` (C1.01) · `#john_h` (C1.02) · `#cuatro_mayo` (huevo EE03) | `D43@BM`, `D43@Crane` |
| `D44` | `#pierna` (C1.01) · `#conoce_mary` (C1.06) · `#madre_muerta` (C1.07) · `#july7` (C1.09) · `#septiembre` (C1.09) · `#oficios_mano` (C8) · `#perlas` (huevo EE03) | `D44@BM`, `D44@Crane` |
| `D45` | `#duelo` (C14) | `D45@BM` |
| `D46` | — (se mide entero: `M:D46`, C7) | `D46@L5` |

**S:** `S:HC06.b_kbm` (C6) · `S:HC06.b_kw` (C6) · `S:HC06.b_kh` (C6) · `S:HC06.b_*` (C7) · `S:HC06.a` (C7) · `S:HC06.c` (C8) · `S:HC05.jueves_a` (C9) · `S:HC06.e` (C9) · `S:M7.inteligente` (C10, C10a) · `S:M6.donde` (C10) · `S:M7.donde_duerme` (C10) · `S:M7.trichinopolis` (C13) · `S:AGENTE.militar` (C13) · `S:PRO.cace_india` (C13)

**L:** `L:mrs_hudson.mycroft_paga` (C4) · `L:mrs_hudson.ordenes` (C6) · `L:watson.escribi_mycroft` (C7) · `L:wiggins.vieja_tarifa` (C7) · `L:wiggins.conduit` (C10, C10a)

**N:** `N:RB.foto.linea` (C3, refuta falsa_reuter → `a:refuta_reuter`) · `N:*.sil_wiggins` (C6) · `N:L2.cotter_canastilla` (C7) · `N:L2.cesto_tiras` (C7) · `N:L3.ventanas_abiertas` (C9) · `N:L3.shag` (C9) · `N:L3.cajon` (C9, refuta falsa_meunier → `a:refuta_meunier`) · `N:PRO.harris` (C10, C10a, C13) · `N:L7.linea_de_tiro` (C11) · `N:L1.librero_dedos` (C12) · `N:L1.librero_sombra` (C12) · `N:L8.guillotina` (C13) · `N:L8.ceniza` (C13) · `N:L4.hueco_estante` (C14) · `N:L4.crespon` (C14) · `N:L7.azafranes` (refuta falsa_anarquistas → `a:refuta_anarquistas`)

**M:** `M:HA1.carta` (C7) · `M:HA0.carta` (C7) · `M:D46` (C7)

**R:** `R:D27.texto` (C3, refuta falsa_posadero → `a:refuta_posadero`) · `R:D28.anglo` (C5) · `R:HA3.*` (C6) · `R:HC10.texto` (C6) · `R:HB1.pared.1.col` (C6) · `R:HA1.*` (C6, C7) · `R:HB1.pared.1.kw` (C6, C7) · `R:HB4.carta` (C6) · `R:HA4.lisle_mudanza.kh` (C6) · `R:HC04.tarjeta` (C7) · `R:HA0.*` (C7) · `R:HB5.recibo` (C7) · `R:HC01.sobre` (C7) · `R:HA1.giro` (C7) · `R:HA0.giro` (C7) · `R:HC01.no_lo_es` (C8) · `R:HB7.col` (C10) · `R:M2.nota` (C10) · `R:HB9.carta` (C10) · `R:D37.precio` (C12)

**J:** `J:go` (C6) · `J:slip` (C6) · `J:say.watson` (C6) · `J:go.L3` (C6) · `J:say.mrs_hudson` (C6)

**AD:** `AD:prologo` (C6) · `AD:*` (C6)

**Grupos y claves por conclusión** (`conclusions.json`; en el texto se escriben con `a:`; `${ch:campo}` = código del canal del medio elegido: `kbm` `kw` `kh` `ks` `kt`):

| conclusión | plantilla | grupos (línea de la plantilla · etiqueta) | `keys.entities` (enlace por claves) |
|---|---|---|---|
| C2 | T2 | l0 `fina_impreso_sin_raspadura` · l1 `raspadura_registrada` | fina, reichenbach, roca, pared, raspadura, marca_en_la_roca |
| C3 | T1 | l0 `fina_a_pique` · l1 `cornisa_existe` · extra `remite_journal` | reichenbach, pared, sendero, cornisa |
| C4 | T5 | l0 `bienes_a_mycroft` · l1 `bienes_a_mycroft` · l4 `en_vida` | holmes, mycroft, bienes |
| C5 | T4 | l0 `estilo_cartas_coronel` · l1 `estilo_o_rostro_moran` | tigre, desague, cruel, bigote, cazador |
| C6 | T6 | l0 `acto_${ch:por_medio}` · l0 `ancla_${ch:por_medio}` · l1 `acto_${ch:y_de}` · l1 `ancla_${ch:y_de}` | (ninguna) + kinds `act_ref`: todo fragmento cita un acto (`[[@act|…]]`) |
| C7 | T4 | l0 `me_vigila_de_cerca` · l1 `vinculo_mycroft` | club_diogenes, pall_mall, mycroft, remington, remington_s_alzada, papel_corto, giro_ahorrare, whitehall, matasellos_sw, watson |
| C8 | T7 | l0 `identidad_holmes` · l1 `actividad_posterior_a_mayo_1891` · extra `refuta_jartum` | numero_97, monografia_cenizas, opusculo_oficios, forma_de_la_mano, mycroft, letra |
| C9 | T8 | l1 `preparativos_221b` · l2 `dia_jueves` · extra `latencia_s` | jueves, 221b, mycroft, baker_street |
| C10 | T9 | l0 `harris_es_moran` · l1 `cebo` · l2 `busca_a_holmes` | harris, moran, bigote, cabrito, cabrito_atado, cebo, donde, tigre, adjetivos_repetidos |
| C10a | T3 | l0 `harris_es_moran` · l1 `harris_es_moran` | harris, moran, bigote, adjetivos_repetidos, conduit_street, cruel |
| C11 | T5 | l0 `autor_moran` · l2 `arma_de_aire` · l3 `disparo_desde_fuera` | ronald_adair, moran, disparo, bala, bala_blanda, fusil_de_aire, arma_de_aire_comprimido, park_lane, park_lane_427, linea_de_tiro |
| C12 | T3 | l0 `librero_falso` · l1 `rasgo_holmes` | librero, anciano, church_street, letra, amarillo, sombra |
| C13 | T5 | l0 `tirador` · l3 `escondite_preparado` | camden_house, casa_vacia, harris, moran, cheroot, 221b |
| C14 | T5 | l0 `tomos_de_watson` · l3 `tomos_de_watson` · l4 `duelo` | watson, paddington, tomos, mary_watson, subasta_de_paddington, notas_de_los_tomos |

### 12.3 Cierre de la ola 3 (integración) — vinculante

- **D16 · Recortar en casa.** El escritorio muestra el hub (`"hub"`: `GameSim.q_hub_plate`). `WorldModel.plate_snapshot(st, repo, "hub")` es la buhardilla de ahora (área `buhardilla` y nodos `*`, siluetas, variante; `{}` fuera de casa); `Clipper.accessible("plate", "hub")` vale con Lisle en casa. Recortarla (`clip_plate {plate:"hub"}` o `clip_text {src:{kind:"node", ref:"hub/<nodo>"}}`) archiva esa instantánea como lámina de visita `PL.L1.<día>.<franja>[.k]` (origen igual; RouteDB: `PL.L1`) y el recorte la nombra; una igual en la misma franja se reutiliza y un recorte rechazado no deja lámina (`PlayerActions._clip`).
- **D17 · Láminas de escena en un lugar del mapa.** Una escena con `plate` que no es una lámina fija de `plates/` y con `place` del mapa archiva, al empezar, la instantánea de ese lugar y área con ese id (origen `PL.<lugar>.<día>.<franja>`). HC07 lleva `"plate": "PL.HC07"`: la confrontación muestra la tienda del día 10 y sus nodos (`N:L1.librero_dedos`, `N:L1.librero_sombra`: C12.R1) se recortan.
- **D18 · Siluetas con diálogo = personajes.** Como `WorldModel.start_visit` suma a los personajes de la visita la silueta que tiene diálogo, el modelo de rutas también (`Availability._sil_char_srcs`, `all_chars`): Wiggins se interroga desde que HC02 lo pone (3.dawn) en todo lugar que declara su silueta, en cualquier área visitable (en el hub sólo la tienda). Resuelve `L:wiggins.vieja_tarifa` (C7.R7) y `L:wiggins.conduit` (C10.R4, C10a.R4).
- **D19 · Medidas de C7.R1.** `M:D25` no tenía documento (D25 son las cartas runtime de la voz A) y HC06 no podía declarar su medida. Ahora: `M:HA1.carta` (C7.R1, garantizada) / `M:HA0.carta` (C7.R1c, columna) — la carta entregada, que se mide en el lector — con `M:D46`, el pliego del club de HC06 (f): documento D46, ejemplar `D46@L5` (área `*`: Sala de Forasteros y portería, días 8–9; HB12 cierra sólo la Sala, D9) que se abre desde los nodos `papel_mesa`/`papel_club` (e:papel_del_club) y se mide con la regla del lector. Schema admite `measure`/`paper_mm` también en escenas (`M:<escena>.<x>`), aunque la UI sólo mide documentos.
- **D20 · T1 de las opcionales.** `RouteDB.lint` exige ≥2 rutas ★ sin ejemplar común sólo a las obligatorias; en las opcionales (C10a, C14) cada ruta debe valer igual (`test_t01_optional_real_data`). C14.R3 lleva el crespón (`N:L4.crespon`): sin él no cubría el grupo `duelo`.
- **D21 · Voces de la «siguiente comunicación» (M10–M12).** Cada rastro `linea` tiene su `linea_h` (mismas etiquetas, más `e:harris`): Pell transmite en tercera persona («El mayor…»); Harris en persona (M7, canal `en_persona`) o firmando «H.» (tras M4) habla en primera persona. `Effects._take_next_lines` elige al adjuntarla.
- **D22 · Contracciones con borde de palabra.** `Markup.contract` (lo usan `WorldModel.contract` y `Diary.compose`): «de el »/«a el » se contraen sólo como palabras sueltas («para el», «puede el» quedan intactos); `Deps.fill` ya lo hacía en las junturas.
- **D24 · Plan y bots.** `Feasibility.merge`: un fragmento con varias fuentes en el MISMO lugar y área (p. ej. `S:HC06.b_*`, una línea por canal en la Sala de Forasteros) pide una visita a ese lugar en cualquiera de sus franjas, no «una salida cualquiera» (el deductor iba a otro lado y perdía la línea). Bot deductor: los lotes son exactos, así que una opcional (C10a, C14) acompaña a una obligatoria sólo si hace falta por paridad (las demás obligatorias por sellar antes de la pasada final son pares) o si no queda otra pasada doble; la pasada final de 1 queda para C12, que sólo vale ahí. Driver de verificación con ventana: `devtools/drivers/w3cierre_flujo.gd` (hub, D46, HC07).
- **D23 · Pequeños de UI.** Epígrafe de recorte de texto con «; » entre etiquetas de índice (`Clipper._caption`); `Composers.piece_text` público (lo usa `ad_composer`); el foley del propio clic (`sfx.papel`, `sfx.pagina`, `sfx.plumin`) suena sin subtítulo (`audio.json` `quiet_captions`, `Audio.quiet`); la pestaña del cuaderno se llama «Cotejos».

### 12.4 Cierre de la ola 4 (integrador final) — vinculante

- **D25 · Una sola fuente por id.** `ui_text/scenes.json` ya no copia líneas que tienen fuente propia: HB4 → `dialogue/watson` (`hb4.1`, `hb4.2`), HB12 → `dialogue/mycroft` (`hb12_exito`, `hb12_error_1/2`, por `efecto.resultado`), confrontación → `scenes/HC07`. Sólo quedan en ui_text `scenes.conf.3.si` y `scenes.conf.acto_def`. Los fixtures (`tests/fixtures/scenes`, `w3sceneui/data/scenes/HC07.json`) siguen la misma regla.
- **D26 · Pedir siempre cuesta.** `act_slip` gasta la papeleta también si la ficha es de ruido (`{t:"slip", doc:"", noise:<rótulo>}`) o si el ejemplar BM no se sirve hoy (fuera de su ventana): `{ok:true, view:""}`, evento `slip` con `topic` «otros» (o el del documento) y el título; `st.world.slips[visita]` guarda `"~<doc o rótulo>"`. Un documento sin ejemplar BM sigue siendo `no_esta`. `GameSim.q_slips_used()`. Así el costo no distingue lo que importa.
- **D27 · Wiggins sólo en exteriores** (`silhouettes.<who>.talk`, §4.11): L1 tienda, L3 calle, L5 portería, L7 exterior; en L2, L4, L6 y L8 se ve por la ventana sin panel. `WorldModel.start_visit` y `Availability._sil_char_srcs` usan la misma regla (T1/T3 verdes).
- **D28 · El prólogo no se bloquea** (§5.1, «Índice desde el instructor»).
- **D29 · Lo conocido de antemano.** `dialogue.<char>.known: true` (Crane, el casero de Lisle): su nombre se muestra aunque no esté en el índice (`q_scene`, `SimLink.char_label`, cuaderno).
- **D30 · Día 10.** `Clock.enter_day` dice primero la escena HC07 (Crane llama, entra el anciano) y después la afirmación I de la confrontación; el anciano cita el acto en voz alta («asiento 214, el martes 27», `Confrontation._spoken`).
- **D31 · UI.** Los avisos de la Shell se corren al margen izquierdo con un compositor abierto (informe, anuncio, telegrama, carta) para no tapar el título; la tarjeta de diálogo se reajusta cuando cambia el alto del texto; las pestañas del libro mayor terminan sobre el alto real del papel del sello; la papeleta no duplica comillas; el título pregunta «Seguir / Volver al título» antes de continuar un guardado de otra versión (`Game.save_other_version`). Letra manuscrita: `ThemeInstaller.HAND_SPACE_PX` (la «S» de Homemade Apple dibuja 18 px a la izquierda de su origen a 32 px).
- **D32 · 3D.** Maniquíes con ojos (dos puntos de tinta): una figura de frente ya no se lee de espaldas. Pell «se seca la frente» con el codo doblado (IK de dos huesos, `Mannequin._elbow`) y un pañuelo chico; Harris tres cuartos hacia la cámara en la lámina del prólogo; Mycroft y su sillón miran al encuadre de la Sala de Forasteros; L4 esquina = farmacia de Pratt (como el Kelly's, D17); L8 «vista» por la rendija de la hoja levantada.
- **Guiones.** `devtools/scripts/slice_*.jsonl` regrabados (`slice_record.gd -- all`) con el contenido final; `slice_ui_runner` pide la copia certificada por la tarjeta de examen y lee la presentación del prólogo antes de trabajar. El runner de tests admite varios filtros separados por coma.

### 12.5 v3, segundo playtest (corrector final) — vinculante

Ver `docs/GDD_v3.md` §12. Lo que toca contratos de código: `WorldRoot` desarma las bandas del borde al reactivar la
entrada o `edge_enabled` (`_edge_armed`, se arma con un movimiento fuera de las franjas); `CameraRig._settle_step` asienta
en la dirección del giro con `SETTLE_DIR_T`; `DocumentReader`: rueda = desplazar, Ctrl + rueda = zoom; `PageView.MIN_W_MM`
y tiras acostadas; `ClipRules.inherit` devuelve `inherited` (tramo `#fisica` con ≥ 25 %); `Dossier.act_confirm` devuelve
`no_link` y el texto `v3core.no_se_tocan` cuando las pruebas no comparten entidades; `Dialogue.topics/act_ask` aceptan
`st.world.known`; `dialogue.<char>.addr_anon`; `Guide` suma `v3core.pend.sin_abiertas`; `Objects.own_doc` (`_doc` de los
nodos); entrega de reacción `del_libro`.
