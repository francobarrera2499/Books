# ui/shell.gd — dueño de la pantalla: capas, mundo 3D, pila de paneles, fundidos, avisos (ARCHITECTURE §2.3, §6.3).
# Dueño: W3-SHELL. Lo crea main.gd y recibe boot(opts) con los argumentos de usuario (main.parse_args).
# Crea: WorldRoot (3D) · capas de ui/layers.gd · DropCatcher3D (5) · DragLayer (120) · subtítulos (90) · fundido (100) ·
#   InputRouter. Pantallas (una activa): Title -> GameScreen -> Epilogue/Credits/BluePencil (W4-EPILOGUE) -> Title.
# Pila de paneles (§6.3): push(panel) · pop() -> bool (fe_volver) · top() · close_kind(kind) · is_open(kind).
#   Un panel es un Control (va a la capa de su clase) o un CanvasLayer (va como hijo). Protocolo por duck typing, sin
#   class_name (paneles de W2-READER, W3-NOTEBOOK, W3-LEDGER, W3-SCENEUI, W4-EPILOGUE):
#     open(...) opcional (se llama con los argumentos que admita) · close() opcional · back() -> bool opcional (consume
#     un fe_volver interno, p. ej. dejar la tijera) · señal closed opcional · var handle_back (el lector) se pone false:
#     el volver lo decide la pila. Un panel que se oculta o libera solo sale de la pila en el cuadro siguiente.
#   Máximo 2 paneles apilados (§6.1): al abrir un tercero se cierra el de abajo.
# Paneles por clase (open_panel(kind, args)): notebook, ledger (libros, 20) · map (50) · scene, confront (40) ·
#   ad, telegram, letter, report (60) · options (60) · epilogue, credits, blue_pencil (pantallas de W4). Si el script
#   de otro paquete todavía no existe, se usa un respaldo propio mínimo (fallback.gd) para que nada quede trabado.
# Avisos: note(text) = línea de Lisle (voz del oficio, ui_text), sin sonido de alerta. Subtítulos: Audio.subtitle.
extends Node

signal screen_changed(id: String)
signal panel_opened(kind: String)
signal panel_closed(kind: String)

