# ui/reader/document_reader.gd — lector de documentos a pantalla completa (CanvasLayer 30, fuera del grabado).
# Dueño: W2-READER. Contrato: ARCHITECTURE §6.4 (GDD§14.3, §8.1).
# Uso (Shell/W3): var r = preload("res://ui/reader/document_reader.gd").new(); add_child(r); r.open("D05@BM")
#   open(view_id) -> bool        Game.sim.q_view(view_id); sin partida (Game.sim == null) y fallback_repo: ViewModel.from_repo
#   open_view(view)              una vista ya armada (forma de q_view, §3.7)
#   close()                      oculta, restaura el cursor, emite closed
# Señales: closed · clipped(result) (clip_text aceptado) · plate_requested(plate) · tijera_changed(on) · page_changed(idx).
# Config: act_fn (Callable(a: Dictionary) -> Dictionary; por defecto Game.act) · handle_back (true: fe_volver cierra el
#   lector; Shell lo pone en false si maneja su pila y escucha closed) · sounds · fallback_repo · strip_target ·
#   emit_read (true: la primera vez que muestra cada hoja en la sesión emite la acción libre `read`, GDD_v2 §B.4).
# Interacción (mouse primero, §6.1): rueda = zoom 80–300 % en el puntero (fe_zoom_*); arrastrar el papel (fuera de la
#   tijera) o con el botón medio = desplazar; C (fe_tijera) = modo tijera: arrastrar sobre palabras y soltar ->
#   SelectionMapper.map -> Game.act({"t":"clip_text","src":{"kind":"doc","ref":view,"part":<hoja>,"block":<i>},...})
#   (part = índice int de la hoja en q_view.pages, block = índice del bloque en la hoja);
#   error -> línea de Lisle (ui_text clip.<err>); éxito -> la tira vuela al cuaderno. ←/→ hojas; ↑/↓ desplazan;
#   Esc / clic derecho = volver (con la tijera en la mano, primero la deja; después cierra el lector si handle_back).
# GDD_v2 §C.3 (revelado progresivo): al principio sólo el papel, la ficha (título y origen) y «Volver». «Tijera» aparece
#   con la bandera desk.tijera (q_ui); las flechas ‹ n/N ›, sólo si hay más de una hoja; el zoom va con la rueda y un
#   indicador «130 %» aparece sólo si el zoom no es el de lectura (clic = volver). Sin lupa ni regla (§C.5): la medida, el
#   papel y la mano los dice la línea de DESCRIPCIÓN FÍSICA que todo documento trae al principio (recortable).
# Sin brillos, contadores ni pistas: el lector no distingue lo importante (§6.1). Animaciones ≤0,4 s.
extends CanvasLayer

signal closed
signal clipped(result: Dictionary)
signal plate_requested(plate: String)
signal tijera_changed(on: bool)
signal page_changed(idx: int)

const L = preload("res://core/util/log.gd")
const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const PageView = preload("res://ui/reader/page_view.gd")
const UiFlags = preload("res://ui/kit/ui_flags.gd")
const ViewModel = preload("res://ui/reader/view_model.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")

const LAYER := 30
const ZOOM_MIN := 0.8
const ZOOM_MAX := 3.0
const ZOOM_STEP := 1.12
const TOOLS_W := 176.0
const NOTE_HOLD_S := 3.4
const FLY_S := 0.4
const PAN_KEY_PX := 70.0
const KEEP_VISIBLE_PX := 90.0

var act_fn: Callable = Callable()
var handle_back := true
var sounds := true
var fallback_repo := true
var emit_read := true
var strip_target := Vector2(-1, -1)  # adónde vuela la tira recortada (canvas); por defecto abajo a la izquierda (el cuaderno)

var view := {}
var page_idx := 0
var zoom := 1.0
var tijera := false
var px_per_mm := 3.0
var fit_zoom := 1.0             # zoom de lectura (el que pone _fit_view): el indicador sólo aparece fuera de él
var page: Control = null        # PageView visible

