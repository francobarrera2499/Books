# ui/scene/scene_panel.gd — panel de escena: líneas dichas (recortables), personajes y sus verbos (§6.7; GDD §8.7).
# Dueño: W3-SCENEUI. CanvasLayer propio (capa 40, ARCHITECTURE §2.3), como el lector: Shell lo agrega como hijo.
# Uso (Shell/W3): var sp = preload("res://ui/scene/scene_panel.gd").new(); add_child(sp); sp.refresh()
#   Fases: visit (personajes con «Preguntar», «Afirmar», «Presentar»; «Pagar» si el diálogo tiene línea "pago";
#   «Encargar» si tiene "tarea.*" y GameSim.can lo admite) · scene / parklane (sólo líneas y «Continuar» = leave).
#   should_show() -> bool: hay algo que mostrar (fase de escena con líneas o personajes). Shell decide visible.
# API:
#   refresh()                          relee q_clock / q_scene (también se llama solo con Game.sim_changed)
#   present(char, item) -> bool        DropCatcher3D (§6.3): soltar un recorte/asiento sobre el personaje -> 2.º paso
#   focus_char(char)                   clic en el personaje 3D (WorldRoot.character_clicked): abre «Preguntar»
#   open_ask(char, mode) · open_picker(char) · open_pay(char) · open_task(char) · close_sub() -> bool
#   set_tijera(on)                     modo tijera sobre las líneas (C / botón «Tijera» del panel)
#   leave()                            «Salir» (visita; con confirmación si gasta franja) / «Continuar» (escena fija)
# Config: sim (GameSim inyectada; null = Game.sim) · act_fn (null = Game.act) · sounds · show_leave (false: la salida de
#   una visita la da Shell; true: el panel muestra «Salir») · handle_keys (C y fe_volver para sus subpaneles) ·
#   strip_target (adónde vuela la tira recortada; por defecto abajo a la izquierda, el cuaderno).
# Señales: said(res) (ask/assert/present/pay/task aceptado) · clipped(res) · left(res) · sub_changed(name) ("" = ninguno) ·
#   closed (se ocultó: close(), «Continuar»/«Salir» o la fase dejó de ser de escena).
# Protocolo de la pila de Shell (ui/shell.gd, duck typing): open(char := "") (refresca; si el panel ya estaba a la vista y
#   char está presente, abre «Preguntar»; en fase confront delega en shell.open_panel("confront") y se cierra) · close() ·
#   back() -> bool (consume un fe_volver interno: subpanel, confirmación o tijera) · handle_back (= handle_keys; Shell lo
#   pone en false y el volver llega por back()) · toggle_tijera() / tijera · request_present(char, data) (DropCatcher3D).
#   Fase confront: open() y request_present() delegan en la vista de confrontación EN EL CUADRO SIGUIENTE (Shell pone
#   visible = true después de open()): se ocultan y piden shell.open_panel("confront"); lo soltado se vuelve refute(item).
#   Fase prologue: sólo las líneas (recortables), sin verbos. Fases scene/parklane: sin columna de elenco, «Continuar».
# Subpaneles (preguntar, selector, presentar): se acoplan sobre la banda del lado contrario al personaje con quien se habla
#   (posición en pantalla del maniquí: world = WorldRoot inyectado o shell.world; sin mundo, a la derecha).
# Reglas (§6.1): sin contador de preguntas (si ya no contesta, sus verbos de hablar desaparecen tras su línea de cierre),
#   sin brillos, frase exacta antes de hablar, dos pasos para presentar, ≤2 paneles (banda + un subpanel).
# GDD_v2 §C.3 (revelado progresivo, q_ui vía SimLink.flags): al principio la banda con lo dicho y «Preguntar»; «Mostrar»
#   aparece con sc.mostrar (hay algo que mostrar), «Decir» cuando hay afirmaciones posibles, «Pagar»/«Encargar» sólo ante
#   quien los acepta, y «Tijera» con desk.tijera.
extends CanvasLayer

