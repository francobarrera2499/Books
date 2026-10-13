# ui/ledger/ledger.gd — el libro mayor, la «Fe de erratas» (CanvasLayer 20, «Libros»). Dueño: W3-LEDGER.
# Contrato: ARCHITECTURE §6.6 (+ §6.1 UI limpia, §6.3 arrastre), GDD§8.0–8.6, §14.1–14.2.
# Uso (Shell/W3): var lg = preload("res://ui/ledger/ledger.gd").new(); add_child(lg); lg.open()   (tecla L)
#   open(page := "")   "" = la última página vista (la primera vez, «Reglas del asiento») · "varios" · "erratas" · FOnnn
#   close() · is_open() · show_page(pid) · select_entry(eid) · refresh() · dock(rect) (zona de pantalla; Rect2() = toda)
#   back() -> bool (volver: elector > confirmación > asiento del acoplado > cierra el libro; true = consumido)
# Señales: closed · acted(action, result) (cada acción propia, ya aplicada) · page_changed(pid) · entry_selected(eid).
# Config: act_fn (Callable(a)->Dictionary; por defecto Game.act) · sim (GameSim; por defecto Game.sim) · handle_back
#   (true: Esc lo maneja el libro; el Shell lo pone en false y su pila llama a back(); el clic derecho sobre el libro
#   siempre es volver) · handle_hotkey (L cierra; sólo sin Shell) · sounds · backdrop (clic en el fondo = cerrar).
# Con Shell (set_shell, protocolo por duck typing de ui/shell.gd): si el cuaderno está abierto (va a la izquierda) o hay
#   visita/escena/confrontación (presentar = soltar sobre el 3D), el libro se acopla solo a la mitad derecha
#   (auto_dock); durante un arrastre el fondo deja pasar el ratón.
# Libro abierto en dos páginas + pestañas al canto + el sello «Visto» con su tampón:
#   pestañas: Reglas · Varios · Folio n (con las primeras palabras del recorte que lo abrió) · Erratas inocentes ·
#     «Nuevo folio» (clic -> elegir el recorte; o soltar ahí un recorte {"kind":"clip"} -> folio_open).
#   izquierda: la página (folio_page.gd) · derecha: el asiento abierto (entry_view.gd); en «Reglas», las reglas
#     (GDD§8.0) y el modo de asentar con las plantillas (rules_page.gd).
#   sello (seal.gd): el jugador marca exactamente lot_size asientos a lápiz («Al sello») y estampa: confirmación en dos
#     pasos con lo que se pasa -> pass_clean -> con tinta: plumín, secante y golpe (Audio «pasada_tinta»), los asientos
#     quedan en tinta con su «Visto»; si no: golpe seco («pasada_seca») y Lisle dice sólo «Alguno no se sostiene.».
#     El tampón se ve seco mientras passes_left == 0. La práctica (C1, prólogo y «Erratas inocentes») tiene su propio
#     «Pasar en limpio» por asiento, sin gastar el sello.
# Todo con el mouse; nada distingue lo importante (sin brillos, contadores ni pistas); el chequeo formal se lee en la
# voz de Lisle junto a la línea. Animaciones ≤0,4 s sin rebote. Respeta text_scale y alto contraste (reconstruye).
# API de automatización (lo mismo que hacen los clics; tests y drivers): new_folio_from(clip) · new_entry(tid) ·
#   set_field(eid, line, field, value) · add_support(eid, line, item) · remove_support(eid, line, item) ·
#   toggle_lot(eid) · stamp() (abre la confirmación) · confirm_stamp() · practice(eid) · delete_entry(eid) ·
#   picker() / confirm_dialog() (lo abierto en la capa superior) · debug_state().
extends CanvasLayer

signal closed
signal acted(action: Dictionary, result: Dictionary)
signal page_changed(pid: String)
signal entry_selected(eid: String)

const L = preload("res://core/util/log.gd")
const Markup = preload("res://core/text/markup.gd")
const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")
const Model = preload("res://ui/ledger/ledger_model.gd")
const RulesPage = preload("res://ui/ledger/rules_page.gd")
const FolioPage = preload("res://ui/ledger/folio_page.gd")
const EntryView = preload("res://ui/ledger/entry_view.gd")
const Seal = preload("res://ui/ledger/seal.gd")
const Picker = preload("res://ui/ledger/picker.gd")

const LAYER := 20
const DESIGN := Vector2(1560, 860)
const BOOK := Rect2(0, 0, 1330, 860)
const PAGE_L := Rect2(18, 18, 638, 824)
const PAGE_R := Rect2(674, 18, 638, 824)
const COL := Rect2(1318, 30, 242, 520)
const SEAL_R := Rect2(1346, 588, 214, 272)
# Acoplado angosto (p. ej. junto al cuaderno): una sola página que alterna entre la lista y el asiento abierto.
const COMPACT_BELOW := 1150.0
const MIN_H_C := 440.0          # alto mínimo de diseño del libro acoplado
const DESIGN_C := Vector2(930, 860)
const BOOK_C := Rect2(0, 0, 674, 860)
const COL_C := Rect2(662, 30, 242, 520)
const SEAL_C := Rect2(690, 588, 214, 272)
const MARGIN_W := 40.0
const MARGIN_SEP := 16.0
const MARGIN_LINE := 58.0
const NOTE_HOLD_S := 3.4
const SFX_EVENTS := true
# Con Shell y subtítulos activos, el Shell apila hasta dos subtítulos abajo a la derecha (ui/shell.gd, _subs): el
# sello sube para que no le tapen las ranuras del lote cada vez que suena el papel o el plumín.
const SUBS_RESERVE := 112.0
const SEAL_MIN_TOP := 250.0     # el sello nunca sube más que esto (diseño): deja lugar a las pestañas

var act_fn: Callable = Callable()
var sim = null                  # GameSim (tests/drivers); null -> Game.sim
var handle_back := true
var handle_hotkey := true
var sounds := true
var backdrop := true
var area := Rect2()
var compact := false            # lo decide dock(): zona más angosta que COMPACT_BELOW
var shell = null                # ui/shell.gd (Shell.open_panel lo pone con set_shell); opcional
var auto_dock := true           # con Shell: mitad derecha si el cuaderno está abierto o se está fuera (visita, escena)
var side := false               # acoplado por el Shell (lo decide _sync_with_shell)

var page := Model.PAGE_RULES
var selected := ""
var lot: Array = []

var _built := false
var _root: Control
var _back: Control
var _stage: Control
var _book: Control
var _left: Control
var _right: Control
var _scroll_l: ScrollContainer
var _scroll_r: ScrollContainer
var _spine: Control
var _col: VBoxContainer
var _tabs_scroll: ScrollContainer
var _tabs: VBoxContainer
var _new_folio: Control
var _nb_tab: Control = null      # pestaña «Cuaderno» (con Shell y el cuaderno cerrado): abre el otro libro al lado
var _nb_tab_stale := false
var _seal: Control
var _note: PanelContainer
var _note_label: Label
var _note_tw: Tween = null
var _layer_top: Control
var _picker: Control = null
var _confirm: Control = null
var _dirty := false
var _sel_by_page := {}
var _fresh_ink: Array = []
var _sim_conn = null
var _opened_once := false
var _compact_entry := false     # acoplado: la página muestra el asiento abierto en vez de la lista
var _hd := 860.0                # alto de diseño actual del escenario (ver _layout)
var _seal_bottom := 860.0       # borde inferior del sello (diseño): _hd, o más arriba si hay subtítulos del Shell
var _seal_shown := true         # el sello está a la vista (no de visita)