const Layers = preload("res://ui/layers.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const WorldRootScript = preload("res://world/world_root.gd")
const Reader = preload("res://ui/reader/document_reader.gd")
const DragLayer = preload("res://ui/drag/drag_layer.gd")
const DropCatcher = preload("res://ui/drag/drop_catcher_3d.gd")
const InputRouter = preload("res://ui/input_router.gd")
const GameScreen = preload("res://ui/desk/game_screen.gd")
const Title = preload("res://ui/menus/title.gd")
const Fallback = preload("res://ui/desk/fallback.gd")
const J = preload("res://core/util/j.gd")

const FADE_S := 0.35
const NOTE_S := 3.6
const MAX_STACK := 2

# kind -> {path, layer, cache}
const PANELS := {
	"notebook": {"path": "res://ui/notebook/notebook.gd", "layer": "books", "cache": true},
	"ledger": {"path": "res://ui/ledger/ledger.gd", "layer": "books", "cache": true},
	"map": {"path": "res://ui/map/map_screen.gd", "layer": "map", "cache": true},
	"scene": {"path": "res://ui/scene/scene_panel.gd", "layer": "scene", "cache": false},
	"confront": {"path": "res://ui/scene/confrontation_view.gd", "layer": "scene", "cache": false},
	"ad": {"path": "res://ui/compose/ad_composer.gd", "layer": "modal", "cache": false},
	"telegram": {"path": "res://ui/compose/telegram_composer.gd", "layer": "modal", "cache": false},
	"letter": {"path": "res://ui/compose/telegram_composer.gd", "layer": "modal", "cache": false},
	"report": {"path": "res://ui/compose/report_composer.gd", "layer": "modal", "cache": false},
	"options": {"path": "res://ui/menus/options.gd", "layer": "modal", "cache": false},
	"epilogue": {"path": "res://ui/epilogue/epilogue_screen.gd", "layer": "modal", "cache": false},
	"credits": {"path": "res://ui/epilogue/credits.gd", "layer": "modal", "cache": false},
	"blue_pencil": {"path": "res://ui/epilogue/blue_pencil.gd", "layer": "modal", "cache": false},
}

var opts := {}
var fast := false
var sounds := true
var world: Node3D
var layers := {}                 # nombre -> CanvasLayer
var router: Node
var drag_layer: CanvasLayer
var drop_catcher: Control
var reader: CanvasLayer = null
var screen: Node = null
var screen_id := ""
var game_screen: Node = null
var stack: Array = []            # [{kind, node}]
var _cache := {}                 # kind -> node (paneles reutilizables)
var _owned := {}                 # instance_id -> true: paneles creados por open_panel (los únicos que la Shell libera)
var _fade_rect: ColorRect
var _fade_tw: Tween = null
var _subs: VBoxContainer
var _note_box: VBoxContainer
var _busy := 0                   # >0: transición en curso (el router no abre paneles)

func _init() -> void:
	name = "Shell"

func _ready() -> void:
	world = WorldRootScript.new()
	add_child(world)
	for k in Layers.ALL:
		if k != "drag":
			layers[k] = Layers.make(self, int(Layers.ALL[k]), "Layer_" + k)
	drop_catcher = DropCatcher.new()
	drop_catcher.world = world
	Layers.root_of(layers.drop).add_child(drop_catcher)
	drag_layer = DragLayer.new()
	layers["drag"] = drag_layer
	add_child(drag_layer)
	_build_fade()
	_build_subs()
	router = InputRouter.new()
	router.shell = self
	add_child(router)
	var au := _autoload("Audio")
	if au != null and au.has_signal("subtitle"):
		au.subtitle.connect(_on_subtitle)
	var g := _autoload("Game")
	if g != null and g.has_signal("notice"):
		g.notice.connect(func(key): note(Widgets.t(key)))

func _process(_dt: float) -> void:
	_prune()

# ------------------------------------------------------------------ arranque
func boot(p_opts: Dictionary) -> void:
	opts = p_opts.duplicate()
	fast = bool(opts.get("fast", false))
	sounds = not bool(opts.get("mute", false))
	world.set_fast(fast)
	var g := _autoload("Game")
	if String(opts.get("data", "")) != "" and g != null:
		var r = Fallback.data_repo(String(opts.data))
		if r != null:
			g.repo_override = r
	if String(opts.get("save", "")) != "" and g != null:
		g.save_path = String(opts.save)
	var scr := String(opts.get("screen", ""))
	if scr == "":
		scr = "game" if (bool(opts.get("new", false)) or bool(opts.get("continue", false))) else "title"
	if scr == "title":
		show_title()
		return
	var kind := scr.get_slice(":", 0)
	var arg := scr.substr(kind.length() + 1) if scr.contains(":") else ""
	# capturas y depuración: --screen distinto de game sin --new/--continue usa un registro aparte
	if g != null and kind != "game" and not bool(opts.get("continue", false)) and String(opts.get("save", "")) == "":
		g.save_path = "user://saves/pantalla.jsonl"
	if kind == "reader" and not bool(opts.get("new", false)) and not bool(opts.get("continue", false)):
		_show_bare()
		open_reader(arg)
		return
	if not _start_session(bool(opts.get("continue", false)), int(opts.get("seed", 0))):
		show_title()
		return
	if String(opts.get("script", "")) != "":
		run_script(String(opts.script))
	await enter_game(true)
	match kind:
		"notebook", "ledger", "map":
			open_panel(kind)
		"reader":
			open_reader(arg)
		"place":
			if game_screen != null:
				game_screen.debug_place(arg)
		"epilogue":
			show_epilogue()

func _start_session(cont: bool, seed: int) -> bool:
	var g := _autoload("Game")
	if g == null:
		return false
	if cont:
		return bool(g.continue_session())
	mark_finished(false)
	return bool(g.new_session(seed))

# Aplica un JSONL de acciones (una por línea; «#» comenta) con Game.act. Devuelve cuántas se aceptaron.
func run_script(path: String) -> int:
	var g := _autoload("Game")
	if g == null or g.sim == null:
		return 0
	var n := 0
	var txt := FileAccess.get_file_as_string(path)
	for ln in txt.split("\n"):
		var s := ln.strip_edges()
		if s == "" or s.begins_with("#"):
			continue
		var a = J.parse_str(s)   # como EventLog: enteros del JSON como int (mismo estado que la partida)
		if typeof(a) != TYPE_DICTIONARY:
			push_warning("Shell.run_script: línea ilegible: " + s)
			continue
		var r: Dictionary = g.act(a)
		if bool(r.get("ok", false)):
			n += 1
		else:
			push_warning("Shell.run_script: %s -> %s" % [s, str(r.get("err", ""))])
	return n

# ------------------------------------------------------------------ pantallas
func _set_screen(n: Node, id: String) -> void:
	close_all()
	if screen != null and is_instance_valid(screen):
		if screen.has_method("leave_screen"):
			screen.leave_screen()
		screen.queue_free()
	screen = n
	screen_id = id
	game_screen = n if id == "game" else null
	screen_changed.emit(id)

func _show_bare() -> void:
	_set_screen(Node.new(), "bare")
	add_child(screen)
	world.show_hub("escritorio", "N")

func show_title() -> void:
	var t := Title.new()
	t.shell = self
	_set_screen(t, "title")
	Layers.root_of(layers.hud).add_child(t)
	world.visible = true
	if world.has_method("set_input_enabled"):
		world.set_input_enabled(false)
	world.show_hub("escritorio", "N")
	await fade_in()

# Marca «partida terminada» junto al archivo de guardado (<save>.fin). on=false la borra.
func finished_mark_path() -> String:
	var g := _autoload("Game")
	if g == null:
		return ""
	var p := String(g.save_path)
	if p.begins_with("user://") or p.begins_with("res://"):
		p = ProjectSettings.globalize_path(p)
	return p + ".fin"

func mark_finished(on: bool) -> void:
	var p := finished_mark_path()
	if p == "":
		return
	if on:
		DirAccess.make_dir_recursive_absolute(p.get_base_dir())
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f != null:
			f.store_string("fin\n")
			f.close()
	elif FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)