signal said(res: Dictionary)
signal clipped(res: Dictionary)
signal left(res: Dictionary)
signal sub_changed(sub: String)
signal closed

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const SimLink = preload("res://ui/scene/sim_link.gd")
const Transcript = preload("res://ui/scene/transcript.gd")
const AskPanel = preload("res://ui/scene/ask_panel.gd")
const ItemPicker = preload("res://ui/scene/item_picker.gd")
const PresentBar = preload("res://ui/scene/present_bar.gd")
const LisleNote = preload("res://ui/scene/lisle_note.gd")

const LAYER := 40
const BAND_H := 262.0
const MARGIN := 24.0
const CAST_W := 360.0          # cuatro verbos en un renglón aun con la barra de desplazamiento (W4-SLICE: 330 no alcanzaba)
const BAND_MAX_EXTRA := 110.0
const SUB_GAP := 12.0
const TASKS := ["seguir_chico_pell", "seguir_parker"]
const PAY_AMOUNTS := [6, 12, 30]
const PHASES := ["visit", "scene", "parklane", "prologue"]

class CastBlock extends VBoxContainer:
	var char_id := ""
	var panel = null
	func _can_drop_data(_at: Vector2, data) -> bool:
		if typeof(data) != TYPE_DICTIONARY:
			return false
		var k := String(data.get("kind", ""))
		if panel == null or panel.phase != "visit":
			return false
		if k == "ent":
			# un chip del índice = preguntar por ese tema: sólo si todavía contesta (si no, «Preguntar» ya no se ofrece)
			return panel._verbs(char_id).has("ask")
		return k == "clip" or k == "entry"
	func _drop_data(_at: Vector2, data) -> void:
		var k := String(data.get("kind", ""))
		if k == "ent":
			panel.open_ask(char_id, "ask")
			panel.ask_panel.choose(String(data.get("id", "")))
		else:
			panel.present(char_id, {"kind": k, "id": String(data.get("id", ""))})

var link
var shell = null                 # Shell (la asigna open_panel): delegar la confrontación y ubicar al personaje (shell.world)
var world = null                 # WorldRoot opcional (drivers); si es null se usa shell.world
var dock_left := false           # subpaneles a la izquierda (el personaje está en la mitad derecha de la pantalla)
var show_leave := false
var handle_keys := true
var auto_close := true           # se oculta solo cuando la fase deja de ser de escena
var strip_target := Vector2(-1, -1)
var phase := ""
var scene_id := ""
var chars: Array = []

var root: Control
var band: PanelContainer
var transcript
var ask_panel
var picker
var present_bar
var note
var _title: Label
var _tijera_btn: Button
var _cast: VBoxContainer
var _cast_scroll: ScrollContainer
var _sep: VSeparator
var _right: VBoxContainer
var _foot: HBoxContainer
var _conf_queued := false
var _conf_item := {}
var _fly: Control
var _confirm: Control = null
var _picker_char := ""
var _refresh_queued := false
var _connected := false
var _opened := false
var _band_h := BAND_H
var _fit_frames := 0
var _flags := {}                 # q_ui() del último refresco

var sim:
	get: return link.sim_override
	set(v): link.sim_override = v
var act_fn: Callable:
	get: return link.act_fn
	set(v): link.act_fn = v
var sounds: bool:
	get: return link.sounds
	set(v): link.sounds = v
var handle_back: bool:
	get: return handle_keys
	set(v): handle_keys = v
var tijera: bool:
	get: return transcript != null and transcript.tijera

func _init() -> void:
	layer = LAYER
	name = "ScenePanel"
	link = SimLink.new()
	_build()

func _ready() -> void:
	_connect_game()
	refresh()

func _exit_tree() -> void:
	var g := SimLink.autoload("Game")
	if _connected and g != null and g.sim_changed.is_connected(_on_sim_changed):
		g.sim_changed.disconnect(_on_sim_changed)
	_connected = false

