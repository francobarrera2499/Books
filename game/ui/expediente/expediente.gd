# ui/expediente/expediente.gd — el Expediente Holmes (CanvasLayer 20, «Libros»). Dueño: UI-EXPEDIENTE.
# Contrato: GDD_v3 §1.6 (responder y pasar en limpio), §1.7 (q_dossier, q_answer_options, dq_answer, dq_proof,
# dq_confirm), §6.1 (la vista), §6.2 (tarjetas), §6.10 (preguntas como ítems de informe y de «Mostrar»); reglas de UI
# limpia (ARCHITECTURE §6.1) y arrastre (§6.3).
# Una carpeta de cartón abierta. Izquierda (índice): «El encargo» (abre D23 en el lector), las preguntas abiertas (≤3,
#   con su texto, en la letra de Lisle) y, plegadas, las que ya están «En tinta». Derecha (la hoja elegida): la pregunta,
#   su origen (una línea chica), las dudas de Lisle (lápiz), «Respuesta: ___» (clic -> selector con buscador; o soltar
#   una ficha del Índice del cuaderno), «Pruebas:» con dos ranuras-tarjeta (se sueltan recortes directo desde el
#   cuaderno; soltar sobre una ocupada reemplaza; clic derecho la vacía) y «Pasar en limpio» cuando las tres están
#   llenas. Lápiz = grafito gris; tinta = negra, con la letra de Lisle.
# Pasar en limpio (dq_confirm, de a una hoja): chequeo de forma visible en la voz de Lisle junto a la ranura; si cierra,
#   se borra el lápiz y Lisle escribe su texto en tinta (revelado de 1,5 s, plumín y secante, nada más); la primera
#   tinta de la partida, además, baja la luz un 10 % durante 2 s (momento sobrio). Si no, sólo «Algo no cierra.» debajo
#   del botón, 3 s: nunca dice si falló la respuesta o una prueba. Sin contadores (ni preguntas, ni intentos).
# Con Shell (set_shell): al abrir en casa, el cuaderno se abre acoplado a la izquierda (de ahí se arrastran las pruebas)
#   y se cierra con la carpeta si lo abrió ella; la carpeta va a la derecha. De visita / en escena también a la derecha
#   (a la izquierda queda el 3D: una pregunta se suelta sobre un personaje para mostrarla, {"kind":"pregunta","id"}).
# Uso: var ex = preload("res://ui/expediente/expediente.gd").new(); add_child(ex); ex.open()
#   open(qid := "") · close() · is_open() · select(qid) · refresh() · dock(rect) (Rect2() = automático) · back() -> bool
#   API de automatización (lo mismo que los clics): set_answer(qid, value) · set_proof(qid, slot, clip) ·
#   clear_proof(qid, slot) · confirm(qid) · open_picker(qid) · picker() · open_encargo() ·
#   rect_of(what, i) (pantalla: "respuesta", "prueba", "pasar", "pregunta" (i = índice en el índice), "encargo",
#   "en_tinta", "hoja") · row_rect(qid) · tutor_rect() (lugar libre en la solapa para la nota del instructor) · debug_state()
# Señales: closed · acted(action, result) · question_selected(qid) · inked(qid) · encargo_requested(view).
# Config: act_fn (Callable(a) -> Dictionary; por defecto Game.act) · sim (GameSim o doble; por defecto Game.sim) ·
#   handle_back (Esc propio; el Shell lo pone en false y su pila llama a back()) · sounds · backdrop · auto_notebook.
extends CanvasLayer

signal closed
signal acted(action: Dictionary, result: Dictionary)
signal question_selected(qid: String)
signal inked(qid: String)
signal encargo_requested(view: String)

const Model = preload("res://ui/expediente/expediente_model.gd")
const Picker = preload("res://ui/expediente/answer_picker.gd")
const ClipCard = preload("res://ui/notebook/clip_card.gd")
const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const UiFlags = preload("res://ui/kit/ui_flags.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")

const LAYER := 20
const DESIGN := Vector2(900, 860)
const BODY := Rect2(0, 40, 900, 820)        # el cartón abierto
const TAB := Rect2(20, 2, 176, 50)          # la pestaña con «Holmes»
const INDEX_R := Rect2(24, 66, 240, 776)    # solapa izquierda: el índice
const SHEET_R := Rect2(280, 56, 600, 790)   # la hoja de la pregunta elegida
const CLOSE_POS := Vector2(900, 2)          # «Volver»: arriba a la derecha (se alinea por la derecha)
const PAD := 16.0
const NO_CIERRA_S := 3.0
const INK_REVEAL_S := 1.5
const DIM_S := 2.0
const DIM_A := 0.10
const NOTE_HOLD_S := 3.2
const AWAY_PHASES := ["visit", "scene", "parklane", "confront"]

var act_fn: Callable = Callable()
var sim = null
var handle_back := true
var sounds := true
var backdrop := true
var auto_notebook := true
var auto_dock := true
var area := Rect2()
var shell = null
var side := false
var selected := ""
var flags := {}

var _built := false
var _root: Control
var _back: Control
var _dim: ColorRect
var _stage: Control
var _folder: Control
var _index_scroll: ScrollContainer
var _index: VBoxContainer
var _sheet: PanelContainer
var _sheet_scroll: ScrollContainer
var _sheet_box: VBoxContainer
var _close_btn: Button
var _note: PanelContainer
var _note_label: Label
var _note_tw: Tween = null
var _layer_top: Control
var _picker: Control = null
var _dirty := false
var _sim_conn = null
var _opened_nb := false
var _fresh_ink := ""
var _first_ink := false
var _no_cierra := {}            # qid -> msec hasta cuándo se ve «Algo no cierra.»
var _formal_now := {}           # qid -> [códigos] devueltos por el último intento (forma)
var _rows := {}                 # qid -> QRow (índice)
var _encargo_row: Control = null
var _ink_fold: Control = null
var _answer_btn: Control = null
var _proof_slots: Array = []
var _looked_sent := {}           # qid -> true: ya se avisó al sim que la hoja se vio (examine «sheet/<qid>»)
var _pass_btn: Button = null
var _no_cierra_label: Label = null
var _no_cierra_msg := {}         # qid -> lo que dijo Lisle en el último intento («Algo no cierra.» o «…no se tocan.»)
var _ink_label: Label = null
var _dim_tw: Tween = null
var _sel_hist := ""             # última hoja elegida (se recuerda al cerrar)
var _restore_nb := false        # el lector (encargo) cerró el cuaderno por el tope de dos paneles: vuelve al cerrarlo

# ------------------------------------------------------------------ dibujo
class Backdrop extends Control:
	signal clicked
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			accept_event()
			clicked.emit()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if Paper.hc_on():
			draw_rect(r, Color(0.14, 0.14, 0.14, 0.97))
			return
		draw_rect(r, Color(Paper.MESA.darkened(0.18), 0.9))