# Hay una partida que se puede continuar: un guardado que no terminó.
func can_continue() -> bool:
	var g := _autoload("Game")
	if g == null or not bool(g.has_save()):
		return false
	var p := finished_mark_path()
	return p == "" or not FileAccess.file_exists(p)

func new_game(seed := 0) -> void:
	mark_finished(false)
	await fade_out()
	if _start_session(false, seed):
		await enter_game(false)
	else:
		show_title()

func continue_game() -> void:
	await fade_out()
	if _start_session(true, 0):
		await enter_game(false)
	else:
		show_title()

func enter_game(instant := false) -> void:
	var gs = GameScreen.new()
	gs.shell = self
	_set_screen(gs, "game")
	add_child(gs)
	world.set_input_enabled(true)
	await gs.start(instant)

# Fundido al epílogo desde la pantalla de juego (la corrutina vive en la Shell, no en la pantalla que se libera).
func go_epilogue() -> void:
	if screen_id == "epilogue":
		return
	busy(true)
	await fade_out()
	show_epilogue()
	busy(false)
	await fade_in()

func show_epilogue() -> void:
	if not ResourceLoader.exists(PANELS.epilogue.path):
		var fb = Fallback.Epilogue.new()
		fb.shell = self
		_set_screen(fb, "epilogue")
		Layers.root_of(layers.modal).add_child(fb)
		return
	var n := _instance(PANELS.epilogue.path)
	if n == null:
		return
	_set_screen(n, "epilogue")
	_attach(n, "modal")
	_call_flex(n, "open", [])
	if n.has_signal("closed"):
		n.closed.connect(func(): show_title(), CONNECT_ONE_SHOT)