# ------------------------------------------------------------------ armado
func _build() -> void:
	root = Control.new()
	root.name = "Raiz"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	band = Widgets.sheet("cuaderno", {"pad": 22})
	band.name = "Banda"
	band.mouse_filter = Control.MOUSE_FILTER_STOP
	band.gui_input.connect(_on_band_input)
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_left = MARGIN
	band.offset_right = -MARGIN
	band.offset_top = -(BAND_H + MARGIN)
	band.offset_bottom = -MARGIN
	root.add_child(band)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	band.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_title = Widgets.source_line("")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_title)
	_tijera_btn = Widgets.ink_button(link.t("sceneui.tijera"))
	_tijera_btn.toggle_mode = true
	_tijera_btn.toggled.connect(set_tijera)
	head.add_child(_tijera_btn)
	left.add_child(head)
	transcript = Transcript.new(link)
	transcript.clipped.connect(_on_clipped)
	transcript.failed.connect(_on_clip_failed)
	transcript.tijera_changed.connect(func(on): _tijera_btn.set_pressed_no_signal(on))
	left.add_child(transcript)
	_sep = VSeparator.new()
	h.add_child(_sep)
	_right = VBoxContainer.new()
	_right.custom_minimum_size = Vector2(CAST_W, 0)
	_right.add_theme_constant_override("separation", 8)
	h.add_child(_right)
	_cast_scroll = ScrollContainer.new()
	_cast_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cast_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.add_child(_cast_scroll)
	_cast = VBoxContainer.new()
	_cast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cast.add_theme_constant_override("separation", 12)
	_cast_scroll.add_child(_cast)
	_foot = HBoxContainer.new()
	_foot.alignment = BoxContainer.ALIGNMENT_END
	_right.add_child(_foot)
	# subpaneles (uno a la vez, sobre la banda, a la derecha)
	ask_panel = AskPanel.new(link)
	ask_panel.said.connect(_on_said)
	ask_panel.failed.connect(_on_failed)
	ask_panel.closed.connect(func(): sub_changed.emit(""))
	_dock(ask_panel, 560.0)
	picker = ItemPicker.new(link)
	picker.picked.connect(_on_picked)
	picker.closed.connect(func(): sub_changed.emit(""))
	_dock(picker, 640.0)
	present_bar = PresentBar.new(link)
	present_bar.done.connect(_on_said)
	present_bar.failed.connect(_on_failed)
	present_bar.closed.connect(func(): sub_changed.emit(""))
	_dock(present_bar, 760.0)
	note = LisleNote.new()
	note.anchor_left = 0.0
	note.anchor_top = 1.0
	note.anchor_bottom = 1.0
	note.offset_left = MARGIN + 18.0
	note.offset_bottom = -(BAND_H + MARGIN + SUB_GAP)
	note.offset_top = note.offset_bottom
	note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(note)
	_fly = Control.new()
	_fly.name = "Vuelo"
	_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fly.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fly)

func _dock(c: Control, w: float) -> void:
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_bottom = -(BAND_H + MARGIN + SUB_GAP)
	c.offset_top = c.offset_bottom
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c.custom_minimum_size = Vector2(w, 0)
	_place(c, false)
	root.add_child(c)

func _place(c: Control, left: bool) -> void:
	var w := c.custom_minimum_size.x
	if left:
		c.anchor_left = 0.0
		c.anchor_right = 0.0
		c.offset_left = MARGIN
		c.offset_right = MARGIN + w
	else:
		c.anchor_left = 1.0
		c.anchor_right = 1.0
		c.offset_right = -MARGIN
		c.offset_left = -MARGIN - w