# La carpeta de cartón abierta: pestaña con «Holmes», solapa izquierda (más oscura) y pliegue.
class Folder extends Control:
	var title := "Holmes"
	var font: Font = null
	var font_px := 26
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var hc := Paper.hc_on()
		var card := Color(1, 1, 1) if hc else Color("c7a86e")
		var card_l := Color(1, 1, 1) if hc else Color("bc9c61")
		var edge := Color(0, 0, 0) if hc else Color("6f5631")
		# pestaña (detrás del cuerpo, asoma arriba)
		var tab_sb := Paper.flat(card, edge, [1, 1, 1, 0], 8)
		tab_sb.corner_radius_bottom_left = 0
		tab_sb.corner_radius_bottom_right = 0
		draw_style_box(tab_sb, Rect2(TAB.position, TAB.size + Vector2(0, 12)))
		var body := Paper.flat(card, edge, [1, 1, 1, 1], 6)
		if not hc:
			body.shadow_color = Color(0, 0, 0, 0.45)
			body.shadow_size = 14
			body.shadow_offset = Vector2(0, 6)
		draw_style_box(body, BODY)
		# solapa izquierda (la tapa abierta) y el pliegue
		var flap := Rect2(BODY.position + Vector2(8, 8), Vector2(INDEX_R.end.x + 4.0 - BODY.position.x, BODY.size.y - 16))
		draw_rect(flap, card_l, true)
		if not hc:
			var x := flap.end.x
			for i in 6:
				draw_line(Vector2(x + i, BODY.position.y + 6), Vector2(x + i, BODY.end.y - 6), Color(0.2, 0.13, 0.05, 0.16 - 0.025 * i), 1.0)
			# veta del cartón
			for k in 9:
				var y := BODY.position.y + 30.0 + float(k) * (BODY.size.y - 60.0) / 8.0
				draw_line(Vector2(BODY.position.x + 14, y), Vector2(BODY.end.x - 14, y + 2.0), Color(0.35, 0.24, 0.1, 0.035), 1.0)
		else:
			draw_line(Vector2(flap.end.x, BODY.position.y), Vector2(flap.end.x, BODY.end.y), Color(0, 0, 0), 2.0)
		if font != null:
			var ink := Paper.ink("negra")
			var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
			var base := Vector2(TAB.position.x + (TAB.size.x - tw) * 0.5, BODY.position.y - 8.0)
			draw_string(font, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, ink)

# Renglón del índice: una hoja chica con la pregunta (o «El encargo»). Clic = elegir; arrastre = la pregunta como ítem.
class QRow extends PanelContainer:
	signal clicked
	var ex
	var qid := ""
	var drag_text := ""
	var selected := false
	var _press := false
	func _init(p_ex, p_qid: String, p_sel: bool, p_drag_text := "") -> void:
		ex = p_ex
		qid = p_qid
		selected = p_sel
		drag_text = p_drag_text
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var paper := "carta" if selected else "cuaderno"
		var sb := Paper.flat(Paper.paper(paper) if selected else Paper.shade("cuaderno", 0.05), Color(Paper.edge(paper), 0.9 if selected else 0.6), [1, 1, 1, 1], 2, [12, 8, 10, 9])
		if selected and not Paper.hc_on():
			sb.shadow_color = Color(0, 0, 0, 0.28)
			sb.shadow_size = 5
			sb.shadow_offset = Vector2(2, 2)
		if selected:
			sb.border_width_left = 4
			sb.border_color = Paper.ink("negra")
		add_theme_stylebox_override("panel", sb)
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_press = true
			elif _press:
				_press = false
				if Rect2(Vector2.ZERO, size).has_point(ev.position):
					accept_event()
					clicked.emit()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_BEGIN:
			_press = false
	func _get_drag_data(_at: Vector2):
		if qid == "" or qid.begins_with("_"):
			return null
		_press = false
		if is_inside_tree() and get_viewport().gui_is_dragging():
			set_drag_preview(Widgets.chip(drag_text, {"kind": "pregunta", "id": qid}))
		return {"kind": "pregunta", "id": qid}

# Ranura de la respuesta: «___» subrayado; llena, a lápiz. Clic = selector; recibe una ficha del Índice ({"kind":"ent"}).
class AnswerSlot extends Button:
	var ex
	var qid := ""
	var editable := true
	var _hover := false
	func _can_drop_data(_at: Vector2, data) -> bool:
		var ok: bool = editable and typeof(data) == TYPE_DICTIONARY and String(data.get("kind", "")) == "ent" and String(data.get("id", "")) != ""
		_set_hover(ok)
		return ok
	func _drop_data(_at: Vector2, data) -> void:
		_set_hover(false)
		ex.set_answer(qid, String(data.get("id", "")))
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
			_set_hover(false)
	func _set_hover(on: bool) -> void:
		if _hover != on:
			_hover = on
			queue_redraw()
	func _draw() -> void:
		if _hover:
			var c := Paper.ink("lapiz")
			draw_rect(Rect2(Vector2(-4, -2), size + Vector2(8, 4)), Color(c, 0.08), true)

# Ranura de una prueba: vacía, un recuadro de líneas cortadas que invita a soltar; llena, la tarjeta del recorte.
class ProofSlot extends PanelContainer:
	var ex
	var qid := ""
	var slot := 0
	var clip := {}
	var editable := true
	var _hover := false
	func _init(p_ex, p_qid: String, p_slot: int, p_clip, p_editable: bool) -> void:
		ex = p_ex
		qid = p_qid
		slot = p_slot
		clip = p_clip if typeof(p_clip) == TYPE_DICTIONARY else {}
		editable = p_editable
		name = "Prueba_%d" % slot
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_theme_stylebox_override("panel", Paper.empty([0, 0, 0, 0]))
		if clip.is_empty() and editable:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func filled() -> bool:
		return not clip.is_empty()
	func _can_drop_data(_at: Vector2, data) -> bool:
		var ok: bool = editable and typeof(data) == TYPE_DICTIONARY and String(data.get("kind", "")) == "clip" and String(data.get("id", "")) != ""
		_set_hover(ok)
		return ok
	func _drop_data(_at: Vector2, data) -> void:
		_set_hover(false)
		ex.set_proof(qid, slot, String(data.get("id", "")))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and editable and not filled():
			accept_event()
			ex.hint_proof()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
			_set_hover(false)
	func _set_hover(on: bool) -> void:
		if _hover != on:
			_hover = on
			queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var c := Paper.ink("lapiz")
		if not filled():
			if _hover:
				draw_rect(r, Color(c, 0.1), true)
			c.a = 0.85 if _hover else 0.55
			var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
			for i in 4:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				var n := maxi(2, int(a.distance_to(b) / 9.0))
				for k in n:
					if k % 2 == 0:
						draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), c, 1.3)
		elif _hover:
			# soltar sobre una ranura llena reemplaza: una llave a lápiz a la izquierda
			var x := -9.0
			draw_line(Vector2(x, 2), Vector2(x, size.y - 2), c, 1.5)
			draw_line(Vector2(x, 2), Vector2(x + 5, 2), c, 1.5)
			draw_line(Vector2(x, size.y - 2), Vector2(x + 5, size.y - 2), c, 1.5)

# ------------------------------------------------------------------ ciclo
func _init() -> void:
	layer = LAYER
	name = "Expediente"
	visible = false