# ------------------------------------------------------------------ dibujo del libro
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
		draw_rect(r, Color(Paper.MESA.darkened(0.18), 0.94))
		var c := Vector2(size.x * 0.45, size.y * 0.4)
		var rad := maxf(size.x, size.y) * 0.6
		for i in 6:
			var k := float(i) / 6.0
			draw_circle(c, rad * (1.0 - k), Color(1.0, 0.86, 0.6, 0.012))

class BookFrame extends Control:
	var single := false
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var hc := Paper.hc_on()
		var r := Rect2(Vector2.ZERO, size)
		var leather := Color(0, 0, 0) if hc else Color("41271f")
		var edge := Color(0, 0, 0) if hc else Color("24140f")
		var sb := Paper.flat(leather, edge, [2, 2, 2, 2], 12)
		if not hc:
			sb.shadow_color = Color(0, 0, 0, 0.45)
			sb.shadow_size = 16
			sb.shadow_offset = Vector2(0, 6)
		draw_style_box(sb, r)
		if not hc:
			# filete dorado gastado a lo largo del canto
			draw_rect(r.grow(-7.0), Color(0.72, 0.58, 0.35, 0.22), false, 1.0)
			# canto de las hojas (grosor del libro) bajo cada página (el alto sigue al del libro: acoplado puede ser menor)
			var bot := size.y - PAGE_L.position.y
			for k in 3:
				var off := float(k + 1) * 2.0
				var pc := Paper.paper("libro_mayor").darkened(0.18 + 0.08 * k)
				draw_line(Vector2(PAGE_L.position.x + 2, bot + off), Vector2(PAGE_L.end.x, bot + off), pc, 1.0)
				draw_line(Vector2(PAGE_L.position.x - off * 0.5, PAGE_L.position.y + 4), Vector2(PAGE_L.position.x - off * 0.5, bot), pc, 1.0)
				if single:
					draw_line(Vector2(PAGE_L.end.x + off * 0.5, PAGE_L.position.y + 4), Vector2(PAGE_L.end.x + off * 0.5, bot), pc, 1.0)
				else:
					draw_line(Vector2(PAGE_R.position.x, bot + off), Vector2(PAGE_R.end.x - 2, bot + off), pc, 1.0)
					draw_line(Vector2(PAGE_R.end.x + off * 0.5, PAGE_R.position.y + 4), Vector2(PAGE_R.end.x + off * 0.5, bot), pc, 1.0)

class Spine extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if Paper.hc_on():
			draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, size.y), Color(0, 0, 0), 2.0)
			return
		var w := size.x
		var steps := 14
		for i in steps:
			var k := float(i) / float(steps)
			var a := 0.30 * pow(1.0 - k, 2.0)
			var dx := k * w * 0.5
			draw_rect(Rect2(Vector2(w * 0.5 - dx - w / float(steps) * 0.5, 0), Vector2(w / float(steps) * 0.5, size.y)), Color(0.12, 0.08, 0.05, a))
			draw_rect(Rect2(Vector2(w * 0.5 + dx, 0), Vector2(w / float(steps) * 0.5, size.y)), Color(0.12, 0.08, 0.05, a))

class Tab extends PanelContainer:
	signal clicked
	var pid := ""
	var selected := false
	func setup(p_pid: String, text: String, sub: String, p_sel: bool, font: Font, sub_font: Font, px: int, spx: int) -> void:
		pid = p_pid
		selected = p_sel
		name = "Pestana_" + pid
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var bg := Paper.paper("libro_mayor") if selected else Paper.shade("libro_mayor", 0.07)
		var sb := Paper.flat(bg, Paper.edge("libro_mayor"), [0, 1, 1, 1], 0, [22, 6, 12, 7])
		sb.corner_radius_top_right = 7
		sb.corner_radius_bottom_right = 7
		sb.anti_aliasing = true
		if selected and not Paper.hc_on():
			sb.shadow_color = Color(0, 0, 0, 0.25)
			sb.shadow_size = 4
			sb.shadow_offset = Vector2(2, 2)
		add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		var l := Label.new()
		l.text = text
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", px)
		l.add_theme_color_override("font_color", Paper.ink("negra" if selected else "lapiz"))
		v.add_child(l)
		if sub != "":
			var s := Label.new()
			s.text = sub
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s.clip_text = true
			s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			s.add_theme_font_override("font", sub_font)
			s.add_theme_font_size_override("font_size", spx)
			s.add_theme_color_override("font_color", Paper.ink("lapiz" if selected else "tenue"))
			v.add_child(s)
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			accept_event()
			clicked.emit()

class DashedTab extends PanelContainer:
	signal clicked
	var enabled := true
	func _init() -> void:
		name = "NuevoFolio"
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_stylebox_override("panel", Paper.empty([22, 8, 12, 9]))
	func _draw() -> void:
		var r := Rect2(Vector2(10, 1), size - Vector2(12, 2))
		var c := Paper.ink("negra" if enabled else "tenue")
		c.a = 0.75 if enabled else 0.5
		draw_style_box(Paper.flat(Color(Paper.paper("libro_mayor"), 0.62 if not Paper.hc_on() else 1.0), Color(0, 0, 0, 0), [0, 0, 0, 0], 7), r)
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for i in 4:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := int(a.distance_to(b) / 9.0)
			for k in n:
				if k % 2 == 0:
					draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), c, 1.2)
	func _gui_input(ev: InputEvent) -> void:
		if enabled and ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			accept_event()
			clicked.emit()

# ------------------------------------------------------------------ ciclo
func _init() -> void:
	layer = LAYER
	name = "LibroMayor"
	visible = false

func _ready() -> void:
	_build()
	var ti := Widgets.ti()
	if ti != null and not ti.theme_changed.is_connected(_on_theme_changed):
		ti.theme_changed.connect(_on_theme_changed)
	var g := _autoload("Game")
	if g != null:
		if not g.session_started.is_connected(_on_session):
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
		if g != null and not g.sim_changed.is_connected(_on_sim_changed):
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
	lot.clear()
	_hide_note()
	if is_inside_tree():
		_connect_sim()
	_queue_refresh()

func _on_session() -> void:
	_hide_note()
	lot.clear()
	selected = ""
	_sel_by_page.clear()
	page = Model.PAGE_RULES
	_opened_once = false
	_queue_refresh()

func _on_sim_changed(kind: String, _payload: Dictionary) -> void:
	if ["entry", "folio", "pass", "index", "clip", "pair", "clock", "flag"].has(kind):
		_queue_refresh()
	if kind == "clock" and shell != null:
		_sync_with_shell.call_deferred()

# Mientras se arrastra algo, el fondo deja pasar el ratón (presentar un asiento sobre un personaje, soltar en el 3D).
func _notification(what: int) -> void:
	if _back == null:
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif what == NOTIFICATION_DRAG_END:
		_back.mouse_filter = Control.MOUSE_FILTER_STOP

# ------------------------------------------------------------------ Shell (duck typing; ui/shell.gd)
func set_shell(s) -> void:
	shell = s
	if s != null and s.has_signal("panel_opened"):
		if not s.panel_opened.is_connected(_on_shell_panel):
			s.panel_opened.connect(_on_shell_panel)
		if not s.panel_closed.is_connected(_on_shell_panel):
			s.panel_closed.connect(_on_shell_panel)
	_sync_with_shell()

func _on_shell_panel(_kind: String) -> void:
	if visible:
		_sync_with_shell.call_deferred()