# Lado de los subpaneles según dónde está el personaje (no tapar a quien se le habla). La nota de Lisle, del otro lado.
func _update_dock(cid: String) -> void:
	var p := char_screen_pos(cid)
	var vw := root.get_viewport_rect().size.x if root.is_inside_tree() else 1600.0
	dock_left = p.x >= 0.0 and p.x > vw * 0.5
	# el cuaderno acoplado ocupa la mitad izquierda (se arrastra de él a la escena): los subpaneles van a la derecha
	if shell != null and is_instance_valid(shell) and shell.has_method("is_open") and bool(shell.is_open("notebook")):
		dock_left = false
	for c in [ask_panel, picker, present_bar]:
		_place(c, dock_left)
	if dock_left:
		note.anchor_left = 1.0
		note.anchor_right = 1.0
		note.offset_right = -(MARGIN + 18.0)
		note.offset_left = note.offset_right
		note.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	else:
		note.anchor_left = 0.0
		note.anchor_right = 0.0
		note.offset_left = MARGIN + 18.0
		note.offset_right = note.offset_left
		note.grow_horizontal = Control.GROW_DIRECTION_END

func _world():
	if world != null and is_instance_valid(world):
		return world
	if shell != null and is_instance_valid(shell) and "world" in shell and shell.world != null and is_instance_valid(shell.world):
		return shell.world
	return null

# Posición en pantalla (canvas) del personaje cid: maniquí (Chars/char_<id>) o silueta (nodo sil_<id>). (-1, -1) si no.
func char_screen_pos(cid: String) -> Vector2:
	var w = _world()
	if w == null or not w.has_method("camera"):
		return Vector2(-1, -1)
	var cam: Camera3D = w.camera()
	var d = w.get("diorama")
	if cam == null or d == null or not is_instance_valid(d) or not cam.is_inside_tree():
		return Vector2(-1, -1)
	var b = d.get_node_or_null("Chars/char_" + cid)
	var p := Vector3.ZERO
	if b is Node3D:
		var aabb: AABB = b.get_meta("aabb", AABB(Vector3(-0.25, 0, -0.2), Vector3(0.5, 1.8, 0.4)))
		p = (b as Node3D).global_transform * aabb.get_center()
	elif w.has_method("node_body") and w.node_body("sil_" + cid) is Node3D:
		p = (w.node_body("sil_" + cid) as Node3D).global_position
	else:
		return Vector2(-1, -1)
	if cam.is_position_behind(p):
		return Vector2(-1, -1)
	return cam.unproject_position(p)

func _connect_game() -> void:
	if _connected or not link.uses_game():
		return
	var g := SimLink.autoload("Game")
	if g != null and g.has_signal("sim_changed"):
		g.sim_changed.connect(_on_sim_changed)
		_connected = true

func _on_sim_changed(kind: String, _payload: Dictionary) -> void:
	if ["line", "visit", "scene", "clock", "index", "flag", "clip", "entry"].has(kind):
		_queue_refresh()

func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	(func():
		_refresh_queued = false
		refresh()).call_deferred()

# ------------------------------------------------------------------ API
func open(char_id := "") -> void:
	var was := _opened and visible
	_opened = true
	visible = true
	refresh()
	if phase == "confront":
		_queue_confront()
		return
	if was and char_id != "" and _present_char(char_id) and sub_open() == "":
		focus_char(char_id)

# En la confrontación este panel no se queda: se oculta y Shell abre la vista de confrontación (si se soltó algo sobre el
# librero, pasa directo al segundo paso de refutar). Diferido: Shell hace visible = true después de open().
func _queue_confront() -> void:
	if _conf_queued:
		return
	_conf_queued = true
	(func():
		_conf_queued = false
		var item := _conf_item
		_conf_item = {}
		close()
		if shell != null and is_instance_valid(shell) and shell.has_method("open_panel"):
			var cv = shell.open_panel("confront")
			if cv != null and not item.is_empty() and cv.has_method("refute"):
				cv.refute(item)).call_deferred()

func close() -> void:
	_opened = false
	close_sub()
	set_tijera(false)
	if visible:
		visible = false
		closed.emit()

func back() -> bool:
	if close_sub():
		sub_changed.emit("")
		return true
	if transcript.tijera:
		set_tijera(false)
		return true
	return false

func toggle_tijera() -> void:
	set_tijera(not transcript.tijera)