func _ready() -> void:
	_build()
	var ti := Widgets.ti()
	if ti != null and ti.has_signal("theme_changed") and not ti.theme_changed.is_connected(_on_theme_changed):
		ti.theme_changed.connect(_on_theme_changed)
	var g := _autoload("Game")
	if g != null and g.has_signal("session_started") and not g.session_started.is_connected(_on_session):
		g.session_started.connect(_on_session)
	_connect_sim()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _exit_tree() -> void:
	_disconnect_sim()

static func _autoload(n: String) -> Node:
	var ml = Engine.get_main_loop()
	if ml is SceneTree and ml.root != null:
		return ml.root.get_node_or_null(n)
	return null

func sim_ref():
	if sim != null:
		return sim
	var g := _autoload("Game")
	return g.sim if g != null else null

func _connect_sim() -> void:
	_disconnect_sim()
	if sim != null:
		if sim.has_signal("changed"):
			sim.changed.connect(_on_sim_changed)
			_sim_conn = sim
	else:
		var g := _autoload("Game")
		if g != null and g.has_signal("sim_changed") and not g.sim_changed.is_connected(_on_sim_changed):
			g.sim_changed.connect(_on_sim_changed)
			_sim_conn = g

func _disconnect_sim() -> void:
	if _sim_conn != null and is_instance_valid(_sim_conn):
		for sig in ["changed", "sim_changed"]:
			if _sim_conn.has_signal(sig) and _sim_conn.is_connected(sig, _on_sim_changed):
				_sim_conn.disconnect(sig, _on_sim_changed)
	_sim_conn = null

func set_sim(p_sim) -> void:
	sim = p_sim
	selected = ""
	_no_cierra.clear()
	_formal_now.clear()
	if is_inside_tree():
		_connect_sim()
	_queue_refresh()

func _on_session() -> void:
	selected = ""
	_sel_hist = ""
	_no_cierra.clear()
	_formal_now.clear()
	_hide_note()
	_queue_refresh()

func _on_sim_changed(kind: String, _payload: Dictionary) -> void:
	_queue_refresh()
	if kind == "clock" and shell != null:
		_sync_with_shell.call_deferred()

# Mientras se arrastra algo, el fondo deja pasar el mouse (mostrar una pregunta sobre un personaje, soltar en el 3D).
func _notification(what: int) -> void:
	if _back == null:
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif what == NOTIFICATION_DRAG_END:
		_back.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_theme_changed() -> void:
	ClipCard.clear_looks()
	TextBuilder.clear_caches()
	if _folder != null:
		_folder_font()
		_folder.queue_redraw()
	if _back != null:
		_back.queue_redraw()
	_queue_refresh()

# ------------------------------------------------------------------ Shell (duck typing; ui/shell.gd)
func set_shell(s) -> void:
	shell = s
	if s != null and s.has_signal("panel_opened"):
		if not s.panel_opened.is_connected(_on_shell_opened):
			s.panel_opened.connect(_on_shell_opened)
		if not s.panel_closed.is_connected(_on_shell_closed):
			s.panel_closed.connect(_on_shell_closed)
	_sync_with_shell()

func _on_shell_panel(_kind: String) -> void:
	if visible:
		_sync_with_shell.call_deferred()

# El lector (p. ej. «El encargo») entra como tercer panel: la Shell cierra el de abajo (el cuaderno) antes de anunciar
# el lector. Si el cuaderno se cierra con el lector entrando y la carpeta abierta, al cerrar el lector vuelve a su lugar.
func _on_shell_opened(kind: String) -> void:
	_on_shell_panel(kind)

func _on_shell_closed(kind: String) -> void:
	if kind == "notebook" and visible and _reader_up():
		_restore_nb = true
	elif kind == "reader" and _restore_nb:
		_restore_nb = false
		if visible and not _nb_open():
			_ensure_notebook.call_deferred()
	_on_shell_panel(kind)

func _reader_up() -> bool:
	if not _shell_ok():
		return false
	if shell.has_method("reader_open") and bool(shell.reader_open()):
		return true
	return shell.has_method("top_kind") and String(shell.top_kind()) == "reader"

func _phase() -> String:
	var s = sim_ref()
	if s == null or not s.has_method("q_clock"):
		return ""
	return String(s.q_clock().get("phase", ""))

func _shell_ok() -> bool:
	return shell != null and is_instance_valid(shell) and shell.has_method("is_open")

func _nb_open() -> bool:
	return _shell_ok() and bool(shell.is_open("notebook"))

func _sync_with_shell() -> void:
	if not auto_dock or not _shell_ok():
		return
	side = _nb_open() or AWAY_PHASES.has(_phase())
	_layout()

# Zona de la carpeta acoplada: a la derecha del cuaderno (su book_rect real) o de la mitad de la pantalla; arriba de la
# banda de una escena si la hay.
func side_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600, 900)
	var x := vp.x * 0.45
	if _nb_open():
		var nb = shell.panel("notebook")
		if nb != null and nb.has_method("book_rect"):
			x = (nb.book_rect() as Rect2).end.x + 10.0
	x = clampf(x, 0.0, maxf(0.0, vp.x - 420.0))
	var h := vp.y
	var bt := _scene_band_top()
	if bt > 0.0:
		h = maxf(360.0, bt - 10.0)
	return Rect2(Vector2(x, 0.0), Vector2(vp.x - x, h))

func _scene_band_top() -> float:
	if not _shell_ok() or not shell.has_method("panel"):
		return 0.0
	for k in ["confront", "scene"]:
		if not shell.is_open(k):
			continue
		var p = shell.panel(k)
		if p == null or not is_instance_valid(p):
			continue
		if "visible" in p and not p.visible:
			continue
		var b = p.get("band") if "band" in p else null
		if b is Control and is_instance_valid(b) and b.is_visible_in_tree() and b.size.y > 0.0:
			return b.get_global_rect().position.y
		var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600, 900)
		return vp.y - 290.0
	return 0.0

# Al abrir en casa (con Shell y el cuaderno permitido), el cuaderno se abre acoplado a la izquierda: de ahí salen las
# pruebas. Si lo abrió la carpeta, se cierra con ella.
func _ensure_notebook() -> void:
	if not auto_notebook or not _shell_ok() or not shell.has_method("open_panel"):
		return
	if AWAY_PHASES.has(_phase()) or _nb_open():
		return
	if not UiFlags.on(flags, "hud.cuaderno"):
		return
	# siempre en Recortes: de ahí salen las pruebas (el jugador pudo haberlo dejado en el Diario)
	var nb = shell.open_panel("notebook", ["recortes"])
	_opened_nb = nb != null
	# la carpeta sigue arriba de la pila (Esc la cierra a ella, y con ella el cuaderno que abrió)
	if nb != null and visible and shell.has_method("push") and bool(shell.is_open("dossier")):
		shell.push(self, "dossier")