var _ui_built := false
var _root: Control
var _back: Control
var _area: Control
var _stage: Control
var _header: PanelContainer
var _title: Label
var _src: Label
var _tools: PanelContainer
var _b_tijera: Button
var _b_plate: Button
var _b_zoom: Button
var _b_close: Button
var _tijera_ok := true          # bandera desk.tijera (se relee al abrir)
var _pager: PanelContainer
var _page_label: Label
var _b_prev: Button
var _b_next: Button
var _note: PanelContainer
var _tij_help: Label = null
var _note_label: Label
var _note_tw: Tween = null
var _fly: Control
var _pan := false
var _pan_from := Vector2.ZERO
var _pan_start := Vector2.ZERO
var _mouse := Vector2(-10000, -10000)
var _cursor_set := false
var _busy := false
static var _read_sent := {}     # "vista|hoja" ya emitidas en la sesión (la acción read es libre; esto sólo evita repetirla)

class Backdrop extends Control:
	var lamp: GradientTexture2D
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(1.0, 0.86, 0.6, 0.13), Color(1.0, 0.86, 0.6, 0.0)])
		lamp = GradientTexture2D.new()
		lamp.gradient = g
		lamp.fill = GradientTexture2D.FILL_RADIAL
		lamp.fill_from = Vector2(0.5, 0.5)
		lamp.fill_to = Vector2(1.0, 0.5)
		lamp.width = 256
		lamp.height = 256
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if Paper.hc_on():
			draw_rect(r, Color(0.16, 0.16, 0.16))
			return
		draw_rect(r, Paper.MESA.darkened(0.12))
		var c := Vector2(size.x * 0.46, size.y * 0.42)
		var rad := maxf(size.x, size.y) * 0.62
		draw_texture_rect(lamp, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false)

func _init() -> void:
	layer = LAYER
	name = "DocumentReader"

func _ready() -> void:
	_build_ui()
	var ti := _ti()
	if ti != null and not ti.theme_changed.is_connected(_on_theme_changed):
		ti.theme_changed.connect(_on_theme_changed)
	var game := _autoload("Game")
	if game != null and game.has_signal("sim_changed") and not game.sim_changed.is_connected(_on_sim_changed):
		game.sim_changed.connect(_on_sim_changed)
	if game != null and game.has_signal("session_started") and not game.session_started.is_connected(reset_read_memory):
		game.session_started.connect(reset_read_memory)
	if view.is_empty():
		visible = false
	else:
		# abierto antes de entrar al árbol: la ficha y los útiles se ubican ahora que hay viewport
		_layout_chrome.call_deferred()
		_fit_view.call_deferred()

func _exit_tree() -> void:
	_set_cursor(false)

# ------------------------------------------------------------------ API
func open(view_id: String) -> bool:
	var v := {}
	var game := _autoload("Game")
	if game != null and game.get("sim") != null:
		v = game.sim.q_view(view_id)
	elif fallback_repo:
		var data := _autoload("Data")
		if data != null:
			v = ViewModel.from_repo(data.repo(), view_id)
	if typeof(v) != TYPE_DICTIONARY or v.is_empty():
		L.w("reader", "vista vacía o inaccesible: %s" % view_id)
		return false
	if String(v.get("view", "")) == "":
		v["view"] = view_id
	return open_view(v)

func open_view(v: Dictionary) -> bool:
	_build_ui()
	var nv := ViewModel.normalize(v)
	if nv.pages.is_empty():
		# sin texto: no se toca la hoja abierta (si la hay) salvo para cederle el lugar a la lámina 3D
		if String(nv.get("plate", "")) != "":
			if visible or page != null:
				close()
			plate_requested.emit(String(nv.plate))
			return true
		return false
	view = nv
	page_idx = 0
	if tijera:
		set_tijera(false)
	for c in _fly.get_children():
		c.queue_free()
	_tijera_ok = UiFlags.on(UiFlags.now(), "desk.tijera")
	_header_text()
	_compute_scale()
	_show_page(0, true)
	# la lectura de la primera hoja (acción `read`) puede encender banderas: en el prólogo, abrir el encargo trae la tijera
	_tijera_ok = UiFlags.on(UiFlags.now(), "desk.tijera")
	_sync_tools()
	visible = true
	_sfx("sfx.papel")
	return true

func close() -> void:
	if not visible and view.is_empty():
		return
	if tijera:
		set_tijera(false)
	_set_cursor(false)
	visible = false
	if page != null:
		page.queue_free()
		page = null
	for c in _fly.get_children():
		c.queue_free()
	view = {}
	closed.emit()