func request_present(char_id: String, data: Dictionary) -> bool:
	var item := {"kind": String(data.get("kind", "")), "id": String(data.get("id", ""))}
	phase = String(link.qd("q_clock").get("phase", phase))
	if phase == "confront":
		if not ["clip", "entry"].has(item.kind) or item.id == "":
			return false
		_conf_item = item
		_queue_confront()
		return true
	return present(char_id, item)

func should_show() -> bool:
	var c: Dictionary = link.qd("q_clock")
	if not PHASES.has(String(c.get("phase", ""))):
		return false
	var sc: Dictionary = link.qd("q_scene")
	return not (sc.get("chars", []) as Array).is_empty() or not (sc.get("lines", []) as Array).is_empty()

func refresh() -> void:
	var c: Dictionary = link.qd("q_clock")
	phase = String(c.get("phase", ""))
	if auto_close and visible and is_inside_tree() and phase != "" and not PHASES.has(phase) and phase != "confront":
		close()
		return
	var sc: Dictionary = link.qd("q_scene")
	var sid := String(sc.get("id", ""))
	if sid != scene_id:
		scene_id = sid
		transcript.clear()
		close_sub()
		set_tijera(false)
	chars = (sc.get("chars", []) as Array).duplicate(true)
	var uids: Array = []
	for ln in sc.get("lines", []):
		uids.append(String(ln.get("uid", "")))
	transcript.set_caption(_epigraph(sc))
	transcript.set_narration(phase == "parklane")
	transcript.set_lines(uids, chars)
	_title.text = _title_text(sc, c)
	_flags = link.flags()
	_tijera_btn.visible = link.flag("desk.tijera", _flags)
	if not _tijera_btn.visible and transcript.tijera:
		set_tijera(false)
	_build_cast()

func present(char_id: String, item: Dictionary) -> bool:
	if phase != "visit" or not _present_char(char_id):
		return false
	if not ["clip", "entry"].has(String(item.get("kind", ""))) or String(item.get("id", "")) == "":
		return false
	close_sub()
	_update_dock(char_id)
	present_bar.open_present(char_id, _label_of(char_id), item)
	sub_changed.emit("present")
	return true

func focus_char(char_id: String) -> void:
	if phase != "visit" or not _present_char(char_id):
		return
	if _verbs(char_id).has("ask"):
		open_ask(char_id, "ask")
	elif _verbs(char_id).has("assert"):
		open_ask(char_id, "assert")

func open_ask(char_id: String, mode := "ask") -> void:
	close_sub()
	_update_dock(char_id)
	ask_panel.open(char_id, _label_of(char_id), mode)
	sub_changed.emit("ask")

func open_picker(char_id: String) -> void:
	close_sub()
	_update_dock(char_id)
	_picker_char = char_id
	picker.open(link.t("sceneui.present.title", {"quien": SimLink.cap(_label_of(char_id))}))
	sub_changed.emit("picker")

func open_pay(char_id: String) -> void:
	close_sub()
	_update_dock(char_id)
	present_bar.open_pay(char_id, _label_of(char_id), PAY_AMOUNTS)
	sub_changed.emit("pay")

func open_task(char_id: String) -> void:
	close_sub()
	_update_dock(char_id)
	present_bar.open_task(char_id, _label_of(char_id), _tasks_ok(char_id))
	sub_changed.emit("task")

func close_sub() -> bool:
	var any := false
	for s in [ask_panel, picker, present_bar]:
		if s.visible:
			s.visible = false
			any = true
	if _confirm != null:
		_confirm.queue_free()
		_confirm = null
		any = true
	return any

func sub_open() -> String:
	if ask_panel.visible:
		return "ask"
	if picker.visible:
		return "picker"
	if present_bar.visible:
		return "present"
	if _confirm != null:
		return "confirm"
	return ""

func set_tijera(on: bool) -> void:
	transcript.set_tijera(on)
	_tijera_btn.set_pressed_no_signal(on)

func leave() -> void:
	if phase == "visit" and not _visit_free():
		_ask_leave()
		return
	_do_leave()