# El cuaderno acoplado en una pestaña de la que nada se suelta en la carpeta (Diario, Curiosidades) pasa a Recortes;
# con force (clic en una prueba vacía), también desde el Índice.
func _notebook_to_clips(force := false) -> void:
	if not _nb_open() or not shell.has_method("panel"):
		return
	var nb = shell.panel("notebook")
	if nb == null or not is_instance_valid(nb) or not ("tab" in nb) or not nb.has_method("show_tab"):
		return
	var t := String(nb.tab)
	if t != "recortes" and (force or t != "indice"):
		nb.show_tab("recortes")

# ------------------------------------------------------------------ API
func open(qid := "") -> void:
	_build()
	_looked_sent.clear()
	flags = UiFlags.of(sim_ref())
	if qid != "" and qid != null:
		selected = String(qid)
	elif selected == "" and _sel_hist != "":
		selected = _sel_hist
	var was := visible
	visible = true
	if not was:
		_ensure_notebook()
		_notebook_to_clips()
	_sync_with_shell()
	_layout()
	refresh()
	if not was:
		_sfx("sfx.pagina")

func close() -> void:
	_close_overlays()
	_hide_note()
	_stop_dim()
	if not visible:
		return
	_sel_hist = selected
	_restore_nb = false
	visible = false
	if _opened_nb and _shell_ok() and shell.has_method("close_kind") and _nb_open():
		shell.close_kind("notebook")
	_opened_nb = false
	closed.emit()

func is_open() -> bool:
	return visible

func dock(rect: Rect2) -> void:
	area = rect
	_layout()

func select(qid: String) -> void:
	if qid == "":
		return
	selected = qid
	_sel_hist = qid
	refresh()
	question_selected.emit(qid)
	_sfx("sfx.pagina")

func refresh() -> void:
	_dirty = false
	if not _built:
		return
	_rebuild()

func _queue_refresh() -> void:
	if _dirty:
		return
	_dirty = true
	_deferred_refresh.call_deferred()

func _deferred_refresh() -> void:
	if _dirty and visible:
		refresh()

# ------------------------------------------------------------------ armado
func _build() -> void:
	if _built:
		return
	_built = true
	_root = Control.new()
	_root.name = "Raiz"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.name = "Penumbra"
	_dim.color = Color(0, 0, 0, 0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dim)
	_back = Backdrop.new()
	_back.name = "Fondo"
	_back.clicked.connect(_on_backdrop)
	_root.add_child(_back)
	_stage = Control.new()
	_stage.name = "Escenario"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = DESIGN
	_root.add_child(_stage)
	_folder = Folder.new()
	_folder.name = "Carpeta"
	_folder.size = DESIGN
	_folder_font()
	_stage.add_child(_folder)
	# el cartón ataja los clics (no caen al fondo, que cierra)
	var catcher := Control.new()
	catcher.name = "Carton"
	catcher.position = BODY.position
	catcher.size = BODY.size
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.add_child(catcher)
	_index_scroll = ScrollContainer.new()
	_index_scroll.name = "Indice"
	_index_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_index_scroll.position = INDEX_R.position
	_index_scroll.size = INDEX_R.size
	_stage.add_child(_index_scroll)
	_index = VBoxContainer.new()
	_index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_index.add_theme_constant_override("separation", 10)
	_index_scroll.add_child(_index)
	_sheet = PanelContainer.new()
	_sheet.name = "Hoja"
	_sheet.position = SHEET_R.position
	_sheet.size = SHEET_R.size
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	Widgets.restyle(_sheet, func(): _sheet.add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 0, "shadow_size": 6, "shadow_y": 3})))
	_stage.add_child(_sheet)
	_sheet_scroll = ScrollContainer.new()
	_sheet_scroll.name = "Desplazar"
	_sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet.add_child(_sheet_scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(k, 30)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 26)
	_sheet_scroll.add_child(m)
	_sheet_box = VBoxContainer.new()
	_sheet_box.name = "Contenido"
	_sheet_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_box.add_theme_constant_override("separation", 10)
	m.add_child(_sheet_box)
	_close_btn = Widgets.button(Model.tx(null, "exp.volver"), func(): close())
	_close_btn.name = "Volver"
	_stage.add_child(_close_btn)
	_note = Widgets.paper_panel("cuaderno", null, {"margin": 16, "margin_v": 9, "shadow_size": 6})
	_note.name = "NotaLisle"
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_label = Widgets.marginal("")
	_note_label.custom_minimum_size = Vector2(300, 0)
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_child(_note_label)
	_note.visible = false
	_note.modulate.a = 0.0
	_root.add_child(_note)
	_layer_top = Control.new()
	_layer_top.name = "Capa"
	_layer_top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_layer_top)

func _folder_font() -> void:
	var ti := Widgets.ti()
	_folder.font = ti.font("manuscrito") if ti != null else ThemeDB.fallback_font
	_folder.font_px = int(round(float(_px("title")) * 0.72))
	_folder.title = Model.tx(sim_ref(), "exp.tapa")

func _layout() -> void:
	if not _built or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var a := area if area.size.x > 0.0 and area.size.y > 0.0 else Rect2(Vector2.ZERO, vp)
	if side and not (area.size.x > 0.0 and area.size.y > 0.0):
		a = side_rect()
	_back.position = a.position
	_back.size = a.size
	_back.visible = backdrop and not side
	var s := clampf(minf((a.size.x - PAD * 2.0) / DESIGN.x, (a.size.y - PAD * 2.0) / DESIGN.y), 0.4, 1.0)
	_stage.scale = Vector2(s, s)
	_stage.position = (a.position + (a.size - DESIGN * s) * 0.5).floor()
	_close_btn.reset_size()
	_close_btn.position = Vector2(CLOSE_POS.x - _close_btn.size.x, CLOSE_POS.y + 6.0)
	_place_note()

# ------------------------------------------------------------------ estilo
func font(slot: String, italic := false) -> Font:
	var ti := Widgets.ti()
	return ti.font(slot, italic) if ti != null else ThemeDB.fallback_font

func _px(kind: String) -> int:
	var ti := Widgets.ti()
	return int(ti.px(kind)) if ti != null else int({"doc": 21, "ui": 19, "small": 15, "title": 34, "caption": 16}.get(kind, 19))

func tx(key: String, vars := {}) -> String:
	return Model.tx(sim_ref(), key, vars)

# Letra de Lisle: lápiz (grafito gris) o tinta (negra).
func hand(text: String, ink := "lapiz", k := 1.0) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font("manuscrito"))
	var sz := int(round(float(_px("ui")) * 0.92 * k))
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", Paper.ink(ink))
	l.add_theme_constant_override("line_spacing", -int(round(sz * 0.18)))
	return l

func printed(text: String, k := 1.0, italic := false, ink := "negra") -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font("imprenta", italic))
	l.add_theme_font_size_override("font_size", int(round(float(_px("ui")) * k)))
	l.add_theme_color_override("font_color", Paper.ink(ink))
	return l

func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