func quit_to_title() -> void:
	var g := _autoload("Game")
	if g != null and g.sim != null:
		# partida terminada (epílogo cerrado): el título ya no ofrece «Continuar» (W4: cargaba la partida en fase done y
		# volvía al título sin decir nada, en bucle). Marca junto al guardado; una partida nueva la borra.
		if String(g.sim.q_clock().get("phase", "")) == "done":
			mark_finished(true)
		g.end_session()
	await fade_out()
	show_title()

# ------------------------------------------------------------------ pila de paneles
func push(n: Node, kind := "") -> void:
	if n == null:
		return
	for e in stack:
		if e.node == n:
			stack.erase(e)
			break
	_set_mouse(n, true)
	stack.append({"kind": kind, "node": n})
	while stack.size() > MAX_STACK:
		var bottom: Dictionary = stack[0]
		if String(bottom.kind) == "reader" and stack.size() > 1:
			bottom = stack[1]
		_close_entry(bottom)
	if n.has_signal("closed") and not n.closed.is_connected(_on_panel_closed):
		n.closed.connect(_on_panel_closed.bind(n))
	panel_opened.emit(kind)
	if _note_box != null and _note_box.get_child_count() > 0:
		_place_notes.call_deferred()

func top() -> Node:
	_prune()
	return null if stack.is_empty() else stack[-1].node

func top_kind() -> String:
	_prune()
	return "" if stack.is_empty() else String(stack[-1].kind)

func is_open(kind: String) -> bool:
	_prune()
	for e in stack:
		if String(e.kind) == kind:
			return true
	return false

func panel(kind: String) -> Node:
	for e in stack:
		if String(e.kind) == kind:
			return e.node
	return _cache.get(kind, null)

# fe_volver: el panel de arriba consume (back) o se cierra. false = la pila estaba vacía.
func pop() -> bool:
	_prune()
	if stack.is_empty():
		return false
	var e: Dictionary = stack[-1]
	var n: Node = e.node
	if String(e.kind) == "reader" and reader != null and bool(reader.tijera):
		reader.set_tijera(false)
		return true
	if n.has_method("back"):
		var r = n.back()
		if r == true:
			return true
	_close_entry(e)
	return true

func close_kind(kind: String) -> void:
	for e in stack.duplicate():
		if String(e.kind) == kind:
			_close_entry(e)

func close_all() -> void:
	for e in stack.duplicate():
		_close_entry(e)
	stack.clear()

func _close_entry(e: Dictionary) -> void:
	stack.erase(e)
	if _note_box != null and _note_box.get_child_count() > 0:
		_place_notes.call_deferred()
	var n: Node = e.node
	if not is_instance_valid(n):
		return
	if n.has_signal("closed") and n.closed.is_connected(_on_panel_closed):
		n.closed.disconnect(_on_panel_closed)
	if n.has_method("close"):
		_call_flex(n, "close", [])
	elif "visible" in n:
		n.visible = false
	_mute_while_fading(n)
	var kind := String(e.kind)
	_free_owned(n, kind)
	panel_closed.emit(kind)

func _on_panel_closed(n: Node) -> void:
	_mute_while_fading(n)
	for e in stack.duplicate():
		if e.node == n:
			stack.erase(e)
			panel_closed.emit(String(e.kind))
			_free_owned(n, String(e.kind))
	if _note_box != null and _note_box.get_child_count() > 0:
		_place_notes.call_deferred()

# Un panel que se cierra con fundido sigue visible unos cuadros: mientras tanto no recibe el mouse (un clic apurado no
# debe caer en un panel que se va). Se restituye a los 0,45 s (todo fundido dura ≤0,4 s) o al volver a la pila.
func _mute_while_fading(n: Node) -> void:
	if not is_instance_valid(n) or not is_inside_tree():
		return
	_set_mouse(n, false)
	var iid := n.get_instance_id()   # por id: el panel puede liberarse antes (no capturar el objeto)
	get_tree().create_timer(0.45).timeout.connect(func():
		var o = instance_from_id(iid)
		if o != null and o is Node:
			_set_mouse(o, true))