# Dos paneles a la vez (§6.1): el cuaderno se va a la izquierda cuando el libro mayor está abierto; el libro, a la
# derecha. Fuera del escritorio (visita, escena, confrontación) también a la derecha: a la izquierda queda el 3D para
# soltar un asiento sobre un personaje.
func _sync_with_shell() -> void:
	if not auto_dock or shell == null or not is_instance_valid(shell) or not shell.has_method("is_open"):
		return
	var phase := ""
	var s = sim_ref()
	if s != null:
		phase = String(s.q_clock().get("phase", ""))
	var want: bool = bool(shell.is_open("notebook")) or ["visit", "scene", "confront"].has(phase)
	side = want
	_sync_nb_tab()
	_layout()

# La pestaña del otro libro, al pie de la columna de pestañas (como las del libro, sin distinguirse): clic = el cuaderno
# a la izquierda y el libro a la derecha. Se rehace entera (letra y papel siguen al tema); sin Shell no existe.
func _sync_nb_tab() -> void:
	if _col == null:
		return
	var want: bool = shell != null and is_instance_valid(shell) and shell.has_method("is_open") and not bool(shell.is_open("notebook"))
	if want == (_nb_tab != null and is_instance_valid(_nb_tab)) and not _nb_tab_stale:
		return
	_nb_tab_stale = false
	if _nb_tab != null and is_instance_valid(_nb_tab):
		_col.remove_child(_nb_tab)
		_nb_tab.queue_free()
	_nb_tab = null
	if not want:
		_size_tabs.call_deferred()
		return
	var t := Tab.new()
	t.setup("cuaderno", Widgets.t("shell.hud.cuaderno"), "", false, font("imprenta"), font("imprenta", true), _px("ui"), _px("small"))
	t.clicked.connect(func():
		if shell != null and is_instance_valid(shell):
			shell.open_panel("notebook"))
	var m := MarginContainer.new()
	m.name = "OtroLibro"
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 10)
	m.add_child(t)
	_nb_tab = m
	_col.add_child(m)
	_size_tabs.call_deferred()

# Zona del libro acoplado por el Shell: a la derecha del cuaderno en su modo «left» (ui/notebook/notebook.gd:
# x = 18, ancho = max(560, vp.x/2 − 30)), o la mitad derecha. Con el panel de escena o de confrontación a la vista
# (capa 40, su banda tapa el pie de la pantalla) el libro termina arriba de la banda, como el cuaderno.
func side_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600, 900)
	var x := maxf(vp.x * 0.5, 18.0 + maxf(560.0, vp.x * 0.5 - 30.0) + 10.0)
	x = minf(x, maxf(0.0, vp.x - 420.0))
	var h := vp.y
	var bt := scene_band_top()
	if bt > 0.0:
		h = maxf(360.0, bt - 10.0)
	return Rect2(Vector2(x, 0.0), Vector2(vp.x - x, h))

const SCENE_BAND_FALLBACK := 290.0   # alto reservado si el panel de escena no expone su banda

# Borde superior (en pantalla) de la banda del panel de escena o de confrontación abierto en el Shell; 0 = no hay.
func scene_band_top() -> float:
	if shell == null or not is_instance_valid(shell) or not shell.has_method("is_open") or not shell.has_method("panel"):
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
		return vp.y - SCENE_BAND_FALLBACK
	return 0.0

func _on_theme_changed() -> void:
	_nb_tab_stale = true
	TextBuilder.clear_caches()
	if _back != null:
		_back.queue_redraw()
	if _book != null:
		_book.queue_redraw()
		_spine.queue_redraw()
	_queue_refresh()

# ------------------------------------------------------------------ API
func open(p_page := "") -> void:
	_build()
	if p_page != "":
		page = p_page
	elif not _opened_once:
		page = Model.PAGE_RULES
	_opened_once = true
	visible = true
	_sync_with_shell()
	_layout()
	refresh()
	_sfx("sfx.pagina")

func close() -> void:
	_close_overlays()
	_hide_note()
	if not visible:
		return
	visible = false
	closed.emit()

# La nota de Lisle no sobrevive al libro cerrado (al reabrirlo no queda una línea vieja a la vista).
func _hide_note() -> void:
	if _note_tw != null and _note_tw.is_valid():
		_note_tw.kill()
	_note_tw = null
	if _note != null:
		_note.visible = false
		_note.modulate.a = 0.0

func is_open() -> bool:
	return visible

func dock(rect: Rect2) -> void:
	area = rect
	_layout()

func show_page(pid: String) -> void:
	if pid == "":
		return
	page = pid
	_compact_entry = false
	selected = String(_sel_by_page.get(pid, ""))
	refresh()
	page_changed.emit(pid)
	_sfx("sfx.pagina")

func select_entry(eid: String) -> void:
	var s = sim_ref()
	if s == null or eid == "" or s.q_entry(eid).is_empty():
		return
	var pid := Model.page_of_entry(s, eid)
	if pid != page:
		page = pid
		page_changed.emit(pid)
	selected = eid
	_sel_by_page[page] = eid
	_compact_entry = true
	refresh()
	entry_selected.emit(eid)

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
	if _dirty:
		refresh()

# ------------------------------------------------------------------ armado
func _build() -> void:
	if _built:
		return
	_built = true
	_root = Control.new()
	_root.name = "Raiz"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # fuera de la zona del libro (acoplado) el clic sigue de largo
	add_child(_root)
	_back = Backdrop.new()
	_back.name = "Fondo"
	_back.clicked.connect(_on_backdrop)
	_root.add_child(_back)
	_stage = Control.new()
	_stage.name = "Escenario"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = DESIGN
	_root.add_child(_stage)
	# pestañas primero: el canto del libro tapa su raíz
	_col = VBoxContainer.new()
	_col.name = "Canto"
	_col.position = COL.position
	_col.size = COL.size
	_col.add_theme_constant_override("separation", 6)
	_stage.add_child(_col)
	_tabs_scroll = ScrollContainer.new()
	_tabs_scroll.name = "Pestanas"
	_tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_col.add_child(_tabs_scroll)
	_tabs = VBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs_scroll.add_child(_tabs)
	_new_folio = DashedTab.new()
	_new_folio.clicked.connect(func(): on_new_folio(_new_folio))
	_new_folio.set_drag_forwarding(Callable(), func(_p, d): return can_drop_folio(d), func(_p, d): drop_folio(d))
	_col.add_child(_new_folio)
	_book = BookFrame.new()
	_book.name = "Libro"
	_book.position = BOOK.position
	_book.size = BOOK.size
	_stage.add_child(_book)
	_left = _page_sheet("HojaIzq", PAGE_L)
	_right = _page_sheet("HojaDer", PAGE_R)
	_scroll_l = _left.get_child(0)
	_scroll_r = _right.get_child(0)
	_spine = Spine.new()
	_spine.name = "Lomo"
	_spine.position = Vector2(PAGE_L.end.x - 26, PAGE_L.position.y)
	_spine.size = Vector2(PAGE_R.position.x - PAGE_L.end.x + 52, PAGE_L.size.y)
	_book.add_child(_spine)
	_seal = Seal.new()
	_seal.position = SEAL_R.position
	_seal.size = SEAL_R.size
	_seal.stamp_pressed.connect(stamp)
	_seal.slot_pressed.connect(select_entry)
	_seal.slot_add_pressed.connect(on_lot_add)
	_seal.slot_remove_pressed.connect(func(eid: String):
		lot.erase(eid)
		refresh())
	_stage.add_child(_seal)
	_note = Widgets.paper_panel("cuaderno", null, {"margin": 16, "margin_v": 9, "shadow_size": 6})
	_note.name = "NotaLisle"
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_label = Widgets.marginal("")
	_note_label.custom_minimum_size = Vector2(300, 0)
	_note_label.add_theme_font_size_override("font_size", _px("ui"))
	_note.add_child(_note_label)
	_note.visible = false
	_note.modulate.a = 0.0
	_root.add_child(_note)
	_layer_top = Control.new()
	_layer_top.name = "Capa"
	_layer_top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_layer_top)