func debug_state() -> Dictionary:
	var cast := {}
	for ch in chars:
		cast[String(ch.id)] = _verbs(String(ch.id))
	return {"phase": phase, "scene": scene_id, "lines": transcript.uids(), "cast": cast, "sub": sub_open(),
		"tijera": transcript.tijera, "note": note.text(), "title": _title.text, "dock_left": dock_left, "cast_column": _cast_scroll.visible}

# ------------------------------------------------------------------ elenco
func _build_cast() -> void:
	for c in _cast.get_children():
		_cast.remove_child(c)
		c.queue_free()
	for c in _foot.get_children():
		_foot.remove_child(c)
		c.queue_free()
	# fuera de una visita no hay verbos: sin columna de elenco (sólo «Continuar» al pie, si corresponde)
	var visit := phase == "visit"
	_cast_scroll.visible = visit
	_sep.visible = visit
	_right.custom_minimum_size.x = CAST_W if visit else 0.0
	_right.visible = visit or phase == "scene" or phase == "parklane"
	_right.alignment = BoxContainer.ALIGNMENT_BEGIN if visit else BoxContainer.ALIGNMENT_END
	if visit:
		var first := true
		for ch in chars:
			var cid := String(ch.get("id", ""))
			var vs := _verbs(cid)
			if not first:
				_cast.add_child(Widgets.rule())
			first = false
			_cast.add_child(_cast_block(cid, _label_of(cid), vs))
		if show_leave:
			_foot.add_child(Widgets.ink_button(link.t("sceneui.leave.free" if _visit_free() else "sceneui.leave"), leave))
	elif phase == "scene" or phase == "parklane":
		_foot.add_child(Widgets.button(link.t("sceneui.continue"), _do_leave))
	_fit_band.call_deferred()

# La banda crece lo justo para que el elenco entero quepa sin desplazar (W4: con dos personajes los verbos del segundo
# pasaban a un segundo renglón y «Pagar» quedaba cortado al pie). Tope BAND_MAX_EXTRA.
func _fit_band() -> void:
	# dos cuadros después (los HFlowContainer de los verbos miden su alto con el ancho ya puesto); por _process y no
	# con await: el panel puede liberarse antes
	_fit_frames = 2
	set_process(true)

func _process(_dt: float) -> void:
	if _fit_frames <= 0:
		set_process(false)
		return
	_fit_frames -= 1
	if _fit_frames == 0:
		set_process(false)
		_do_fit_band()

func _do_fit_band() -> void:
	if not is_inside_tree() or band == null:
		return
	var want := BAND_H
	if _cast_scroll.visible:
		var need := _cast.get_combined_minimum_size().y + _foot.get_combined_minimum_size().y + 8.0 + 44.0 + 6.0
		want = clampf(need, BAND_H, BAND_H + BAND_MAX_EXTRA)
	set_band_height(want)

func set_band_height(h: float) -> void:
	if is_equal_approx(h, _band_h):
		return
	_band_h = h
	band.offset_top = -(h + MARGIN)
	note.offset_bottom = -(h + MARGIN + SUB_GAP)
	note.offset_top = note.offset_bottom
	for c in [ask_panel, picker, present_bar]:
		c.offset_bottom = -(h + MARGIN + SUB_GAP)
		c.offset_top = c.offset_bottom

func band_height() -> float:
	return _band_h

func _cast_block(cid: String, label: String, vs: Array) -> Control:
	var b := CastBlock.new()
	b.char_id = cid
	b.panel = self
	b.name = "Personaje_" + cid
	b.add_theme_constant_override("separation", 4)
	var nm := Label.new()
	nm.text = SimLink.short(_cap(label), 40)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Widgets.restyle(nm, func():
		nm.add_theme_font_override("font", SimLink.font("imprenta"))
		nm.add_theme_font_size_override("font_size", int(round(SimLink.px("ui") * 1.16)))
		nm.add_theme_color_override("font_color", Paper.ink("negra")))
	b.add_child(nm)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 2)
	for v in vs:
		var btn := Widgets.ink_button(link.t("sceneui.verb." + String(v)))
		btn.name = "Verbo_" + String(v)
		match String(v):
			"ask":
				btn.pressed.connect(open_ask.bind(cid, "ask"))
			"assert":
				btn.pressed.connect(open_ask.bind(cid, "assert"))
			"present":
				btn.pressed.connect(open_picker.bind(cid))
			"pay":
				btn.pressed.connect(open_pay.bind(cid))
			"task":
				btn.pressed.connect(open_task.bind(cid))
		row.add_child(btn)
	b.add_child(row)
	return b