func set_tijera(on: bool) -> void:
	if on and not _tijera_ok:
		return   # la tijera todavía no está en la mano (prólogo, antes del paso «recortar»)
	if tijera == on:
		return
	tijera = on
	if page != null:
		page.set_tijera(on)
	_set_cursor(on)
	_sync_tools()
	tijera_changed.emit(on)

func set_zoom(z: float, focus := Vector2(-1, -1)) -> void:
	z = clampf(z, ZOOM_MIN, ZOOM_MAX)
	if focus.x < 0.0:
		focus = _area_rect().get_center()
	var local := (focus - _stage.position) / zoom
	zoom = z
	_stage.scale = Vector2(z, z)
	_stage.position = focus - local * z
	_clamp_pan()
	_sync_tools()
	_pointer_moved(_mouse)

func go_page(i: int) -> void:
	var n: int = view.get("pages", []).size()
	if n == 0 or i < 0 or i >= n or i == page_idx:
		return
	_show_page(i, false)
	_sfx("sfx.pagina")
	page_changed.emit(i)

func page_count() -> int:
	return view.get("pages", []).size()

# Mueve la lámpara como si el mouse estuviera en canvas_pos (capturas y tests).
func point_at(canvas_pos: Vector2) -> void:
	_pointer_moved(canvas_pos)

func debug_state() -> Dictionary:
	return {"view": view.get("view", ""), "page": page_idx, "pages": page_count(), "zoom": zoom, "tijera": tijera,
		"px_per_mm": px_per_mm, "paper_px": (page.size if page != null else Vector2.ZERO), "tools": tool_names()}

# Controles a la vista en el panel de útiles (revelado progresivo; tests y capturas): nombres de nodo visibles.
func tool_names() -> Array:
	var out: Array = []
	if not _ui_built:
		return out
	for b in [_b_tijera, _b_zoom, _pager, _b_plate, _b_close]:
		if b != null and b.visible:
			out.append(String(b.name))
	return out

# Rectángulo (canvas) del bloque i de la hoja visible (tests, drivers).
func block_rtl(i: int) -> RichTextLabel:
	if page == null or i < 0 or i >= page.blocks.size():
		return null
	return page.blocks[i]

# ------------------------------------------------------------------ armado
func _ti() -> Node:
	return _autoload("ThemeInstaller")

# Autoload por nombre aunque el lector todavía no esté en el árbol (get_node("/root/…") fuera del árbol es ERROR).
static func _autoload(n: String) -> Node:
	var ml = Engine.get_main_loop()
	if ml is SceneTree and ml.root != null:
		return ml.root.get_node_or_null(n)
	return null

func _t(key: String, vars := {}) -> String:
	return Widgets.t(key, vars)