func _page_sheet(nm: String, r: Rect2) -> Control:
	var sh := Widgets.sheet("libro_mayor", {"ruled": true, "margin_line": MARGIN_LINE, "margin_double": true, "shadow": false})
	sh.name = nm
	sh.add_theme_stylebox_override("panel", Paper.empty([8, 26, 30, 22]))
	sh.position = r.position
	sh.size = r.size
	sh.mouse_filter = Control.MOUSE_FILTER_STOP
	var sc := ScrollContainer.new()
	sc.name = "Desplazar"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sh.add_child(sc)
	_book.add_child(sh)
	return sh

func _layout() -> void:
	if not _built or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var a := area if area.size.x > 0.0 and area.size.y > 0.0 else Rect2(Vector2.ZERO, vp)
	if side and not (area.size.x > 0.0 and area.size.y > 0.0):
		a = side_rect()
	_back.position = a.position
	_back.size = a.size
	_back.visible = backdrop
	var want := a.size.x < COMPACT_BELOW
	if want != compact:
		compact = want
		_compact_entry = false
		_queue_refresh()
	var pad := 16.0
	var d := DESIGN_C if compact else DESIGN
	var s := 1.0
	if compact:
		# una sola página: la escala la da el ancho (texto legible) y el alto del libro se ajusta a la zona (p. ej. arriba
		# de la banda de una escena); lo que no cabe se desplaza dentro de la hoja
		s = clampf((a.size.x - pad * 2.0) / d.x, 0.4, 1.0)
		d.y = clampf((a.size.y - pad * 2.0) / s, MIN_H_C, DESIGN_C.y)
		s = maxf(0.4, minf(s, (a.size.y - pad * 2.0) / d.y))
	else:
		s = maxf(0.4, minf(1.0, minf((a.size.x - pad * 2.0) / d.x, (a.size.y - pad * 2.0) / d.y)))
	_hd = d.y
	var pos := a.position + (a.size - d * s) * 0.5
	_seal_bottom = _hd
	var res := subs_reserve()
	if res > 0.0:
		var sr := SEAL_C if compact else SEAL_R
		var lim := (vp.y - res - pos.y) / s
		_seal_bottom = clampf(lim, SEAL_MIN_TOP + sr.size.y, _hd)
	_apply_geom()
	_stage.size = d
	_stage.scale = Vector2(s, s)
	_stage.position = pos
	_place_note()

# Alto (px de pantalla) que se deja libre abajo para los subtítulos del Shell; 0 sin Shell o sin subtítulos.
func subs_reserve() -> float:
	if shell == null or not is_instance_valid(shell):
		return 0.0
	if shell.has_method("subs_rect"):
		return (shell.subs_rect() as Rect2).size.y   # la zona real de los subtítulos del Shell (0 sin ellos o con --mute)
	var au := _autoload("Audio")
	if au == null or not ("subtitles_on" in au) or not bool(au.get("subtitles_on")):
		return 0.0
	return SUBS_RESERVE

# Geometría del escenario para el alto de diseño _hd (860 a pantalla entera; menos, acoplado arriba de una banda).
func _apply_geom() -> void:
	var b := BOOK_C if compact else BOOK
	_book.size = Vector2(b.size.x, _hd)
	_book.single = compact
	_book.queue_redraw()
	var ph := _hd - PAGE_L.position.y * 2.0
	_left.size = Vector2(PAGE_L.size.x, ph)
	_right.size = Vector2(PAGE_R.size.x, ph)
	_spine.size = Vector2(_spine.size.x, ph)
	_right.visible = not compact
	_spine.visible = not compact
	var c := COL_C if compact else COL
	var sr := SEAL_C if compact else SEAL_R
	_col.position = c.position
	# el papel del sello puede crecer con lo que va «Al sello» (su mínimo): las pestañas terminan sobre su alto real
	var seal_h := maxf(sr.size.y, _seal.get_combined_minimum_size().y)
	var col_h := (_seal_bottom - seal_h - c.position.y - 38.0) if _seal_shown else (_hd - c.position.y - 30.0)
	_col.size = Vector2(c.size.x, maxf(160.0, col_h))
	_seal.size = sr.size
	_seal.position = Vector2(sr.position.x, _seal_bottom - _seal.size.y)
	_size_tabs()

# El papel del sello tiene medida fija: si un contenido nuevo lo estiró un momento, vuelve a su medida y a su lugar.
func _fit_seal() -> void:
	if _seal == null:
		return
	var sr := SEAL_C if compact else SEAL_R
	_seal.size = sr.size
	_seal.position = Vector2(sr.position.x, _seal_bottom - _seal.size.y)
	if _col != null and _seal_shown:
		var c := COL_C if compact else COL
		var col_h := _seal_bottom - _seal.size.y - c.position.y - 38.0
		if absf(_col.size.y - maxf(160.0, col_h)) > 0.5:
			_col.size = Vector2(c.size.x, maxf(160.0, col_h))
			_size_tabs()

func _place_note() -> void:
	if _note == null:
		return
	_note.reset_size()
	var s := _stage.scale.x
	var cx := PAGE_L.get_center().x if compact else PAGE_L.end.x
	var bottom := _stage.position + Vector2(cx * s, (_hd - PAGE_L.position.y - 8.0) * s)
	_note.position = Vector2(bottom.x - _note.size.x * 0.5, bottom.y - _note.size.y)