# ------------------------------------------------------------------ reconstrucción
func _rebuild() -> void:
	var s = sim_ref()
	flags = UiFlags.of(s)
	var keep_i := _index_scroll.scroll_vertical
	var keep_s := _sheet_scroll.scroll_vertical
	var d := Model.dossier(s)
	var all: Array = d.open + d.inked
	var known := all.map(func(h): return String(h.id))
	if selected == "" or not known.has(selected):
		selected = String(d.open[0].id) if not d.open.is_empty() else (String(d.inked[0].id) if not d.inked.is_empty() else "")
	_build_index(s, d)
	var hs := Model.sheet(s, selected)
	_build_sheet(s, hs)
	if not hs.is_empty() and not bool(hs.get("looked", true)):
		_look.call_deferred(String(hs.id))
	_folder.title = tx("exp.tapa")
	_folder.queue_redraw()
	_close_btn.text = tx("exp.volver")
	_layout()
	_restore_scroll.call_deferred(keep_i, keep_s)

func _restore_scroll(i: int, s: int) -> void:
	if is_instance_valid(_index_scroll):
		_index_scroll.scroll_vertical = i
	if is_instance_valid(_sheet_scroll):
		_sheet_scroll.scroll_vertical = s

func _build_index(s, d: Dictionary) -> void:
	_clear(_index)
	_rows.clear()
	var w := INDEX_R.size.x - 8.0
	# El encargo (D23): siempre arriba, con su clip
	var enc := QRow.new(self, "_encargo", false, "")
	enc.name = "Encargo"
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 0)
	ev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var et := printed(tx("exp.encargo"), 1.0)
	et.custom_minimum_size = Vector2(w - 30.0, 0)
	ev.add_child(et)
	var es := printed(tx("exp.encargo.sub"), 0.78, true, "lapiz")
	ev.add_child(es)
	enc.add_child(ev)
	enc.clicked.connect(open_encargo)
	_index.add_child(enc)
	_encargo_row = enc
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_index.add_child(gap)
	if d.open.is_empty() and d.inked.is_empty():
		var e := hand(tx("exp.sin_preguntas"), "lapiz", 0.85)
		e.custom_minimum_size = Vector2(w, 0)
		_index.add_child(e)
	elif d.open.is_empty():
		# playtest v3: con todo en tinta la carpeta quedaba muda (del día 2 a la noche al 4): Lisle dice de dónde sale
		# lo nuevo, sin anunciar ninguna pregunta
		var e2 := hand(tx("exp.sin_abiertas"), "lapiz", 0.85)
		e2.name = "SinAbiertas"
		e2.custom_minimum_size = Vector2(w, 0)
		_index.add_child(e2)
	if not d.open.is_empty():
		var cap := printed(tx("exp.preguntas"), 0.8, true, "lapiz")
		cap.name = "RotuloPreguntas"
		_index.add_child(cap)
	for h in d.open:
		_index.add_child(_qrow(h, w))
	_ink_fold = null
	if not d.inked.is_empty():
		var sel_inked := Model.is_inked(Model.sheet(s, selected))
		var f := Widgets.fold(tx("exp.en_tinta"), "exp.en_tinta", sel_inked)
		f.name = "EnTinta"
		if sel_inked:
			Widgets.set_fold(f, true)   # la hoja elegida está ahí adentro: a la vista
		var content: VBoxContainer = f.get_meta("content")
		content.add_theme_constant_override("separation", 8)
		for h in d.inked:
			content.add_child(_qrow(h, w))
		_index.add_child(f)
		_ink_fold = f

func _qrow(h: Dictionary, w: float) -> Control:
	var qid := String(h.id)
	var inked_q := Model.is_inked(h)
	var r := QRow.new(self, qid, qid == selected, String(h.text))
	r.name = "Pregunta_" + qid
	var l := hand(String(h.text), "negra" if inked_q or qid == selected else "lapiz", 0.86)
	l.custom_minimum_size = Vector2(w - 26.0, 0)
	r.add_child(l)
	r.clicked.connect(select.bind(qid))
	_rows[qid] = r
	return r

func _build_sheet(s, h: Dictionary) -> void:
	_clear(_sheet_box)
	_answer_btn = null
	_proof_slots = []
	_pass_btn = null
	_no_cierra_label = null
	_ink_label = null
	var inner := SHEET_R.size.x - 60.0
	if h.is_empty():
		var dd: Dictionary = Model.dossier(s)
		var ek := "exp.vacia" if not dd.open.is_empty() else ("exp.sin_abiertas" if not dd.inked.is_empty() else "exp.sin_preguntas")
		var e := hand(tx(ek), "lapiz", 0.95)
		e.custom_minimum_size = Vector2(inner, 0)
		_sheet_box.add_child(e)
		return
	var qid := String(h.id)
	var ink := Model.is_inked(h)
	var title := hand(String(h.text), "negra", 1.42)
	title.name = "Pregunta"
	title.custom_minimum_size = Vector2(inner, 0)
	_sheet_box.add_child(title)
	if String(h.origin) != "":
		var o := printed(String(h.origin), 0.8, true, "tenue")
		o.name = "Origen"
		o.custom_minimum_size = Vector2(inner, 0)
		_sheet_box.add_child(o)
	if ink:
		_build_ink(s, h, inner)
		return
	if not (h.doubts as Array).is_empty():
		var dv := VBoxContainer.new()
		dv.name = "Dudas"
		dv.add_theme_constant_override("separation", 2)
		dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for t in h.doubts:
			var dl := hand("– " + String(t), "lapiz", 0.8)
			dl.custom_minimum_size = Vector2(inner - 10.0, 0)
			dv.add_child(dl)
		var dm := MarginContainer.new()
		dm.add_theme_constant_override("margin_left", 10)
		dm.add_theme_constant_override("margin_top", 4)
		dm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dm.add_child(dv)
		_sheet_box.add_child(dm)
	_sheet_box.add_child(_rule())
	# Respuesta
	var ar := HBoxContainer.new()
	ar.name = "FilaRespuesta"
	ar.add_theme_constant_override("separation", 12)
	var al := printed(tx("exp.respuesta.rotulo"), 1.0)
	al.autowrap_mode = TextServer.AUTOWRAP_OFF
	al.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ar.add_child(al)
	_answer_btn = _answer_slot(qid, Model.answer_label(h), true)
	ar.add_child(_answer_btn)
	_sheet_box.add_child(ar)
	# Pruebas
	var pl := printed(tx("exp.pruebas.rotulo"), 1.0)
	pl.name = "RotuloPruebas"
	_sheet_box.add_child(pl)
	# playtest v3: la regla del enlace es pública (antes «Algo no cierra.» con dos pruebas de los rótulos correctos
	# parecía arbitrario)
	var rl := hand(tx("exp.pruebas.regla"), "tenue", 0.78)
	rl.name = "ReglaPruebas"
	rl.custom_minimum_size = Vector2(inner, 0)
	_sheet_box.add_child(rl)
	var pv := VBoxContainer.new()
	pv.name = "Pruebas"
	pv.add_theme_constant_override("separation", ClipCard.CARD_SEP)
	for i in 2:
		var ps := _proof_slot(s, qid, i, h.proofs[i], true, inner)
		pv.add_child(_with_label(h, i, ps, inner))
		_proof_slots.append(ps)
	_sheet_box.add_child(pv)
	# forma: lo que se dice antes de intentar (mismo papel) y lo que dijo el último intento
	var codes: Array = Model.live_formal(h)
	for c in _formal_now.get(qid, []):
		if not codes.has(c) and (String(c) != "falta_respuesta" or h.answer == null) and (String(c) != "faltan_pruebas" or not Model.full(h)):
			codes.append(c)
	for c in codes:
		var fl := hand(Model.formal_text(s, String(c)), "lapiz", 0.82)
		fl.name = "Forma_" + String(c)
		fl.custom_minimum_size = Vector2(inner, 0)
		_sheet_box.add_child(fl)
	if Model.empty_draft(h):
		var hint := hand(tx("exp.hoja.ayuda"), "tenue", 0.78)
		hint.name = "Ayuda"
		hint.custom_minimum_size = Vector2(inner, 0)
		_sheet_box.add_child(hint)
	# Pasar en limpio
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet_box.add_child(sp)
	var br := HBoxContainer.new()
	br.name = "FilaPasar"
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	_pass_btn = Widgets.button(tx("exp.pasar"), func(): confirm(qid))
	_pass_btn.name = "PasarEnLimpio"
	_pass_btn.visible = Model.can_pass(h, flags)
	br.add_child(_pass_btn)
	_sheet_box.add_child(br)
	_no_cierra_label = hand(String(_no_cierra_msg.get(qid, tx("exp.no_cierra"))), "lapiz", 1.0)
	_no_cierra_label.name = "NoCierra"
	_no_cierra_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_cierra_label.custom_minimum_size = Vector2(inner, 0)
	var until := int(_no_cierra.get(qid, 0))
	_no_cierra_label.visible = until > Time.get_ticks_msec()
	_sheet_box.add_child(_no_cierra_label)
	if _no_cierra_label.visible:
		_fade_no_cierra(qid, until)