static func _set_mouse(n: Node, on: bool) -> void:
	var mode := Control.MOUSE_BEHAVIOR_INHERITED if on else Control.MOUSE_BEHAVIOR_DISABLED
	if n is Control:
		(n as Control).mouse_behavior_recursive = mode
	elif n is CanvasLayer:
		for c in n.get_children():
			if c is Control:
				(c as Control).mouse_behavior_recursive = mode

# Sólo se liberan los paneles que creó open_panel y no se reutilizan; lo que otro empujó (bandeja, catálogo, lector) es
# de quien lo creó: se oculta y nada más.
func _free_owned(n: Node, kind: String) -> void:
	if not is_instance_valid(n) or n == reader or _cache.get(kind, null) == n:
		return
	var iid := n.get_instance_id()
	if _owned.has(iid):
		_owned.erase(iid)
		n.queue_free()

func _prune() -> void:
	for e in stack.duplicate():
		var n = e.node
		if not is_instance_valid(n) or n.is_queued_for_deletion() or ("visible" in n and not n.visible):
			stack.erase(e)
			panel_closed.emit(String(e.kind))
			if is_instance_valid(n) and not n.is_queued_for_deletion():
				_free_owned(n, String(e.kind))

# ------------------------------------------------------------------ paneles por clase
func open_panel(kind: String, args := []) -> Node:
	if _busy > 0 and kind != "options":
		return null
	if not PANELS.has(kind):
		return null
	var spec: Dictionary = PANELS[kind]
	if is_open(kind):
		var n0: Node = panel(kind)
		_call_flex(n0, "open", args)
		push(n0, kind)
		return n0
	var n: Node = _cache.get(kind, null)
	if n == null or not is_instance_valid(n):
		if ResourceLoader.exists(String(spec.path)):
			n = _instance(String(spec.path))
		if n == null:
			n = Fallback.make(kind, self)
		if n == null:
			return null
		_attach(n, String(spec.layer))
		if bool(spec.get("cache", false)):
			_cache[kind] = n
		else:
			_owned[n.get_instance_id()] = true
		if n.has_signal("source_requested") and not n.source_requested.is_connected(_on_source_requested):
			n.source_requested.connect(_on_source_requested)
	if "handle_back" in n:
		n.handle_back = false
	if "sounds" in n:
		n.sounds = sounds   # --mute (capturas, tests) llega también a los paneles de otros paquetes
	if n.has_method("set_shell"):
		n.set_shell(self)
	elif "shell" in n:
		n.shell = self
	if n.has_method("open"):
		_call_flex(n, "open", args)
	if "visible" in n:
		n.visible = true
	push(n, kind)
	return n

func toggle_panel(kind: String) -> void:
	if is_open(kind):
		close_kind(kind)
	else:
		open_panel(kind)

func _instance(path: String) -> Node:
	var s = load(path)
	if s == null:
		return null
	var n = s.new()
	return n if n is Node else null

func _attach(n: Node, layer_name: String) -> void:
	if n.get_parent() != null:
		return
	if n is CanvasLayer:
		add_child(n)
	else:
		Layers.root_of(layers[layer_name]).add_child(n)

# Llama method con los argumentos que admita (sin pasarse ni quedarse corto). Devuelve el resultado o null.
func _call_flex(obj: Object, method: String, args: Array):
	if obj == null or not obj.has_method(method):
		return null
	for m in obj.get_method_list():
		if String(m.name) != method:
			continue
		var total: int = (m.args as Array).size()
		var required: int = total - (m.default_args as Array).size()
		if args.size() < required:
			var padded := args.duplicate()
			while padded.size() < required:
				padded.append(null)
			return obj.callv(method, padded)
		return obj.callv(method, args.slice(0, total))
	return obj.callv(method, args)