# ------------------------------------------------------------------ reconstrucción
func _rebuild() -> void:
	var s = sim_ref()
	var keep_l := _scroll_l.scroll_vertical
	var keep_r := _scroll_r.scroll_vertical
	var keep_t := _tabs_scroll.scroll_vertical
	if s != null:
		lot = Model.clean_lot(s, lot)
	var pages: Array = Model.pages(s)
	var pinfo := {}
	for p in pages:
		if String(p.id) == page:
			pinfo = p
	if pinfo.is_empty():
		page = Model.PAGE_VARIOS if s != null else Model.PAGE_RULES
		for p in pages:
			if String(p.id) == page:
				pinfo = p
	# selección válida en esta página
	var eids: Array = Model.page_entries(s, page)
	if selected != "" and not eids.has(selected):
		selected = ""
	if selected == "" and not eids.is_empty():
		selected = String(_sel_by_page.get(page, ""))
		if not eids.has(selected):
			selected = String(eids[0])
	if selected != "":
		_sel_by_page[page] = selected
	_build_tabs(pages)
	_clear(_scroll_l)
	_clear(_scroll_r)
	var lc: Control
	var rc: Control
	if compact:
		lc = _compact_content(s, pinfo, eids)
		rc = Control.new()
	elif String(pinfo.get("kind", "rules")) == "rules":
		lc = RulesPage.build_left(self)
		rc = RulesPage.build_right(self)
	else:
		var rows: Array = []
		for eid in eids:
			var vm := Model.entry_vm(s, String(eid))
			if not vm.is_empty():
				rows.append({"vm": vm, "summary": Model.entry_summary(vm)})
		lc = FolioPage.build(self, pinfo, rows, selected, lot)
		if selected != "":
			var svm := Model.entry_vm(s, selected)
			rc = EntryView.build(self, svm, lot.has(selected)) if not svm.is_empty() else EntryView.empty(self)
		else:
			rc = EntryView.empty(self)
	lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_l.add_child(lc)
	_scroll_r.add_child(rc)
	# el sello no sale del escritorio: de visita (o en una escena) no se ve; el libro sí va con Lisle
	var shown: bool = s != null and not Model.AWAY_PHASES.has(String(s.q_clock().get("phase", "")))
	_seal.visible = shown
	if shown != _seal_shown:
		_seal_shown = shown
		_apply_geom()
	_new_folio.visible = s != null
	_sync_nb_tab()
	if s != null:
		_new_folio.enabled = Model.tut_allows(s, "folio_open")
		_new_folio.queue_redraw()
		_sync_new_folio_label(s)
		var cards: Array = []
		for id in lot:
			var vm2 := Model.entry_vm(s, String(id))
			cards.append({"id": String(id), "text": "%s · %s" % [Model.tx(s, "ledger.asiento", {"n": int(vm2.get("n", 0))}), String(vm2.get("tname", ""))]})
		_seal.sync(Model.seal_state(s, lot), cards)
		_fit_seal.call_deferred()
	_restore_scroll.call_deferred(keep_l, keep_r, keep_t)
	_size_tabs.call_deferred()
	_clear_fresh.call_deferred()

# Acoplado: una sola página. Reglas (con el modo de asentar debajo) · la lista de la página · o el asiento abierto con
# un renglón para volver a la lista.
func _compact_content(s, pinfo: Dictionary, eids: Array) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	if String(pinfo.get("kind", "rules")) == "rules":
		v.add_child(RulesPage.build_left(self))
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, 16)
		v.add_child(sp)
		v.add_child(RulesPage.build_right(self))
		return v
	if _compact_entry and selected != "":
		var svm := Model.entry_vm(s, selected)
		if not svm.is_empty():
			var bk := Widgets.ink_button("‹ " + String(pinfo.get("title", "")))
			bk.name = "VolverALaPagina"
			bk.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			bk.pressed.connect(func():
				_compact_entry = false
				refresh())
			v.add_child(indent(bk))
			v.add_child(EntryView.build(self, svm, lot.has(selected)))
			return v
	v.free()   # la lista no usa la columna (antes quedaba huérfana: fuga de un VBoxContainer por refresco)
	var rows: Array = []
	for eid in eids:
		var vm := Model.entry_vm(s, String(eid))
		if not vm.is_empty():
			rows.append({"vm": vm, "summary": Model.entry_summary(vm)})
	return FolioPage.build(self, pinfo, rows, selected if _compact_entry else "", lot)

func _clear_fresh() -> void:
	_fresh_ink.clear()

func _restore_scroll(l: int, r: int, t: int) -> void:
	_scroll_l.scroll_vertical = l
	_scroll_r.scroll_vertical = r
	_tabs_scroll.scroll_vertical = t

func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

func _build_tabs(pages: Array) -> void:
	_clear(_tabs)
	var f_imp := font("imprenta")
	var f_it := font("imprenta", true)
	for p in pages:
		var t := Tab.new()
		var sub := String(p.get("head_short", ""))
		t.setup(String(p.id), String(p.tab), sub, String(p.id) == page, f_imp, f_it, _px("ui"), _px("small"))
		t.clicked.connect(show_page.bind(String(p.id)))
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_right", 0 if String(p.id) == page else 14)
		m.add_child(t)
		_tabs.add_child(m)

func _sync_new_folio_label(s) -> void:
	for c in _new_folio.get_children():
		_new_folio.remove_child(c)
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = "+ " + Model.tx(s, "ledger.tab.nuevo_folio")
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font("imprenta"))
	l.add_theme_font_size_override("font_size", _px("ui"))
	l.add_theme_color_override("font_color", Paper.ink("negra" if _new_folio.enabled else "tenue"))
	v.add_child(l)
	var sl := Label.new()
	sl.text = Model.tx(s, "ledger.tab.nuevo_folio.sub")
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sl.add_theme_font_override("font", font("imprenta", true))
	sl.add_theme_font_size_override("font_size", _px("small"))
	sl.add_theme_color_override("font_color", Paper.ink("lapiz" if _new_folio.enabled else "tenue"))
	v.add_child(sl)
	_new_folio.add_child(v)

# El canto: las pestañas ocupan lo que necesitan (con desplazamiento si no caben) y «Nuevo folio» va debajo.
func _size_tabs() -> void:
	if _tabs == null or _col == null:
		return
	var need := _tabs.get_combined_minimum_size().y
	var avail := _col.size.y - _new_folio.get_combined_minimum_size().y - 6.0
	if _nb_tab != null and is_instance_valid(_nb_tab):
		avail -= _nb_tab.get_combined_minimum_size().y + 6.0
	_tabs_scroll.custom_minimum_size = Vector2(0, minf(need, avail))
	_tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if need > avail else ScrollContainer.SCROLL_MODE_SHOW_NEVER

# ------------------------------------------------------------------ estilo (lo usan los constructores de página)
func font(slot: String, italic := false) -> Font:
	var ti := Widgets.ti()
	return ti.font(slot, italic) if ti != null else ThemeDB.fallback_font

func px(kind: String) -> int:
	return _px(kind)

func _px(kind: String) -> int:
	var ti := Widgets.ti()
	return ti.px(kind) if ti != null else int({"doc": 21, "ui": 19, "small": 15, "title": 34, "caption": 16}.get(kind, 19))

# Texto de ui_text sin marcado (<i>…</i>) para un Label.
func plain(t: String) -> String:
	if not t.contains("<") and not t.contains("[[") and not t.contains("{{"):
		return t
	return String(Markup.parse(t).get("plain", t))

func text_width(t: String, slot: String, size: int, cap := 99999.0) -> float:
	return minf(cap, font(slot).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 4.0)

# Sangría hasta la doble raya roja del margen. Un control con SIZE_SHRINK_BEGIN conserva su ancho (botones).
func indent(c: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(MARGIN_W + MARGIN_SEP))
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if c.size_flags_horizontal != Control.SIZE_SHRINK_BEGIN:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(c)
	return m

func rich_text(src: String, slot := "imprenta", size := 0) -> RichTextLabel:
	var r := TextBuilder.make_rtl(slot)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s = sim_ref()
	var parsed: Dictionary = s.repo.parse_text(src) if s != null else Markup.parse(src)
	TextBuilder.build(r, parsed, {"slot": slot, "size": size if size > 0 else _px("doc"), "fx": false})
	return r

# Lápiz: a mano, gris (se corrige y se borra). Tinta: de imprenta, negra (pasado en limpio).
func ink_label(text: String, ink: String, size_kind := "ui") -> Label:
	var l := Label.new()
	l.text = text
	var pencil := ink != "tinta"
	l.add_theme_font_override("font", font("manuscrito" if pencil else "imprenta"))
	var sz := _px(size_kind)
	l.add_theme_font_size_override("font_size", int(round(sz * (0.92 if pencil else 1.0))))
	l.add_theme_color_override("font_color", Paper.ink("lapiz" if pencil else "negra"))
	if pencil:
		l.add_theme_constant_override("line_spacing", -int(round(sz * 0.3)))
	return l