func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true
	_root = Control.new()
	_root.name = "Raiz"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.gui_input.connect(_on_root_input)
	add_child(_root)
	_back = Backdrop.new()
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_back)
	_area = Control.new()
	_area.name = "Area"
	_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_PASS
	_area.clip_contents = true
	_root.add_child(_area)
	_stage = Control.new()
	_stage.name = "Escenario"
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	_area.add_child(_stage)
	# --- ficha del documento (arriba a la izquierda)
	_header = Widgets.paper_panel("cuaderno", null, {"margin": 16, "margin_v": 11, "shadow_size": 6})
	_header.position = Vector2(22, 20)
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 3)
	_header.add_child(hv)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(300, 0)
	hv.add_child(_title)
	_src = Widgets.source_line("")
	_src.custom_minimum_size = Vector2(300, 0)
	hv.add_child(_src)
	_root.add_child(_header)
	# --- útiles (derecha)
	_tools = Widgets.paper_panel("cuaderno", null, {"margin": 12, "margin_v": 12, "shadow_size": 6})
	_tools.mouse_filter = Control.MOUSE_FILTER_STOP
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 8)
	_tools.add_child(tv)
	_b_tijera = _toggle(_t("reader.tool.tijera"), func(on): set_tijera(on))
	_b_tijera.name = "Tijera"
	tv.add_child(_b_tijera)
	# ayuda de una línea (§C.1) mientras la tijera está en la mano y todavía no se recortó nada
	_tij_help = Widgets.label(_t("reader.tijera_ayuda"), "SmallLabel")
	_tij_help.name = "TijeraAyuda"
	_tij_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tij_help.custom_minimum_size = Vector2(TOOLS_W - 48.0, 0)
	_tij_help.add_theme_color_override("font_color", Paper.ink("tenue"))
	_tij_help.visible = false
	tv.add_child(_tij_help)
	# indicador de zoom: sólo fuera del zoom de lectura; clic = volver a él (la rueda es el zoom)
	_b_zoom = Widgets.ink_button("", func(): _fit_view())
	_b_zoom.name = "Zoom"
	_b_zoom.tooltip_text = _t("v2d.reader.zoom_volver")
	tv.add_child(_b_zoom)
	# --- hojas (sólo si hay más de una)
	_pager = PanelContainer.new()
	_pager.name = "Hojas"
	_pager.add_theme_stylebox_override("panel", Paper.empty([0, 0, 0, 0]))
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 2)
	_b_prev = Widgets.ink_button(_t("reader.prev"), func(): go_page(page_idx - 1))
	_b_next = Widgets.ink_button(_t("reader.next"), func(): go_page(page_idx + 1))
	_page_label = Widgets.label("", "SmallLabel")
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(_b_prev)
	ph.add_child(_page_label)
	ph.add_child(_b_next)
	_pager.add_child(ph)
	tv.add_child(_pager)
	_b_plate = Widgets.ink_button(_t("reader.plate"), func(): plate_requested.emit(String(view.get("plate", ""))))
	_b_plate.name = "Lamina"
	tv.add_child(_b_plate)
	_b_close = Widgets.ink_button(_t("reader.close"), func(): close())
	_b_close.name = "Volver"
	tv.add_child(_b_close)
	_tools.custom_minimum_size = Vector2(TOOLS_W - 24.0, 0)
	_root.add_child(_tools)
	# --- nota de Lisle (abajo a la izquierda)
	_note = Widgets.paper_panel("cuaderno", null, {"margin": 14, "margin_v": 8, "shadow_size": 5})
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_label = Widgets.marginal("")
	_note_label.custom_minimum_size = Vector2(280, 0)
	_note.add_child(_note_label)
	_note.modulate.a = 0.0
	_note.visible = false
	_root.add_child(_note)
	_fly = Control.new()
	_fly.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fly)
	_restyle_chrome()
	get_viewport_safe_connect()

func get_viewport_safe_connect() -> void:
	if is_inside_tree():
		var vp := get_viewport()
		if vp != null and not vp.size_changed.is_connected(_on_vp_resized):
			vp.size_changed.connect(_on_vp_resized)

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE and _ui_built:
		get_viewport_safe_connect.call_deferred()