# ------------------------------------------------------------------ láminas archivadas (GDD§5: se vuelven a mirar y recortar)
# Lámina por id (PL.<lugar>.<día>.<franja>, PL.prologo, PL.M7…): la muestra la pantalla de juego en el 3D, con su epígrafe
# y «Dejar la lámina»; volver regresa a lo de antes. true si se pudo.
func open_plate(plate_id: String) -> bool:
	if game_screen == null or plate_id == "":
		return false
	var s = sim()
	if s == null or s.q_plate(plate_id).is_empty():
		note(Widgets.t("shell.reader.no"))
		return false
	close_all()
	game_screen.show_doc_plate(plate_id)
	return true

# Láminas archivadas (más recientes primero): [{id, place, day, slot, label}].
func archived_plates() -> Array:
	var s = sim()
	if s == null:
		return []
	var out: Array = []
	var ids: Array = s.st.world.get("plates", {}).keys()
	for pid in ids:
		var sn: Dictionary = s.q_plate(String(pid))
		if sn.is_empty():
			continue
		var place := String(sn.get("place", ""))
		if s.repo.place(place).is_empty() and not s.repo.plate(place).is_empty():
			place = String(s.repo.plate(place).get("place", place))   # lámina fija (PRO, M7): su lugar
		out.append({"id": String(pid), "place": place, "day": int(sn.get("day", 0)), "slot": String(sn.get("slot", "")),
			"tk": int(sn.get("day", 0)) * 10 + int({"dawn": 0, "M": 1, "T": 2, "N": 3, "night": 4}.get(String(sn.get("slot", "")), 0))})
	out.sort_custom(func(a, b):
		if int(a.tk) != int(b.tk):
			return int(a.tk) > int(b.tk)
		return String(a.id) < String(b.id))
	return out

# Doble clic en un recorte del cuaderno cuyo ejemplar es una lámina: se abre la lámina (no el lector).
func _on_source_requested(_clip_id: String, copy: String) -> void:
	var s = sim()
	if s == null or copy == "" or s.q_plate(copy).is_empty():
		return
	for v in s.q_accessible():
		if String(v.get("view", "")) == copy:
			return   # es un documento: lo abre el lector
	open_plate.call_deferred(copy)

# ------------------------------------------------------------------ lector (capa 30)
func ensure_reader() -> CanvasLayer:
	if reader == null or not is_instance_valid(reader):
		reader = Reader.new()
		reader.handle_back = false
		reader.sounds = sounds
		add_child(reader)
		reader.closed.connect(_on_reader_closed)
		reader.plate_requested.connect(_on_plate_requested)
		reader.clipped.connect(_on_reader_clipped)
	return reader

func open_reader(view_id: String) -> bool:
	ensure_reader()
	if not reader.open(view_id):
		note(Widgets.t("shell.reader.no"))
		return false
	push(reader, "reader")
	_scene_under_reader(true)
	return true

func open_view(v: Dictionary) -> bool:
	ensure_reader()
	if not reader.open_view(v):
		return false
	if reader.visible:
		push(reader, "reader")
		_scene_under_reader(true)
	return true

# El lector es a pantalla completa (capa 30); la banda de la escena (capa 40) taparía la hoja: mientras se lee, los
# paneles de escena bajan a la capa 29 (siguen abiertos y en la pila) y vuelven a la 40 al cerrar el lector.
func _scene_under_reader(on: bool) -> void:
	for k in ["scene", "confront"]:
		var n = panel(k)
		if n is CanvasLayer and is_instance_valid(n):
			(n as CanvasLayer).layer = Layers.READER - 1 if on else Layers.SCENE

func reader_open() -> bool:
	return reader != null and is_instance_valid(reader) and reader.visible

func _on_reader_closed() -> void:
	_scene_under_reader(false)
	for e in stack.duplicate():
		if String(e.kind) == "reader":
			stack.erase(e)
			panel_closed.emit("reader")