# El blanco de un campo «Campo: ___»: subrayado; lleno, a mano en lápiz.
func blank_button(text: String, filled: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text = text
	var lapiz := Paper.ink("lapiz")
	var negra := Paper.ink("negra")
	var n := Paper.flat(Color(0, 0, 0, 0), lapiz, [0, 0, 0, 1], 0, [4, 0, 4, 2])
	var h := Paper.flat(Color(negra, 0.05), negra, [0, 0, 0, 1], 0, [4, 0, 4, 2])
	var p := Paper.flat(Color(negra, 0.09), negra, [0, 0, 0, 2], 0, [4, 0, 4, 1])
	var d := Paper.flat(Color(0, 0, 0, 0), Color(Paper.ink("tenue"), 0.6), [0, 0, 0, 1], 0, [4, 0, 4, 2])
	for k in ["normal", "focus"]:
		b.add_theme_stylebox_override(k, n if k == "normal" else Paper.empty())
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_font_override("font", font("manuscrito"))
	var sz := int(round(_px("ui") * 0.92))
	b.add_theme_font_size_override("font_size", sz)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, lapiz)
	b.add_theme_color_override("font_disabled_color", Paper.ink("tenue"))
	var w := 150.0
	if filled:
		w = clampf(font("manuscrito").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 14.0, 110.0, 420.0)
	b.custom_minimum_size = Vector2(w, maxf(30.0, sz * 1.5))
	return b

# Una tira del «según» (recorte o par). La cruz la quita (sólo a lápiz); el texto completo y su fuente, al pasar.
func support_chip(c: Dictionary, removable: bool, on_remove: Callable) -> Control:
	var p := PanelContainer.new()
	p.name = "Tira_" + String(c.get("id", ""))
	p.theme_type_variation = "Chip"
	p.mouse_filter = Control.MOUSE_FILTER_PASS   # soltar sobre una tira = soltar en la ranura
	p.tooltip_text = String(c.get("text", "")) + ("\n" + String(c.sub) if String(c.get("sub", "")) != "" else "")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var l := Label.new()
	l.text = ("" if String(c.get("kind", "clip")) == "clip" else "‹" + Model.tx(sim_ref(), "ledger.par") + "› ") + Model.short(String(c.get("text", "")), 70)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font("imprenta"))
	l.add_theme_font_size_override("font_size", _px("small") + 1)
	l.add_theme_color_override("font_color", Paper.ink("tenue" if bool(c.get("missing", false)) else "negra"))
	var tw := font("imprenta").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _px("small") + 1).x
	l.custom_minimum_size = Vector2(minf(tw + 2.0, 300.0), 0)
	h.add_child(l)
	if removable:
		var x := Button.new()
		x.name = "Quitar"
		x.flat = true
		x.focus_mode = Control.FOCUS_NONE
		x.icon = Paper.icon("cross", 14, Paper.ink("lapiz"))
		x.tooltip_text = Model.tx(sim_ref(), "ledger.segun.quitar")
		x.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		x.mouse_filter = Control.MOUSE_FILTER_PASS
		x.pressed.connect(on_remove)
		h.add_child(x)
	return p

# El recorte que abrió un folio, pegado como tira de papel (se arrastra como recorte al «según» o a presentar).
func clip_strip(c: Dictionary, draggable := true) -> Control:
	var p := PanelContainer.new()
	p.name = "TiraEncabezado"
	p.add_theme_stylebox_override("panel", Paper.style("diario_hueso", {"margin": 12, "margin_v": 7, "radius": 0, "shadow_size": 4, "shadow_y": 2}))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var l := Label.new()
	l.text = String(c.get("text", ""))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font("imprenta"))
	l.add_theme_font_size_override("font_size", _px("ui"))
	l.add_theme_color_override("font_color", Paper.ink("negra"))
	v.add_child(l)
	if String(c.get("sub", "")) != "":
		var s := Widgets.source_line(String(c.sub))
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(s)
	if draggable and String(c.get("id", "")) != "":
		p.mouse_default_cursor_shape = Control.CURSOR_DRAG
		p.set_drag_forwarding(func(_pos): return drag_clip(String(c.id), Model.short(String(c.get("text", "")), 40), p), Callable(), Callable())
	return p

# Recién pasado en limpio: la tinta se escribe de izquierda a derecha (rasguido de plumín, ≤0,4 s) y después cae el
# «Visto» (maybe_animate_stamp). Sólo en el refresco que sigue a la pasada.
func maybe_animate_ink(eid: String, lab: Label) -> void:
	if not _fresh_ink.has(eid) or lab == null:
		return
	lab.visible_ratio = 0.0
	var tw := lab.create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(lab, "visible_ratio", 1.0, 0.36)

func maybe_animate_stamp(eid: String, holder: Control) -> void:
	if not _fresh_ink.has(eid):
		return
	var lab: Label = holder.get_meta("label") if holder.has_meta("label") else null
	if lab == null:
		return
	var a := lab.modulate.a
	lab.modulate.a = 0.0
	lab.scale = Vector2(1.3, 1.3)
	var tw := lab.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lab, "modulate:a", a, 0.25).set_delay(0.45)
	tw.tween_property(lab, "scale", Vector2.ONE, 0.3).set_delay(0.45)

# ------------------------------------------------------------------ acciones (clic, arrastre y API)
func _do(a: Dictionary) -> Dictionary:
	var r := {}
	if act_fn.is_valid():
		var x = act_fn.call(a)
		r = x if typeof(x) == TYPE_DICTIONARY else {"ok": false, "err": "desconocido"}
	elif sim != null:
		r = sim.apply(a)
	else:
		var g := _autoload("Game")
		r = g.act(a) if g != null else {"ok": false, "err": "no_sim"}
	if not bool(r.get("ok", false)):
		var extra := {"t": String(a.get("t", ""))}
		if r.has("lot_size"):
			extra["lot_size"] = int(r.lot_size)
		say(Model.err_text(sim_ref(), String(r.get("err", "")), extra))
	acted.emit(a, r)
	_queue_refresh()
	return r

func on_select(eid: String) -> void:
	if eid == selected and (not compact or _compact_entry):
		return
	_compact_entry = true
	selected = eid
	_sel_by_page[page] = eid
	refresh()
	entry_selected.emit(eid)

func on_new_folio(anchor: Control) -> void:
	var s = sim_ref()
	if s == null or not Model.tut_allows(s, "folio_open"):
		return
	_open_picker(Model.tx(s, "ledger.picker.folio"), Model.support_options(s, [], false), anchor, Model.tx(s, "ledger.picker.sin_recortes"),
		func(id: String, _o): new_folio_from(id))

func new_folio_from(clip: String) -> Dictionary:
	var r := _do({"t": "folio_open", "clip": clip})
	if bool(r.get("ok", false)):
		_sfx("sfx.papel")
		show_page(String(r.get("folio", "")))
	return r

func on_new_entry(anchor: Control) -> void:
	var s = sim_ref()
	if s == null:
		return
	var opts: Array = []
	for t in Model.templates(s):
		opts.append({"id": String(t.id), "text": String(t.name), "sub": String(t.shape)})
	_open_picker(Model.tx(s, "ledger.picker.plantilla"), opts, anchor, "", func(id: String, _o): new_entry(id))

func new_entry(tid: String) -> Dictionary:
	var where := page if page != Model.PAGE_RULES else Model.PAGE_VARIOS
	var r := _do({"t": "entry_new", "folio": where, "template": tid})
	if bool(r.get("ok", false)):
		if page != where:
			page = where
		selected = String(r.get("entry", ""))
		_sel_by_page[page] = selected
		_compact_entry = true
		_sfx("sfx.plumin")
	return r