func _build_ink(s, h: Dictionary, inner: float) -> void:
	var qid := String(h.id)
	_sheet_box.add_child(_rule())
	var t := hand(String(h.ink_text), "negra", 1.06)
	t.name = "Tinta"
	t.custom_minimum_size = Vector2(inner, 0)
	_sheet_box.add_child(t)
	_ink_label = t
	if _fresh_ink == qid:
		t.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING   # la hoja no se reacomoda mientras escribe
		t.visible_ratio = 0.0
		var tw := t.create_tween()
		tw.tween_property(t, "visible_ratio", 1.0, INK_REVEAL_S)
		_fresh_ink = ""
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet_box.add_child(sp)
	var ar := HBoxContainer.new()
	ar.name = "FilaRespuesta"
	ar.add_theme_constant_override("separation", 12)
	var al := printed(tx("exp.tinta.respuesta"), 0.92)
	al.autowrap_mode = TextServer.AUTOWRAP_OFF
	ar.add_child(al)
	var av := hand(Model.answer_label(h), "negra", 0.92)
	av.name = "Respuesta"
	av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ar.add_child(av)
	_sheet_box.add_child(ar)
	var pl := printed(tx("exp.tinta.pruebas"), 0.92)
	_sheet_box.add_child(pl)
	var pv := VBoxContainer.new()
	pv.name = "Pruebas"
	pv.add_theme_constant_override("separation", ClipCard.CARD_SEP)
	for i in 2:
		var ps := _proof_slot(s, qid, i, h.proofs[i], false, inner)
		pv.add_child(_with_label(h, i, ps, inner))
		_proof_slots.append(ps)
	_sheet_box.add_child(pv)

# Ranura con su rótulo encima, en el lápiz de Lisle (playtest v3: «Prueba de que me vigila de cerca» / «Prueba de quién
# es»: cada prueba muestra una mitad; el orden no importa). Sin rótulos (pregunta sin «pruebas»), la ranura sola.
func _with_label(h: Dictionary, i: int, ps: Control, inner: float) -> Control:
	var pls: Array = h.get("proof_labels", [])
	if i >= pls.size() or String(pls[i]) == "":
		return ps
	var box := VBoxContainer.new()
	box.name = "ConRotulo_%d" % i
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := hand(String(pls[i]), "lapiz", 0.8)
	l.name = "RotuloPrueba_%d" % i
	l.custom_minimum_size = Vector2(inner, 0)
	box.add_child(l)
	box.add_child(ps)
	return box

# La primera vez que se muestra una hoja, la carpeta avisa al sim (examine «sheet/<qid>»): Pendientes deja de anunciar
# «Una pregunta nueva en el expediente.» por ella (playtest v3). Una vez por hoja y sesión.
func _look(qid: String) -> void:
	if qid == "" or _looked_sent.has(qid) or not visible:
		return
	_looked_sent[qid] = true   # una vez por apertura (open() lo limpia): si el sim lo rechaza no se reintenta en bucle
	_do({"t": "examine", "ref": "sheet/" + qid})

func _rule() -> Control:
	var r := Widgets.rule()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _answer_slot(qid: String, label: String, editable: bool) -> AnswerSlot:
	var b := AnswerSlot.new()
	b.ex = self
	b.qid = qid
	b.editable = editable
	b.name = "Respuesta"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var filled := label != ""
	b.text = label if filled else tx("exp.respuesta.vacia")
	b.tooltip_text = tx("exp.respuesta.ayuda")
	var lapiz := Paper.ink("lapiz")
	var negra := Paper.ink("negra")
	var n := Paper.flat(Color(0, 0, 0, 0), Color(lapiz, 0.8), [0, 0, 0, 1], 0, [4, 0, 4, 3])
	var hv := Paper.flat(Color(negra, 0.05), negra, [0, 0, 0, 1], 0, [4, 0, 4, 3])
	var p := Paper.flat(Color(negra, 0.09), negra, [0, 0, 0, 2], 0, [4, 0, 4, 2])
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("focus", Paper.empty())
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_font_override("font", font("manuscrito"))
	var sz := int(round(float(_px("ui")) * 0.95))
	b.add_theme_font_size_override("font_size", sz)
	var col := lapiz if filled else Color(Paper.ink("tenue"), 0.95)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, col)
	b.custom_minimum_size = Vector2(220, maxf(34.0, sz * 1.6))
	b.pressed.connect(func(): open_picker(qid))
	return b

func _proof_slot(s, qid: String, i: int, c, editable: bool, w: float) -> ProofSlot:
	var ps := ProofSlot.new(self, qid, i, c, editable)
	ps.custom_minimum_size = Vector2(w, 0 if ps.filled() else 70.0)
	if ps.filled():
		var card := ClipCard.tarjeta(s, ps.clip, w, {"tooltip": false, "size_k": 0.86 if editable else 0.8, "name": "Tarjeta"})
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ps.add_child(card)
		var tips: Array = []
		var ents := ClipCard.entity_labels(ps.clip)
		if not ents.is_empty():
			tips.append("; ".join(PackedStringArray(ents)))
		if editable:
			tips.append(tx("exp.prueba.quitar"))
		ps.tooltip_text = "\n".join(PackedStringArray(tips))
	else:
		var l := hand(tx("exp.prueba.vacia") if editable else "—", "tenue", 0.8)
		l.name = "Vacia"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(w - 24.0, 0)
		ps.add_child(l)
	return ps