func _toggle(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggled.connect(func(on): if not _busy: cb.call(on))
	return b

func _restyle_chrome() -> void:
	var ti := _ti()
	if _title != null:
		_title.add_theme_font_override("font", ti.font("imprenta") if ti != null else ThemeDB.fallback_font)
		_title.add_theme_font_size_override("font_size", int(round((21.0 if ti == null else float(ti.px("ui"))) * 1.12)))
		_title.add_theme_color_override("font_color", Paper.ink("negra"))
	if _back != null:
		_back.queue_redraw()
	if _b_zoom != null:
		_b_zoom.add_theme_font_size_override("font_size", 17 if ti == null else ti.px("small") + 1)
	_layout_chrome()

func _layout_chrome() -> void:
	if not _ui_built or not is_inside_tree():
		return
	var vp := _vp_size()
	_tools.reset_size()
	_tools.position = Vector2(vp.x - _tools.size.x - 20.0, 20.0)
	_note.reset_size()
	_note.position = Vector2(22.0, vp.y - _note.size.y - 22.0)

func _vp_size() -> Vector2:
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	return Vector2(1600, 900)

# Todo lo que no tapan los útiles (límite del desplazamiento).
func _area_rect() -> Rect2:
	var vp := _vp_size()
	return Rect2(Vector2.ZERO, Vector2(vp.x - TOOLS_W, vp.y))

# Donde se apoya la hoja al abrir: entre la ficha (izquierda) y los útiles (derecha).
func _read_rect() -> Rect2:
	var vp := _vp_size()
	var left := 24.0
	if _header != null and _header.visible:
		left = _header.position.x + _header.size.x + 24.0
	return Rect2(Vector2(left, 0), Vector2(maxf(200.0, vp.x - TOOLS_W - 8.0 - left), vp.y))

func _header_text() -> void:
	var t := String(view.get("title", ""))
	var s := String(view.get("src_line", ""))
	if t != "" and s.begins_with(t):
		s = s.substr(t.length()).lstrip(" ,.;:·—–-").strip_edges()
	_title.text = t
	_src.text = s
	_src.visible = s != ""
	_header.visible = t != "" or s != ""
	_header.reset_size()

# Todas las hojas de una vista usan la misma px_per_mm (la mayor que pida alguna), así el papel no cambia de tamaño.
func _compute_scale() -> void:
	var best := 0.0
	var n: int = view.pages.size()
	for i in n:
		var pv = PageView.new()
		pv.visible = false
		_stage.add_child(pv)
		pv.setup(view, i, {"interactive": false})
		best = maxf(best, pv.px_per_mm)
		_stage.remove_child(pv)
		pv.free()
	px_per_mm = best if best > 0.0 else 3.0

func _show_page(i: int, refit: bool) -> void:
	if page != null:
		if page.get_parent() == _stage:
			_stage.remove_child(page)
		page.free()
		page = null
	page_idx = i
	page = PageView.new()
	page.name = "Hoja%d" % i
	_stage.add_child(page)
	_stage.move_child(page, 0)
	page.setup(view, i, {"px_per_mm": px_per_mm})
	page.block_pressed.connect(_on_block_pressed)
	page.block_released.connect(_on_block_released)
	page.set_tijera(tijera)
	if page.overflow:
		L.w("reader", "%s hoja %d: el texto no cabe en el papel (%s mm)" % [view.get("view", ""), i, str(view.paper_mm)])
	if refit:
		_fit_view()
	else:
		_stage.position.y = 36.0
		_clamp_pan()
	_sync_pager()
	_pointer_moved(_mouse)
	_emit_read(i)

func _fit_view() -> void:
	if page == null:
		return
	var ar := _read_rect()
	var ps: Vector2 = page.size
	var avail := ar.size - Vector2(48.0, 72.0)
	# a lo ancho entra entera; a lo alto se lee desplazando (la letra no baja de 100 % por una hoja larga)
	var z := clampf(minf(1.0, avail.x / ps.x), ZOOM_MIN, ZOOM_MAX)
	if ps.y * z > avail.y and ps.y * ZOOM_MIN <= avail.y:
		z = maxf(ZOOM_MIN, minf(z, avail.y / ps.y))
	zoom = z
	fit_zoom = z
	_stage.scale = Vector2(z, z)
	var x := ar.position.x + (ar.size.x - ps.x * z) * 0.5
	var y := (ar.size.y - ps.y * z) * 0.5 if ps.y * z <= avail.y else 36.0
	_stage.position = Vector2(x, maxf(y, 24.0))
	_sync_tools()

func _clamp_pan() -> void:
	if page == null:
		return
	var ar := _area_rect()
	var ps: Vector2 = page.size * zoom
	var p := _stage.position
	p.x = clampf(p.x, ar.position.x + KEEP_VISIBLE_PX - ps.x, ar.end.x - KEEP_VISIBLE_PX)
	p.y = clampf(p.y, ar.position.y + KEEP_VISIBLE_PX - ps.y, ar.end.y - KEEP_VISIBLE_PX)
	_stage.position = p

func _sync_tools() -> void:
	if not _ui_built:
		return
	_busy = true
	_b_tijera.button_pressed = tijera
	_busy = false
	_b_tijera.visible = _tijera_ok
	if _tij_help != null:
		_tij_help.visible = tijera and not UiFlags.on(UiFlags.now(), "hud.cuaderno")
	# relativo al tamaño de lectura: «100 %» es como se abrió el papel (el indicador sólo aparece fuera de él)
	_b_zoom.text = _t("reader.zoom.pct", {"n": int(round(zoom / maxf(0.01, fit_zoom) * 100.0))})
	_b_zoom.visible = absf(zoom - fit_zoom) > 0.01
	_b_plate.visible = String(view.get("plate", "")) != ""
	_layout_chrome.call_deferred()

func _sync_pager() -> void:
	var n := page_count()
	_pager.visible = n > 1
	_page_label.text = _t("reader.page", {"n": page_idx + 1, "total": n})
	_b_prev.disabled = page_idx <= 0
	_b_next.disabled = page_idx >= n - 1
	_layout_chrome.call_deferred()

# ------------------------------------------------------------------ entrada
func _on_root_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventMouseMotion:
		_pointer_moved(_canvas_mouse())
		if _pan:
			_stage.position = _pan_start + (_canvas_mouse() - _pan_from)
			_clamp_pan()
		_root.accept_event()     # nada de lo que pasa sobre el lector llega al 3D de abajo
		return
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev
		# rueda = fe_zoom_mas / fe_zoom_menos del input map (§6.1)
		var zin := _is_action(mb, "fe_zoom_mas", MOUSE_BUTTON_WHEEL_UP)
		var zout := _is_action(mb, "fe_zoom_menos", MOUSE_BUTTON_WHEEL_DOWN)
		if mb.pressed and (zin or zout):
			var f := ZOOM_STEP if zin else 1.0 / ZOOM_STEP
			if mb.factor > 0.0 and mb.factor != 1.0:
				f = pow(f, clampf(mb.factor, 0.2, 3.0))
			set_zoom(zoom * f, _canvas_mouse())
			_root.accept_event()
			return
		if _is_action(mb, "fe_volver", MOUSE_BUTTON_RIGHT):
			if mb.pressed and tijera:
				set_tijera(false)          # volver: primero se deja la tijera, después el papel
				_root.accept_event()
			elif mb.pressed and handle_back:
				close()
				_root.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and not tijera):
			if mb.pressed:
				_pan = true
				_pan_from = _canvas_mouse()
				_pan_start = _stage.position
				_root.mouse_default_cursor_shape = Control.CURSOR_DRAG
			else:
				_pan = false
				_root.mouse_default_cursor_shape = Control.CURSOR_ARROW
			_root.accept_event()
			return
		_root.accept_event()