func on_field(eid: String, line: int, field: String, accept: Dictionary, value: String, anchor: Control) -> void:
	var s = sim_ref()
	if s == null:
		return
	var label := ""
	var tpl := Model.template(s, String(s.q_entry(eid).get("template", "")))
	var tl: Array = tpl.get("lines", [])
	if line >= 0 and line < tl.size():
		for f in tl[line].get("fields", []):
			if String(f.get("id", "")) == field:
				label = Model.field_label(String(f.get("label", "")))
	_open_picker(label, Model.field_options(s, accept, value), anchor, Model.tx(s, "ledger.picker.sin_indice"),
		func(id: String, _o): set_field(eid, line, field, id))

func set_field(eid: String, line: int, field: String, value: String) -> Dictionary:
	var r := _do({"t": "entry_set", "entry": eid, "line": line, "field": field, "value": value})
	if bool(r.get("ok", false)):
		_sfx("sfx.plumin")
	return r

func on_support_add(eid: String, line: int, anchor: Control) -> void:
	var s = sim_ref()
	if s == null:
		return
	var cur: Array = []
	var e: Dictionary = s.q_entry(eid)
	var lines: Array = e.get("lines", [])
	if line >= 0 and line < lines.size():
		cur = lines[line].get("support", [])
	_open_picker(Model.tx(s, "ledger.picker.segun"), Model.support_options(s, cur, true), anchor, Model.tx(s, "ledger.picker.sin_recortes"),
		func(id: String, _o): add_support(eid, line, id))

func add_support(eid: String, line: int, item: String) -> Dictionary:
	var r := _do({"t": "entry_support_add", "entry": eid, "line": line, "item": item})
	if bool(r.get("ok", false)):
		_sfx("sfx.papel")
	return r

func on_support_remove(eid: String, line: int, item: String) -> void:
	remove_support(eid, line, item)

func remove_support(eid: String, line: int, item: String) -> Dictionary:
	return _do({"t": "entry_support_remove", "entry": eid, "line": line, "item": item})

func on_lot(eid: String) -> void:
	toggle_lot(eid)
	refresh()

# Ranura vacía del sello: elegir qué asiento a lápiz va al lote (lo mismo que su casilla «Al sello»).
func on_lot_add(anchor: Control) -> void:
	var s = sim_ref()
	if s == null:
		return
	var st := Model.seal_state(s, lot)
	if String(st.reason) == "practica":
		say(Model.seal_reason_text(s, st))
		return
	_open_picker(Model.tx(s, "ledger.picker.lote"), Model.lot_options(s, lot), anchor, Model.tx(s, "ledger.picker.sin_asientos"),
		func(id: String, _o):
			toggle_lot(id)
			refresh())

# Marca/desmarca un asiento para el sello. Devuelve si quedó marcado.
func toggle_lot(eid: String) -> bool:
	var s = sim_ref()
	if s == null:
		return false
	if lot.has(eid):
		lot.erase(eid)
		return false
	var e: Dictionary = s.q_entry(eid)
	if e.is_empty():
		return false
	if String(e.get("ink", "")) == "tinta":
		say(Model.tx(s, "ledger.lote.solo_lapiz"))
		return false
	if bool(e.get("practice", false)):
		say(Model.tx(s, "ledger.lote.practica"))
		return false
	var n := int(s.q_clock().get("lot_size", 2))
	if lot.size() >= n:
		say(Model.lot_text(s, n))
		return false
	lot.append(eid)
	return true

func on_practice(eid: String) -> void:
	practice(eid)

func practice(eid: String) -> Dictionary:
	var r := _do({"t": "practice", "entry": eid})
	if String(r.get("err", "")) == "formal":
		# como el sello: Lisle dice por qué no toma tinta (forma), no sólo que no la toma
		var f: Array = r.get("formal", [])
		if not f.is_empty() and typeof(f[0]) == TYPE_DICTIONARY:
			say("%s %s" % [Model.tx(sim_ref(), "pass.formal"), Model.tx(sim_ref(), "formal." + String(f[0].get("code", "")))])
	if bool(r.get("ok", false)):
		if bool(r.get("inked", false)):
			_fresh_ink = [eid]
			_sfx_event("pasada_tinta")
		else:
			_sfx_event("pasada_seca")
		say(String(r.get("msg", "")))
	return r

func on_delete(eid: String) -> void:
	var s = sim_ref()
	if s == null:
		return
	var n := Model.num_of(eid)
	_open_confirm(Model.tx(s, "ledger.borrar.titulo", {"n": n}), Model.tx(s, "ledger.borrar.cuerpo"), Model.tx(s, "ledger.borrar.ok"),
		func(ok: bool): if ok: delete_entry(eid))

func delete_entry(eid: String) -> Dictionary:
	var r := _do({"t": "entry_delete", "entry": eid})
	if bool(r.get("ok", false)):
		lot.erase(eid)
		if selected == eid:
			selected = ""
			_sel_by_page.erase(page)
	return r

# El sello: valida lo que se ve (forma), muestra lo que se pasa y pide confirmación (§6.1: dos pasos).
func stamp() -> void:
	var s = sim_ref()
	if s == null:
		return
	lot = Model.clean_lot(s, lot)
	var st := Model.seal_state(s, lot)
	if not bool(st.ready):
		say(Model.seal_reason_text(s, st))
		return
	# chequeo formal antes de mojar el sello (visible, no gasta): se abre el asiento que falla y Lisle dice por qué
	for id in lot:
		var f: Array = s.q_entry(String(id)).get("formal", [])
		if not f.is_empty():
			select_entry(String(id))
			say("%s %s" % [Model.tx(s, "pass.formal"), Model.tx(s, "formal." + String(f[0]))])
			return
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	var lead := Widgets.label(Model.tx(s, "ledger.sello.cuerpo"), "")
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(lead)
	for id in lot:
		var vm := Model.entry_vm(s, String(id))
		var t := Widgets.label("%s · %s" % [Model.tx(s, "ledger.asiento", {"n": int(vm.n)}), String(vm.tname)], "")
		t.add_theme_font_override("font", font("imprenta"))
		body.add_child(t)
		# el texto entero de lo que se entinta (§6.1: el texto final se ve antes de confirmar; nunca recortado con «…»)
		var sm := ink_label(Model.entry_summary(vm), "lapiz", "small")
		sm.name = "TextoFinal_" + String(id)
		sm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sm.custom_minimum_size = Vector2(440, 0)
		body.add_child(sm)
	_open_confirm(Model.tx(s, "ledger.sello.titulo"), body, Model.tx(s, "ledger.sello.ok"), func(ok: bool): if ok: confirm_stamp())

func confirm_stamp() -> Dictionary:
	_close_overlays()
	var s = sim_ref()
	var ids := lot.duplicate()
	var r := _do({"t": "pass_clean", "entries": ids})
	if bool(r.get("ok", false)):
		var inked := bool(r.get("inked", false))
		_seal.press(inked)
		if inked:
			_fresh_ink = ids.duplicate()
			_sfx_event("pasada_tinta")
		else:
			_sfx_event("pasada_seca")
		lot.clear()
		say(String(r.get("msg", "")))
	elif String(r.get("err", "")) == "formal":
		var f: Array = r.get("formal", [])
		if not f.is_empty() and s != null and typeof(f[0]) == TYPE_DICTIONARY:
			select_entry(String(f[0].get("entry", "")))
			say("%s %s" % [Model.tx(s, "pass.formal"), Model.tx(s, "formal." + String(f[0].get("code", "")))])
	refresh()
	return r