func _on_reader_clipped(r: Dictionary) -> void:
	if game_screen != null and game_screen.has_method("on_clipped"):
		game_screen.on_clipped(r)

func _on_plate_requested(plate: String) -> void:
	if game_screen != null and game_screen.has_method("show_doc_plate"):
		game_screen.show_doc_plate(plate)

# ------------------------------------------------------------------ fundido (capa 100)
func _build_fade() -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.color = Paper.INKS["negra"]
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.modulate.a = 1.0
	Layers.root_of(layers.fade).add_child(_fade_rect)

func fade_out(seconds := FADE_S) -> void:
	await _fade_to(1.0, seconds)

func fade_in(seconds := FADE_S) -> void:
	await _fade_to(0.0, seconds)

func _fade_to(a: float, seconds: float) -> void:
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP if a > 0.5 else Control.MOUSE_FILTER_IGNORE
	if fast or seconds <= 0.0 or not is_inside_tree():
		_fade_rect.modulate.a = a
		await get_tree().process_frame
		return
	_fade_tw = create_tween()
	_fade_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tw.tween_property(_fade_rect, "modulate:a", a, minf(seconds, 0.4))
	await _fade_tw.finished

func faded() -> bool:
	return _fade_rect.modulate.a > 0.5

# ------------------------------------------------------------------ avisos y subtítulos (capa 90)
# Subtítulos abajo a la derecha (no tapan las tarjetas del centro); líneas de Lisle arriba, al centro.
func _build_subs() -> void:
	var root := Layers.root_of(layers.subs)
	_subs = VBoxContainer.new()
	_subs.name = "Subs"
	_subs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subs.alignment = BoxContainer.ALIGNMENT_END
	_subs.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_subs.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_subs.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subs.offset_right = -22
	_subs.offset_bottom = -18
	_subs.add_theme_constant_override("separation", 6)
	root.add_child(_subs)
	_note_box = VBoxContainer.new()
	_note_box.name = "Notes"
	_note_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_note_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_note_box.offset_top = 22
	_note_box.add_theme_constant_override("separation", 8)
	root.add_child(_note_box)

const SUBS_MAX := 2

# Zona de pantalla que pueden ocupar los subtítulos (abajo a la derecha, hasta SUBS_MAX renglones de 360 px) sin banda
# de escena: la usan los paneles que dejan libre ese pie (el sello del libro mayor). Rect2() si no hay subtítulos.
func subs_rect() -> Rect2:
	var au := _autoload("Audio")
	if not sounds or au == null or not ("subtitles_on" in au) or not bool(au.get("subtitles_on")):
		return Rect2()
	var vs := Layers.vp_size(self)
	var probe := Widgets.subtitle("Mg")
	var lh := probe.get_combined_minimum_size().y
	probe.free()
	var sep := float(_subs.get_theme_constant("separation")) if _subs != null else 6.0
	var h := float(SUBS_MAX) * lh + float(SUBS_MAX - 1) * sep + 18.0 + 8.0
	return Rect2(Vector2(vs.x - 22.0 - 380.0, vs.y - h), Vector2(380.0, h))

# Sube los subtítulos por encima de una banda inferior (panel de escena): px = alto ocupado desde abajo.
func set_subs_inset(px: float) -> void:
	if _subs != null:
		_subs.offset_bottom = -18.0 - maxf(0.0, px)

func _on_subtitle(text: String, seconds: float) -> void:
	if text == "":
		return
	# el mismo sonido otra vez no se apila (dos «papel que cruje» seguidos): se renueva el que ya está
	for c in _subs.get_children():
		if c is Label and (c as Label).text == text and not c.is_queued_for_deletion():
			_subs.remove_child(c)
			c.queue_free()
	var l := Widgets.subtitle(text)
	_subs.add_child(l)
	_trim(_subs, SUBS_MAX)
	_expire(l, seconds)