func _unhandled_input(ev: InputEvent) -> void:
	if not visible or view.is_empty():
		return
	if ev.is_action_pressed("fe_tijera"):
		if _tijera_ok:
			set_tijera(not tijera)
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("fe_volver") and tijera:
		set_tijera(false)
		get_viewport().set_input_as_handled()
	elif handle_back and ev.is_action_pressed("fe_volver"):
		close()
		get_viewport().set_input_as_handled()
	elif ev is InputEventKey and ev.pressed:
		var k: InputEventKey = ev
		var used := true
		match k.keycode:
			KEY_LEFT, KEY_PAGEUP:
				if page_count() > 1:
					go_page(page_idx - 1)
				else:
					_nudge(Vector2(PAN_KEY_PX, 0))
			KEY_RIGHT, KEY_PAGEDOWN:
				if page_count() > 1:
					go_page(page_idx + 1)
				else:
					_nudge(Vector2(-PAN_KEY_PX, 0))
			KEY_UP:
				_nudge(Vector2(0, PAN_KEY_PX))
			KEY_DOWN:
				_nudge(Vector2(0, -PAN_KEY_PX))
			KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
				set_zoom(zoom * ZOOM_STEP)
			KEY_MINUS, KEY_KP_SUBTRACT:
				set_zoom(zoom / ZOOM_STEP)
			_:
				used = false
		if used:
			get_viewport().set_input_as_handled()

# ¿El botón del mouse corresponde a la acción del input map? (sin la acción registrada: el botón por defecto)
func _is_action(mb: InputEventMouseButton, action: String, fallback: MouseButton) -> bool:
	if InputMap.has_action(action):
		return InputMap.event_is_action(mb, action)
	return mb.button_index == fallback

func _nudge(d: Vector2) -> void:
	_stage.position += d
	_clamp_pan()

func _canvas_mouse() -> Vector2:
	return _root.get_global_mouse_position()

func _pointer_moved(pos: Vector2) -> void:
	_mouse = pos
	if page != null:
		page.set_light(pos, zoom)