# ------------------------------------------------------------------ arrastrar y soltar (§6.3)
func can_drop_field(data, _accept: Dictionary) -> bool:
	return typeof(data) == TYPE_DICTIONARY and String(data.get("kind", "")) == "ent" and String(data.get("id", "")) != ""

func drop_field(eid: String, line: int, field: String, data) -> void:
	set_field(eid, line, field, String(data.get("id", "")))

func can_drop_support(data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and ["clip", "pair"].has(String(data.get("kind", ""))) and String(data.get("id", "")) != ""

func drop_support(eid: String, line: int, data) -> void:
	add_support(eid, line, String(data.get("id", "")))

func can_drop_folio(data) -> bool:
	var s = sim_ref()
	return s != null and Model.tut_allows(s, "folio_open") and typeof(data) == TYPE_DICTIONARY and String(data.get("kind", "")) == "clip" and String(data.get("id", "")) != ""

func drop_folio(data) -> void:
	new_folio_from(String(data.get("id", "")))

func drag_entry(eid: String, from: Control) -> Variant:
	var s = sim_ref()
	if s == null:
		return null
	var vm := Model.entry_vm(s, eid)
	if vm.is_empty():
		return null
	_preview(from, Widgets.chip("%s · %s" % [Model.tx(s, "ledger.asiento", {"n": int(vm.n)}), String(vm.tname)]))
	return {"kind": "entry", "id": eid}

func drag_clip(id: String, text: String, from: Control) -> Variant:
	_preview(from, Widgets.chip(text))
	return {"kind": "clip", "id": id}

# set_drag_preview sólo vale dentro de un arrastre del motor (las pruebas llaman a drag_* directamente).
func _preview(from: Control, chip: Control) -> void:
	if from.is_inside_tree() and from.get_viewport().gui_is_dragging():
		from.set_drag_preview(chip)
	else:
		chip.free()

# ------------------------------------------------------------------ capa superior: elector y confirmación
func _anchor_rect(c: Control) -> Rect2:
	if c == null or not c.is_inside_tree():
		var vp := get_viewport().get_visible_rect().size
		return Rect2(vp * 0.5 - Vector2(180, 0), Vector2(360, 0))
	return c.get_global_transform() * Rect2(Vector2.ZERO, c.size)

func _open_picker(title: String, opts: Array, anchor: Control, empty_text: String, cb: Callable) -> void:
	_close_overlays()
	var p := Picker.new()
	p.setup(title, opts, _anchor_rect(anchor), empty_text, Model.tx(sim_ref(), "ledger.picker.buscar"))
	p.chosen.connect(func(id: String, o: Dictionary):
		_close_overlays()
		cb.call(id, o))
	p.dismissed.connect(_close_overlays)
	_layer_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer_top.add_child(p)
	_picker = p

func _open_confirm(title: String, body, ok_text: String, cb: Callable) -> void:
	_close_overlays()
	var holder := Control.new()
	holder.name = "Confirmacion"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(dim)
	var c = Widgets.confirm(body, ok_text, Widgets.t("kit.confirm.back"), title)
	holder.add_child(c)
	c.decided.connect(func(ok: bool):
		_close_overlays()
		cb.call(ok))
	_layer_top.add_child(holder)
	_confirm = c
	_center_confirm.call_deferred(c)

func _center_confirm(c: Control) -> void:
	if not is_instance_valid(c):
		return
	c.reset_size()
	var vp := get_viewport().get_visible_rect().size
	c.position = (vp - c.size) * 0.5

func _close_overlays() -> void:
	if _layer_top == null:
		return
	for ch in _layer_top.get_children():
		_layer_top.remove_child(ch)
		ch.queue_free()
	_picker = null
	_confirm = null

func picker() -> Control:
	return _picker if is_instance_valid(_picker) else null

func confirm_dialog() -> Control:
	return _confirm if is_instance_valid(_confirm) else null

# ------------------------------------------------------------------ volver, notas, sonido
# Lo que se puede deshacer dentro del libro sin cerrarlo: el elector, la confirmación, el asiento del acoplado.
func has_inner_back() -> bool:
	return picker() != null or confirm_dialog() != null or (compact and _compact_entry)

# Volver (Esc, clic derecho, Shell.pop): primero lo de adentro; si no queda nada, cierra el libro. true = consumido.
func back() -> bool:
	if picker() != null:
		_picker.dismiss()
		return true
	if confirm_dialog() != null:
		_confirm._decide(false)
		return true
	if compact and _compact_entry:
		_compact_entry = false
		refresh()
		return true
	if not visible:
		return false
	close()
	return true

func _on_backdrop() -> void:
	if picker() != null or confirm_dialog() != null:
		_close_overlays()
		return
	close()

# Clic derecho sobre el libro = volver, con o sin Shell (los controles de la hoja consumen los clics y el InputRouter
# no los vería): se mira en _input si el puntero está sobre el libro.
func _input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventMouseButton and ev.pressed and _is_back_button(ev):
		var hov := get_viewport().gui_get_hovered_control()
		if hov != null and _root.is_ancestor_of(hov):
			back()
			get_viewport().set_input_as_handled()

func _is_back_button(mb: InputEventMouseButton) -> bool:
	if InputMap.has_action("fe_volver"):
		return InputMap.event_is_action(mb, "fe_volver")
	return mb.button_index == MOUSE_BUTTON_RIGHT

# Esc: sin Shell lo maneja el libro; con Shell (handle_back = false) sólo consume lo de adentro y deja que la pila del
# Shell (InputRouter -> Shell.pop -> back) decida, para que Esc cierre lo que está arriba. L: sólo sin Shell (con Shell
# el InputRouter alterna el panel).
func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if InputMap.has_action("fe_volver") and ev.is_action_pressed("fe_volver"):
			# con Shell sólo se consume lo que se ve encima de todo (elector, confirmación); el asiento del acoplado lo
			# vuelve la pila del Shell con back() cuando el libro es lo de arriba (si arriba está el cuaderno, se cierra él)
			if handle_back or picker() != null or confirm_dialog() != null:
				back()
				get_viewport().set_input_as_handled()
		elif handle_hotkey and handle_back and InputMap.has_action("fe_libro_mayor") and ev.is_action_pressed("fe_libro_mayor") and not has_inner_back():
			close()
			get_viewport().set_input_as_handled()

func say(text: String) -> void:
	if text == "" or _note == null:
		return
	_note_label.text = plain(text)
	_note_label.add_theme_font_size_override("font_size", _px("ui"))
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
	return _note_label.text if _note_label != null else ""

func _sfx(id: String) -> void:
	if not sounds:
		return
	var au := _autoload("Audio")
	if au != null and au.has_method("play"):
		au.play(id)

func _sfx_event(nm: String) -> void:
	if not sounds:
		return
	var au := _autoload("Audio")
	if au != null and au.has_method("play_event"):
		au.play_event(nm)

func debug_state() -> Dictionary:
	return {"open": visible, "page": page, "selected": selected, "lot": lot.duplicate(), "picker": picker() != null,
		"confirm": confirm_dialog() != null, "note": last_note(), "scale": _stage.scale.x if _stage != null else 0.0,
		"compact": compact, "compact_entry": _compact_entry, "side": side, "rect": _back.get_rect() if _back != null else Rect2()}