# Línea de Lisle (forma, nunca contenido): papel chico con letra manuscrita a lápiz. Sin sonido de alerta.
func note(text: String, seconds := NOTE_S) -> void:
	if text == "":
		return
	for c in _note_box.get_children():
		if c.has_meta("text") and String(c.get_meta("text")) == text:
			_note_box.remove_child(c)
			c.queue_free()
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_meta("text", text)
	Widgets.restyle(p, func(): p.add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 12, "shadow": true})))
	var l := Widgets.marginal(text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(minf(560.0, 40.0 + text.length() * 9.0), 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	_note_box.add_child(p)
	_trim(_note_box, 2)
	_expire(p, seconds)
	_place_notes.call_deferred()

# Los avisos van arriba al centro; con un compositor abierto (el informe, el anuncio, el telegrama, la carta: hojas
# centradas que empiezan arriba) se corren al margen izquierdo, bajo el calendario, para no tapar el título de la hoja.
const NOTES_SIDE_KINDS := ["report", "ad", "telegram", "letter"]

func _place_notes() -> void:
	if _note_box == null or not is_instance_valid(_note_box):
		return
	var side := NOTES_SIDE_KINDS.has(top_kind())
	if side:
		_note_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_note_box.grow_horizontal = Control.GROW_DIRECTION_END
		_note_box.position = Vector2(22, 240)
		for c in _note_box.get_children():
			for l in c.get_children():
				if l is Label:
					(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					(l as Label).custom_minimum_size.x = 300.0
	else:
		_note_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_note_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_note_box.offset_top = 22
	_note_box.reset_size()

# Deja a lo sumo n hijos (los más nuevos). Saca del árbol antes de liberar: queue_free no baja la cuenta en el cuadro.
static func _trim(box: Control, n: int) -> void:
	while box.get_child_count() > n:
		var c := box.get_child(0)
		box.remove_child(c)
		c.queue_free()

func clear_notes() -> void:
	for c in _note_box.get_children():
		_note_box.remove_child(c)
		c.queue_free()

func notes() -> Array:
	var out: Array = []
	for c in _note_box.get_children():
		if c.has_meta("text") and not c.is_queued_for_deletion():
			out.append(String(c.get_meta("text")))
	return out

func _expire(c: CanvasItem, seconds: float) -> void:
	if not is_inside_tree():
		return
	var tw := c.create_tween()
	tw.tween_interval(maxf(0.5, seconds))
	tw.tween_property(c, "modulate:a", 0.0, 0.4)
	tw.tween_callback(c.queue_free)

# Mensaje de Lisle para un error del sim (ui_text sim.err.<e>, clip.<e>, …); nunca el contenido.
func err_text(err: String) -> String:
	for k in ["sim.err." + err, "clip." + err, "entry." + err, "pass." + err, "shell.err." + err]:
		var s := Widgets.t(k)
		if s != k:
			return s
	return Widgets.t("core.err.desconocido")

# ------------------------------------------------------------------ utilidades
func _autoload(n: String) -> Node:
	if not is_inside_tree():
		var ml = Engine.get_main_loop()
		return ml.root.get_node_or_null(n) if ml is SceneTree else null
	return get_tree().root.get_node_or_null(n)

func game() -> Node:
	return _autoload("Game")

func sim():
	var g := _autoload("Game")
	return g.sim if g != null else null

func act(a: Dictionary) -> Dictionary:
	var g := _autoload("Game")
	if g == null:
		return {"ok": false, "err": "no_sim"}
	return g.act(a)

func busy(on: bool) -> void:
	_busy = maxi(0, _busy + (1 if on else -1))

func is_busy() -> bool:
	return _busy > 0

func play(id: String) -> void:
	if not sounds:
		return
	var au := _autoload("Audio")
	if au != null:
		au.play(id)

func play_event(ev: String) -> float:
	if not sounds:
		return 0.0
	var au := _autoload("Audio")
	if au != null:
		return float(au.play_event(ev))
	return 0.0

func ambience(place: String, slot: String) -> void:
	if not sounds:
		return
	var au := _autoload("Audio")
	if au != null:
		au.set_place_ambience(place, slot)