# GDD_v2 §B.4: la primera vez que se muestra cada hoja en la sesión, la acción libre `read` (Lisle se entera de lo que
# nombra esa hoja; el mapa crece leyendo). Sin partida, o si la partida ya la tiene anotada, no se emite.
func _emit_read(i: int) -> void:
	if not emit_read:
		return
	var vid := String(view.get("view", ""))
	if vid == "":
		return
	var key := "%s|%d" % [vid, i]
	if _read_sent.has(key):
		return
	var game := _autoload("Game")
	var sim = game.get("sim") if game != null else null
	if not act_fn.is_valid() and sim == null:
		return
	if sim != null and sim.has_method("q_read") and (sim.q_read(vid) as Array).has(i):
		_read_sent[key] = true
		return
	var res := _act({"t": "read", "view": vid, "part": i})
	if bool(res.get("ok", false)):
		_read_sent[key] = true

static func reset_read_memory() -> void:
	_read_sent.clear()

# ------------------------------------------------------------------ tijera
func _on_block_pressed(_idx: int, pos: Vector2) -> void:
	_pointer_moved(pos)

func _on_block_released(idx: int, pos: Vector2) -> void:
	_try_clip.call_deferred(idx, pos)

func _try_clip(idx: int, pos: Vector2) -> void:
	if page == null or idx >= page.blocks.size():
		return
	var r: RichTextLabel = page.blocks[idx]
	var sel := r.get_selected_text()
	if sel == "":
		return
	var pt: Dictionary = page.parsed[idx]
	var m := SelectionMapper.map(r, pt)
	if not m.ok:
		L.w("reader", "selección que no cuadra con plain: from=%d «%s»" % [r.get_selection_from(), sel.left(60)])
		r.deselect()
		_say(_t("reader.no_cuadra"))
		return
	var a := {"t": "clip_text", "src": {"kind": "doc", "ref": String(view.get("view", "")), "part": page_idx, "block": idx},
		"from": int(m.from), "len": int(m.len)}
	var res := _act(a)
	r.deselect()
	if bool(res.get("ok", false)):
		_sfx("sfx.tijera")
		var txt := _clip_text_of(res)
		if txt == "":
			txt = SelectionMapper.preview(pt, int(m.from), int(m.len)).text
		_fly_strip(txt, pos)
		clipped.emit(res)
	else:
		_say(_err_text(String(res.get("err", ""))))

func _act(a: Dictionary) -> Dictionary:
	if act_fn.is_valid():
		var r = act_fn.call(a)
		return r if typeof(r) == TYPE_DICTIONARY else {"ok": false, "err": "desconocido"}
	var game := _autoload("Game")
	if game == null:
		return {"ok": false, "err": "no_sim"}
	return game.act(a)

func _clip_text_of(res: Dictionary) -> String:
	if res.has("text"):
		return String(res.text)
	var game := _autoload("Game")
	if game != null and game.get("sim") != null and res.has("clip"):
		var c = game.sim.q_clip(String(res.clip))
		if typeof(c) == TYPE_DICTIONARY:
			return String(c.get("text", ""))
	return ""

func _err_text(err: String) -> String:
	var data := _autoload("Data")
	if data != null and data.repo() != null:
		var tx: Dictionary = data.repo().texts()
		for k in ["clip." + err, "core.err." + err]:
			if tx.has(k):
				return data.repo().text(k, {"n": "tres"})
		return data.repo().text("core.err.desconocido")
	return err

func _say(text: String) -> void:
	if text == "":
		return
	_note_label.text = text
	_note.visible = true
	_layout_chrome()
	if _note_tw != null and _note_tw.is_valid():
		_note_tw.kill()
	_note_tw = _note.create_tween()
	_note_tw.tween_property(_note, "modulate:a", 1.0, 0.25)
	_note_tw.tween_interval(NOTE_HOLD_S)
	_note_tw.tween_property(_note, "modulate:a", 0.0, 0.4)
	_note_tw.tween_callback(func(): _note.visible = false)