# ------------------------------------------------------------------ acciones
func _do(a: Dictionary) -> Dictionary:
	var r := {}
	if act_fn.is_valid():
		var x = act_fn.call(a)
		r = x if typeof(x) == TYPE_DICTIONARY else {"ok": false, "err": "desconocido"}
	elif sim != null:
		r = sim.apply(a)
	else:
		var g := _autoload("Game")
		r = g.act(a) if g != null and g.sim != null else {"ok": false, "err": "no_sim"}
	acted.emit(a, r)
	_queue_refresh()
	return r

func set_answer(qid: String, value: String) -> Dictionary:
	var r := _do({"t": "dq_answer", "q": qid, "value": value})
	if bool(r.get("ok", false)):
		_formal_now.erase(qid)
		_no_cierra.erase(qid)
		_sfx("sfx.papel")
	else:
		say(Model.err_text(sim_ref(), String(r.get("err", ""))))
	return r

func set_proof(qid: String, slot: int, clip: String) -> Dictionary:
	var r := _do({"t": "dq_proof", "q": qid, "slot": slot, "clip": clip})
	if bool(r.get("ok", false)):
		_formal_now.erase(qid)
		_no_cierra.erase(qid)
		_sfx("sfx.papel")
	else:
		say(Model.err_text(sim_ref(), String(r.get("err", ""))))
	return r

func clear_proof(qid: String, slot: int) -> Dictionary:
	return set_proof(qid, slot, "")

# Pasar en limpio una hoja. Forma: Lisle dice qué falta junto a la ranura (no cuenta como intento). Contenido: tinta, o
# sólo «Algo no cierra.» debajo del botón.
func confirm(qid: String) -> Dictionary:
	_close_overlays()
	var s = sim_ref()
	var before := Model.inked_ids(s).size()
	var r := _do({"t": "dq_confirm", "q": qid})
	if String(r.get("err", "")) == "formal":
		var codes: Array = []
		for c in r.get("formal", []):
			codes.append(String(c.get("code", "")) if typeof(c) == TYPE_DICTIONARY else String(c))
		_formal_now[qid] = codes
		if not codes.is_empty():
			say(Model.formal_text(s, String(codes[0])))
	elif bool(r.get("ok", false)):
		_formal_now.erase(qid)
		if bool(r.get("inked", false)):
			_no_cierra.erase(qid)
			_fresh_ink = qid
			selected = qid
			_sel_hist = qid
			_sfx("sfx.plumin")
			_first_ink = bool(r.get("first", before == 0))
			if _first_ink:
				_sober_moment()   # §1.6.4: sólo el plumín
			else:
				_sfx_later("sfx.secante", 1.1)
			inked.emit(qid)
		else:
			_no_cierra[qid] = Time.get_ticks_msec() + int(NO_CIERRA_S * 1000.0)
			var m := String(r.get("msg", ""))
			if m != "": _no_cierra_msg[qid] = m
			else: _no_cierra_msg.erase(qid)
	else:
		say(Model.err_text(s, String(r.get("err", ""))))
	refresh()
	return r

func _fade_no_cierra(qid: String, until: int) -> void:
	if _no_cierra_label == null:
		return
	var lab := _no_cierra_label
	var left := maxf(0.2, float(until - Time.get_ticks_msec()) / 1000.0)
	lab.modulate.a = 1.0
	var tw := lab.create_tween()
	tw.tween_interval(maxf(0.0, left - 0.4))
	tw.tween_property(lab, "modulate:a", 0.0, minf(0.4, left))
	tw.tween_callback(func():
		if is_instance_valid(lab):
			lab.visible = false
		if int(_no_cierra.get(qid, 0)) <= Time.get_ticks_msec():
			_no_cierra.erase(qid))

# Primera tinta de la partida: la luz baja un 10 % durante 2 s; sólo el plumín. Sin cartel, sin música, sin contador.
func _sober_moment() -> void:
	_stop_dim()
	if _dim == null or not is_inside_tree():
		return
	_dim.color = Color(0, 0, 0, 0)
	_dim_tw = _dim.create_tween()
	_dim_tw.tween_property(_dim, "color:a", DIM_A, 0.3)
	_dim_tw.tween_interval(DIM_S - 0.6)
	_dim_tw.tween_property(_dim, "color:a", 0.0, 0.3)

func _stop_dim() -> void:
	if _dim_tw != null and _dim_tw.is_valid():
		_dim_tw.kill()
	_dim_tw = null
	if _dim != null:
		_dim.color = Color(0, 0, 0, 0)

func hint_proof() -> void:
	# sin un solo recorte no hay cuaderno que mostrar: Lisle dice de dónde salen
	say(tx("exp.prueba.ayuda") if UiFlags.on(flags, "hud.cuaderno") else tx("exp.prueba.sin_recortes"))
	_ensure_notebook()
	_notebook_to_clips(true)

func open_encargo() -> void:
	var v := Model.encargo_view(sim_ref())
	encargo_requested.emit(v)
	if v == "":
		return
	if _shell_ok() and shell.has_method("open_reader"):
		# la carpeta arriba de la pila: con el lector como tercer panel, la Shell cierra el cuaderno (que vuelve) y no ella
		if shell.has_method("push") and shell.has_method("top_kind") and String(shell.top_kind()) != "dossier" and bool(shell.is_open("dossier")):
			shell.push(self, "dossier")
		shell.open_reader(v)

# ------------------------------------------------------------------ selector de la respuesta
func open_picker(qid: String) -> void:
	var s = sim_ref()
	var h := Model.sheet(s, qid)
	if h.is_empty() or Model.is_inked(h):
		return
	_close_overlays()
	var opts: Array = Model.answer_options(s, qid)
	if h.answer != null:
		opts.append({"id": "", "text": tx("exp.picker.borrar"), "clear": true})
	var p := Picker.new()
	var anchor := _answer_btn.get_global_rect() if _answer_btn != null and is_instance_valid(_answer_btn) and _answer_btn.is_inside_tree() else Rect2(get_viewport().get_visible_rect().size * 0.5, Vector2(360, 0))
	p.setup(tx("exp.picker.titulo"), opts, anchor, {"empty": tx("exp.picker.vacio"), "search": tx("exp.picker.buscar"),
		"more": tx("exp.picker.mas"), "none": tx("exp.picker.nada")})
	p.chosen.connect(func(id: String, _o):
		_close_overlays()
		set_answer(qid, id))
	p.dismissed.connect(_close_overlays)
	_layer_top.add_child(p)
	_picker = p

func picker() -> Control:
	return _picker if _picker != null and is_instance_valid(_picker) else null

func _close_overlays() -> void:
	if _layer_top == null:
		return
	for ch in _layer_top.get_children():
		_layer_top.remove_child(ch)
		ch.queue_free()
	_picker = null

# ------------------------------------------------------------------ volver
func back() -> bool:
	if picker() != null:
		_picker.dismiss()
		return true
	if not visible:
		return false
	close()
	return true