# Verbos disponibles ahora ante un personaje (en orden). Nada de esto se cuenta en pantalla.
func _verbs(cid: String) -> Array:
	var out: Array = []
	if phase != "visit":
		return out
	var ch: Dictionary = {}
	for x in chars:
		if String(x.get("id", "")) == cid:
			ch = x
	if ch.is_empty():
		return out
	var r = link.repo()
	var dl: Dictionary = r.dialogue(cid) if r != null else {}
	if bool(ch.get("can_ask", false)):
		if not link.qa("q_topics", [cid]).is_empty():
			out.append("ask")
		if not ask_panel.assertions_for(cid).is_empty():
			out.append("assert")
	if link.flag("sc.mostrar", _flags):
		out.append("present")
	var lines: Array = dl.get("lines", [])
	var has_pay := false
	var has_task := false
	for ln in lines:
		var id := String(ln.get("id", "")) if typeof(ln) == TYPE_DICTIONARY else ""
		if id == "pago":
			has_pay = true
		if id.begins_with("tarea."):
			has_task = true
	if has_pay:
		out.append("pay")
	if has_task and not _tasks_ok(cid).is_empty():
		out.append("task")
	return out

func _tasks_ok(cid: String) -> Array:
	var out: Array = []
	for t in TASKS:
		if link.can({"t": "task", "char": cid, "task": t}):
			out.append(t)
	return out

func _present_char(cid: String) -> bool:
	for x in chars:
		if String(x.get("id", "")) == cid:
			return true
	return false

func _label_of(cid: String) -> String:
	# el mismo rótulo que sus líneas (rótulo fijo de la escena, presentado por sí mismo o el del sim), sin mayúscula inicial
	if link.who_override.has(cid):
		return String(link.who_override[cid])
	if SimLink.introduced_by_line(link.sim(), cid):
		return SimLink.proper_name(link.repo(), cid)
	for x in chars:
		if String(x.get("id", "")) == cid:
			return String(x.get("label", cid))
	return link.who_label(cid, chars)

static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s

# ------------------------------------------------------------------ textos
func _title_text(sc: Dictionary, c: Dictionary) -> String:
	var r = link.repo()
	var p := String(sc.get("place", ""))
	var pname := ""
	var lk := "sceneui.lugar.%s.%s" % [p, String(sc.get("area", ""))]
	if link.has_t(lk):
		pname = link.t(lk)
	elif r != null and p != "":
		pname = String(r.place(p).get("name", ""))
		if pname == "":
			pname = String(r.plate(p).get("name", p))
	var when := String(c.get("date_label", ""))
	var sl := String(c.get("slot_label", ""))
	if sl != "":
		when = when + ", " + sl if when != "" else sl
	if pname == "":
		return when
	return pname + " · " + when if when != "" else pname

func _epigraph(sc: Dictionary) -> String:
	var r = link.repo()
	if r == null:
		return ""
	var p := String(sc.get("place", ""))
	var e := ""
	if p != "":
		var pd: Dictionary = r.place(p)
		var by = pd.get("epigraph_by_area", {})
		var ar := String(sc.get("area", ""))
		e = String(by[ar]) if typeof(by) == TYPE_DICTIONARY and ar != "" and by.has(ar) else String(pd.get("epigraph", ""))
	if e == "" and String(sc.get("plate", "")) != "":
		var pl: Dictionary = link.qd("q_plate", [String(sc.plate)])
		var pid := String(pl.get("place", ""))
		if pid != "":
			e = String(r.plate(pid).get("epigraph", ""))
	return e