func _fly_strip(text: String, from_pos: Vector2) -> void:
	if text == "":
		return
	var strip := PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", Paper.style(String(view.get("paper", "cuaderno")), {"margin": 10, "margin_v": 4, "radius": 0, "shadow_size": 6, "shadow_y": 3}))
	var l := Label.new()
	var ti := _ti()
	if ti != null:
		var fslot := String(view.get("font", "imprenta"))
		l.add_theme_font_override("font", ti.font(fslot))
		l.add_theme_font_size_override("font_size", TextBuilder.slot_size(fslot, ti))
	l.add_theme_color_override("font_color", Paper.ink("negra"))
	l.text = text if text.length() <= 64 else text.left(61) + "…"
	strip.add_child(l)
	_fly.add_child(strip)
	strip.reset_size()
	var sz := strip.get_combined_minimum_size()
	strip.size = sz
	strip.pivot_offset = sz * 0.5
	strip.position = from_pos - sz * 0.5
	strip.rotation_degrees = -1.5
	strip.scale = Vector2(zoom, zoom)
	var vp := _vp_size()
	var target := (strip_target if strip_target.x >= 0.0 else Vector2(64.0, vp.y - 40.0)) - sz * 0.5
	var tw := strip.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(strip, "position", target, FLY_S)
	tw.tween_property(strip, "scale", Vector2(0.3, 0.3), FLY_S)
	tw.tween_property(strip, "rotation_degrees", -10.0, FLY_S)
	tw.tween_property(strip, "modulate:a", 0.0, FLY_S * 0.45).set_delay(FLY_S * 0.55)
	tw.chain().tween_callback(strip.queue_free)

func _sfx(id: String) -> void:
	if not sounds:
		return
	var au := _autoload("Audio")
	if au != null and au.has_method("play"):
		au.play(id)

# Cursor de tijera (dibujado por código; sólo en modo tijera, se restaura al salir).
static var _scissors: ImageTexture = null

static func scissors_texture() -> ImageTexture:
	if _scissors != null:
		return _scissors
	var n := 32
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var piv := Vector2(13.0, 13.0)
	var segs := [[Vector2(1.5, 8.0), piv], [Vector2(8.0, 1.5), piv], [piv, Vector2(20.0, 23.0)], [piv, Vector2(23.0, 20.0)]]
	var rings := [Vector2(22.5, 26.0), Vector2(26.0, 22.5)]
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := 1e9
			for s in segs:
				d = minf(d, _seg_d(p, s[0], s[1]))
			for c in rings:
				d = minf(d, absf(p.distance_to(c) - 3.6))
			var ink := clampf(1.6 - d, 0.0, 1.0)
			var halo := clampf(3.0 - d, 0.0, 1.0)
			if halo > 0.0:
				var col := Color(1.0, 0.98, 0.93, halo * 0.95).lerp(Color(0.1, 0.08, 0.06, 1.0), ink)
				col.a = maxf(halo * 0.95, ink)
				img.set_pixel(x, y, col)
	_scissors = ImageTexture.create_from_image(img)
	return _scissors

static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length()

func _set_cursor(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if on:
		Input.set_custom_mouse_cursor(scissors_texture(), Input.CURSOR_IBEAM, Vector2(3, 3))
		_cursor_set = true
	elif _cursor_set:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_IBEAM)
		_cursor_set = false

# ------------------------------------------------------------------ tema
func _on_theme_changed() -> void:
	TextBuilder.clear_caches()
	_restyle_chrome()
	if view.is_empty() or page == null:
		return
	var keep_zoom := zoom
	var keep_pos := _stage.position
	_header_text()
	_compute_scale()
	_show_page(page_idx, false)
	zoom = keep_zoom
	_stage.scale = Vector2(zoom, zoom)
	_stage.position = keep_pos
	_clamp_pan()
	_sync_tools()

# Una bandera puede encenderse con el lector abierto (prólogo: leer el encargo -> paso «recortar» -> aparece «Tijera»).
func _on_sim_changed(_kind: String, _payload: Dictionary) -> void:
	if not visible or not _ui_built:
		return
	var ok := UiFlags.on(UiFlags.now(), "desk.tijera")
	if ok != _tijera_ok:
		_tijera_ok = ok
		_sync_tools()
	elif _tij_help != null and _tij_help.visible:
		_sync_tools()   # el primer recorte se lleva la ayuda de la tijera

func _on_vp_resized() -> void:
	_layout_chrome()
	_clamp_pan()