func _on_backdrop() -> void:
	if picker() != null:
		_close_overlays()
		return
	close()

# Clic derecho: sobre una prueba (a lápiz) la saca; sobre el resto de la carpeta, volver. Se mira en _input porque los
# controles de la hoja consumen los clics y el InputRouter no los vería.
func _input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventMouseButton and ev.pressed and _is_back_button(ev):
		var hov := get_viewport().gui_get_hovered_control()
		if hov == null or not _root.is_ancestor_of(hov):
			return
		var ps := _slot_of(hov)
		if ps != null and picker() == null:
			if ps.editable and ps.filled():
				clear_proof(ps.qid, ps.slot)
			get_viewport().set_input_as_handled()
			return
		back()
		get_viewport().set_input_as_handled()

# Clic derecho que resuelve la carpeta (InputRouter lo pregunta antes de «volver»): sobre una prueba a lápiz, la saca.
func context_click(hov: Node, _at: Vector2) -> bool:
	if not visible or hov == null or _root == null or not _root.is_ancestor_of(hov) or picker() != null:
		return false
	var ps := _slot_of(hov)
	if ps == null:
		return false
	if ps.editable and ps.filled():
		clear_proof(ps.qid, ps.slot)
	return true

func _slot_of(n: Node) -> ProofSlot:
	var c := n
	while c != null and c != _root:
		if c is ProofSlot:
			return c
		c = c.get_parent()
	return null

func _is_back_button(mb: InputEventMouseButton) -> bool:
	if InputMap.has_action("fe_volver"):
		return InputMap.event_is_action(mb, "fe_volver")
	return mb.button_index == MOUSE_BUTTON_RIGHT

func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if InputMap.has_action("fe_volver") and ev.is_action_pressed("fe_volver"):
			if handle_back or picker() != null:
				back()
				get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ Lisle
func say(text: String) -> void:
	if text == "" or _note == null:
		return
	_note_label.text = text
	_note.visible = true
	_place_note()
	if _note_tw != null and _note_tw.is_valid():
		_note_tw.kill()
	_note_tw = _note.create_tween()
	_note_tw.tween_property(_note, "modulate:a", 1.0, 0.2)
	_note_tw.tween_interval(NOTE_HOLD_S)
	_note_tw.tween_property(_note, "modulate:a", 0.0, 0.4)
	_note_tw.tween_callback(func(): _note.visible = false)

func last_note() -> String:
	return _note_label.text if _note_label != null and _note != null and _note.visible else ""

func _hide_note() -> void:
	if _note_tw != null and _note_tw.is_valid():
		_note_tw.kill()
	_note_tw = null
	if _note != null:
		_note.visible = false
		_note.modulate.a = 0.0

func _place_note() -> void:
	if _note == null or not _note.visible:
		return
	_note.reset_size()
	var s := _stage.scale.x
	var c := _stage.position + Vector2((SHEET_R.position.x + SHEET_R.size.x * 0.5) * s, (BODY.end.y - 22.0) * s)
	_note.position = Vector2(c.x - _note.size.x * 0.5, c.y - _note.size.y)

func _sfx(id: String) -> void:
	if not sounds:
		return
	var au := _autoload("Audio")
	if au != null and au.has_method("play"):
		au.play(id)

func _sfx_later(id: String, seconds: float) -> void:
	if not sounds or not is_inside_tree():
		return
	get_tree().create_timer(seconds).timeout.connect(func(): _sfx(id))

# ------------------------------------------------------------------ pruebas y drivers
# Rect en pantalla de una parte de la carpeta: "respuesta", "prueba" (i = 0/1), "pasar", "pregunta" (i = orden en el
# índice: abiertas y luego en tinta), "encargo", "en_tinta", "hoja" (la hoja de la pregunta elegida).
func rect_of(what: String, i := 0) -> Rect2:
	var c: Control = null
	match what:
		"respuesta":
			c = _answer_btn
		"prueba":
			c = _proof_slots[i] if i >= 0 and i < _proof_slots.size() else null
		"pasar":
			c = _pass_btn
		"pregunta":
			var ids := Model.ids(sim_ref())
			c = _rows.get(String(ids[i]), null) if i >= 0 and i < ids.size() else null
		"encargo":
			c = _encargo_row
		"en_tinta":
			c = _ink_fold.get_meta("header") if _ink_fold != null else null
		"hoja":
			c = _sheet
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return Rect2()
	return c.get_global_rect()

# Lugar libre (pantalla) en la solapa del índice, debajo de las preguntas: ahí puede acoplarse la nota del instructor
# (GameScreen._tutor_dock, UI-MUNDO). Rect2() si no queda lugar.
func tutor_rect() -> Rect2:
	if not visible or _index_scroll == null or not _index_scroll.is_inside_tree():
		return Rect2()
	# con el lector encima (el encargo), la carpeta queda tapada: su solapa no es lugar para la nota (caería sobre el
	# texto del documento)
	if _reader_up():
		return Rect2()
	var r: Rect2 = _index_scroll.get_global_rect()
	var used := _index.get_combined_minimum_size().y * _stage.scale.y
	var top := r.position.y + used + 18.0 * _stage.scale.y
	var out := Rect2(r.position.x, top, r.size.x, r.end.y - top)
	return out if out.size.y >= 120.0 else Rect2()

func row_rect(qid: String) -> Rect2:
	var c = _rows.get(qid, null)
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return Rect2()
	return c.get_global_rect()

func debug_state() -> Dictionary:
	var s = sim_ref()
	var h := Model.sheet(s, selected)
	var d := Model.dossier(s)
	var proofs: Array = []
	for ps in _proof_slots:
		proofs.append(String(ps.clip.get("id", "")) if is_instance_valid(ps) else "")
	var shown_words := 0
	for ps in _proof_slots:
		if is_instance_valid(ps) and ps.filled():
			shown_words = maxi(shown_words, Model.words(ClipCard.shown_text(ps.clip)))
	return {"open": visible, "selected": selected, "open_ids": d.open.map(func(x): return String(x.id)),
		"inked_ids": d.inked.map(func(x): return String(x.id)), "index_rows": _rows.keys(),
		"state": String(h.get("state", "")), "answer": Model.answer_label(h), "proofs": proofs,
		"pass": _pass_btn != null and is_instance_valid(_pass_btn) and _pass_btn.visible,
		"no_cierra": _no_cierra_label != null and is_instance_valid(_no_cierra_label) and _no_cierra_label.visible,
		"ink_text": _ink_label.text if _ink_label != null and is_instance_valid(_ink_label) else "",
		"note": last_note(), "picker": picker() != null, "side": side, "scale": _stage.scale.x if _stage != null else 0.0,
		"rect": Rect2(_stage.position, DESIGN * _stage.scale.x) if _stage != null else Rect2(),
		"ink_folded": _ink_fold != null and not bool(_ink_fold.get_meta("open", false)), "has_ink_fold": _ink_fold != null,
		"formal": (_formal_now.get(selected, []) as Array).duplicate(), "max_words_shown": shown_words,
		"dim": _dim.color.a if _dim != null else 0.0, "opened_notebook": _opened_nb}