# ------------------------------------------------------------------ acciones
func _on_said(res: Dictionary) -> void:
	sub_changed.emit("")
	said.emit(res)
	refresh()

func _on_failed(err: String) -> void:
	note.say(link.err_text(err))
	refresh()

func _on_picked(item: Dictionary) -> void:
	if _picker_char != "":
		present(_picker_char, item)

func _on_clipped(res: Dictionary, text: String, pos: Vector2) -> void:
	_fly_strip(text, pos)
	clipped.emit(res)

func _on_clip_failed(err: String) -> void:
	if err == "no_cuadra":
		note.say(link.t("reader.no_cuadra"))
	else:
		note.say(link.err_text(err))

func _visit_free() -> bool:
	var sc: Dictionary = link.qd("q_scene")
	for p in link.qa("q_places"):
		if String(p.get("id", "")) == String(sc.get("place", "")) and String(p.get("area", "")) == String(sc.get("area", "")):
			return bool(p.get("free", false))
	return false

func _ask_leave() -> void:
	close_sub()
	var cf = Widgets.confirm(link.t("sceneui.leave.confirm"), link.t("sceneui.leave.ok"), link.t("sceneui.back"))
	cf.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cf.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cf.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(cf)
	_confirm = cf
	sub_changed.emit("confirm")
	cf.decided.connect(func(ok):
		if _confirm != null:
			_confirm.queue_free()
			_confirm = null
		sub_changed.emit("")
		if ok:
			_do_leave())

func _do_leave() -> void:
	set_tijera(false)
	var res: Dictionary = link.act({"t": "leave"})
	if bool(res.get("ok", false)):
		close_sub()
		left.emit(res)
		refresh()
	else:
		note.say(link.err_text(String(res.get("err", ""))))

# ------------------------------------------------------------------ tira que vuela al cuaderno
func _fly_strip(text: String, from_pos: Vector2) -> void:
	if text == "":
		return
	var strip := PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", Paper.style("cuaderno", {"margin": 10, "margin_v": 4, "radius": 0, "shadow_size": 6, "shadow_y": 3}))
	var l := Label.new()
	l.add_theme_font_override("font", SimLink.font("imprenta"))
	l.add_theme_font_size_override("font_size", SimLink.px("doc"))
	l.add_theme_color_override("font_color", Paper.ink("negra"))
	l.text = SimLink.short(text, 64)
	strip.add_child(l)
	_fly.add_child(strip)
	var sz := strip.get_combined_minimum_size()
	strip.size = sz
	strip.pivot_offset = sz * 0.5
	strip.position = from_pos - sz * 0.5
	strip.rotation_degrees = -1.5
	var vp := root.get_viewport_rect().size if root.is_inside_tree() else Vector2(1600, 900)
	var target := (strip_target if strip_target.x >= 0.0 else Vector2(64.0, vp.y - 40.0)) - sz * 0.5
	var tw := strip.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(strip, "position", target, 0.4)
	tw.tween_property(strip, "scale", Vector2(0.3, 0.3), 0.4)
	tw.tween_property(strip, "rotation_degrees", -10.0, 0.4)
	tw.tween_property(strip, "modulate:a", 0.0, 0.18).set_delay(0.22)
	tw.chain().tween_callback(strip.queue_free)

# ------------------------------------------------------------------ entrada
# Clic derecho sobre la banda = volver (lo consume la GUI, así que no llega al InputRouter de Shell).
func _on_band_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		if not back() and phase != "scene" and phase != "parklane":
			close()
		band.accept_event()

func _unhandled_input(ev: InputEvent) -> void:
	if not visible or not handle_keys:
		return
	if ev.is_action_pressed("fe_volver"):
		if close_sub():
			sub_changed.emit("")
			get_viewport().set_input_as_handled()
		elif transcript.tijera:
			set_tijera(false)
			get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("fe_tijera") and PHASES.has(phase):
		set_tijera(not transcript.tijera)
		get_viewport().set_input_as_handled()
