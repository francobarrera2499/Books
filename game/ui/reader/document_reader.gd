# ui/reader/document_reader.gd — lector de documentos (CanvasLayer 30). Dueño: LECTOR (antes W2-READER).
# Contrato: ARCHITECTURE §6.4 (GDD§14.3, §8.1) con los cambios de GDD_v3 §6.7.
# Uso (Shell): var r = preload("res://ui/reader/document_reader.gd").new(); add_child(r); r.open("D05@BM")
#   open(view_id) -> bool        Game.sim.q_view(view_id); sin partida (Game.sim == null) y fallback_repo: ViewModel.from_repo
#   open_view(view)              una vista ya armada (forma de q_view, §3.7 + v3: ficha, marks, slot/anchor/hand por bloque)
#   close()                      oculta, restaura el cursor, emite closed
# Señales: closed · clipped(result) (clip_text aceptado) · plate_requested(plate) · tijera_changed(on) · page_changed(idx).
# Config: act_fn (Callable(a: Dictionary) -> Dictionary; por defecto Game.act) · handle_back (true: fe_volver cierra el
#   lector; Shell lo pone en false si maneja su pila y escucha closed) · sounds · fallback_repo · strip_target ·
#   emit_read (true: la primera vez que muestra cada hoja en la sesión emite la acción libre `read`, GDD_v2 §B.4) ·
#   blur_mode ("pantalla": el fondo lee la textura de pantalla; "captura": plan B de GDD_v3 §8.8, una captura del
#   viewport al abrir, reducida con mipmaps).
# v3 (GDD_v3 §6.7) — el documento FLOTA frente al jugador:
#   - Fondo: la pieza 3D (todo lo que hay debajo de la capa 30) desenfocada y oscurecida un 25 % (backdrop.gdshader). En
#     alto contraste, un gris liso.
#   - El papel es recto (el texto nunca se rota), con sombra en perspectiva (polígono inclinado 2°, corrido 10/14 px) y una
#     luz muy leve de arriba a la izquierda (PageView floating). Notas al margen, marquitas, ficha y tarjeta: PageView.
#   - Tijera: un ícono suelto (dibujado por código, tinta con halo claro, 28 px) arriba a la derecha, afuera del papel; sin
#     recuadro ni la palabra «Tijera». Clic o C la toman o la dejan; en la mano, el cursor es una tijera y el ícono queda
#     como hueco. Mientras no se recortó nada, una línea de ayuda debajo (GDD_v2 §C.1).
#   - Paginación abajo al centro: «‹  2 / 5  ›» (flechas clicables; ←/→ también). Con una sola hoja, nada. El indicador
#     de zoom («130 %», clic = volver al de lectura) aparece al lado sólo fuera del zoom de lectura.
#   - Arriba a la izquierda, sin recuadro: título y origen del papel, «Ver la imagen» (si tiene) y «Volver».
# Interacción (mouse primero): rueda = desplazar (playtest v3); Ctrl + rueda o +/− = zoom 80–300 % en el puntero
#   (fe_zoom_*); arrastrar el papel (fuera de la tijera)
#   o con el botón medio = desplazar; tijera: arrastrar sobre palabras y soltar -> SelectionMapper.map ->
#   act({"t":"clip_text","src":{"kind":"doc","ref":<vista>,"part":<hoja>,"block":<i>},...}) (part = índice de la hoja en
#   q_view.pages, block = índice del bloque en la hoja, sea cuerpo, nota al margen o tarjeta); error -> línea de Lisle
#   (ui_text clip.<err>); éxito -> la tira vuela al cuaderno. ↑/↓ desplazan; Esc / clic derecho = volver (con la tijera
#   en la mano, primero la deja; después cierra el lector si handle_back).
# Revelado progresivo (GDD_v2 §C.3): la tijera aparece con la bandera desk.tijera (q_ui). Sin brillos, contadores ni
#   pistas: el lector no distingue lo importante. Animaciones ≤0,4 s.
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
const BACKDROP = preload("res://ui/reader/backdrop.gdshader")

const LAYER := 30
const ZOOM_MIN := 0.8
const ZOOM_MAX := 3.0
const ZOOM_STEP := 1.12
const NOTE_HOLD_S := 3.4
const FLY_S := 0.4
const FADE_S := 0.18
const PAN_KEY_PX := 70.0
const WHEEL_PX := 60.0          # una muesca de la rueda desplaza la hoja
const KEEP_VISIBLE_PX := 90.0
const TOP_PAD := 22.0           # arriba del papel al abrir
const BOTTOM_BAND := 74.0       # franja de abajo: la paginación
const SIDE_COL := 92.0          # columna derecha: la tijera
const CAPTION_W := 220.0        # título y origen, arriba a la izquierda
const ICON_PX := 28.0
const ICON_BOX := 48.0
const DIM := 0.25               # oscurecido del fondo
const MEASURE_CAP := 1.15       # la línea, como mucho 15 % más larga que la cómoda (si no cabe, la hoja se alarga)
const BLUR_LOD := 2.5
const LIGHT := Color("efe6d2")  # letra clara sobre el fondo desenfocado

var act_fn: Callable = Callable()
var handle_back := true
var sounds := true
var fallback_repo := true
var emit_read := true
var blur_mode := "pantalla"
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
var _back: ColorRect
var _back_mat: ShaderMaterial
var _area: Control
var _scrim: TextureRect
var _stage: Control
var _caption: VBoxContainer
var _header: Control = null      # = _caption (alias: GameScreen._tutor_dock acopla la nota del instructor debajo de él)
var _title: Label
var _src: Label
var _b_tijera: ScissorsIcon     # ícono suelto (nombre de nodo «Tijera»)
var _b_plate: Button
var _b_zoom: Button
var _b_close: Button
var _tijera_ok := true          # bandera desk.tijera (se relee al abrir)
var _bottom: HBoxContainer
var _pager: PanelContainer
var _page_label: Label
var _b_prev: Button
var _b_next: Button
var _note: PanelContainer
var _tij_help: Label = null
var _note_label: Label
var _note_tw: Tween = null
var _fade_tw: Tween = null
var _fly: Control
var _pan := false
var _pan_from := Vector2.ZERO
var _pan_start := Vector2.ZERO
var _mouse := Vector2(-10000, -10000)
var _cursor_set := false
static var _read_sent := {}     # "vista|hoja" ya emitidas en la sesión (la acción read es libre; esto sólo evita repetirla)

# ------------------------------------------------------------------ ícono de la tijera
# Tijera de tinta con halo claro (se lee sobre el fondo oscuro y sobre el papel). on = en la mano: queda el hueco.
class ScissorsIcon extends Control:
	signal pressed_icon
	var on := false
	var hover := false
	var hc := false

	func _init() -> void:
		custom_minimum_size = Vector2(48, 48)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				pressed_icon.emit()
			accept_event()

	func _notification(what: int) -> void:
		match what:
			NOTIFICATION_MOUSE_ENTER:
				hover = true
				queue_redraw()
			NOTIFICATION_MOUSE_EXIT:
				hover = false
				queue_redraw()

	# Tijera abierta, con las hojas hacia arriba (V) y los anillos abajo, separados: se lee como ✂ aun a 28 px.
	static func strokes() -> Dictionary:
		var piv := Vector2(16.0, 15.5)
		var ra := Vector2(9.0, 25.5)
		var rb := Vector2(23.0, 25.5)
		return {"blades": [[Vector2(7.5, 1.5), piv], [Vector2(24.5, 1.5), piv]],
			"handles": [[piv, rb + (piv - rb).normalized() * 4.3], [piv, ra + (piv - ra).normalized() * 4.3]],
			"rings": [ra, rb], "ring_r": 4.3, "piv": piv}

	func _draw() -> void:
		var k := 28.0 / 32.0
		var o := (size - Vector2(28.0, 28.0)) * 0.5
		var s := strokes()
		var ink := Color(0, 0, 0, 1) if hc else Color("1b1712")
		var halo := Color(1, 1, 1, 1) if hc else Color(0.97, 0.94, 0.87, 0.95 if hover else 0.78)
		if on:
			ink.a *= 0.3
			halo.a *= 0.5
		for pass_i in 2:
			var col := halo if pass_i == 0 else ink
			var extra := 3.0 if pass_i == 0 else 0.0
			for b in s.blades:
				var tip: Vector2 = o + b[0] * k
				var pv: Vector2 = o + b[1] * k
				var dir := (pv - tip).normalized()
				var nrm := Vector2(-dir.y, dir.x)
				var w0 := 0.35 + extra * 0.5
				var w1 := 1.5 + extra * 0.5
				var back := pv + dir * 2.0
				draw_colored_polygon(PackedVector2Array([tip - dir * extra * 0.4 + nrm * w0, back + nrm * w1, back - nrm * w1, tip - dir * extra * 0.4 - nrm * w0]), col)
			for h in s.handles:
				draw_line(o + h[0] * k, o + h[1] * k, col, 1.7 + extra, true)
			for c in s.rings:
				draw_arc(o + c * k, float(s.ring_r) * k, 0.0, TAU, 24, col, 1.8 + extra, true)
			draw_circle(o + s.piv * k, 1.3 + extra * 0.5, col)

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
		# abierto antes de entrar al árbol: el título y los útiles se ubican ahora que hay viewport
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
		# sin texto: no se toca la hoja abierta (si la hay) salvo para cederle el lugar a la imagen 3D
		if String(nv.get("plate", "")) != "":
			if visible or page != null:
				close()
			plate_requested.emit(String(nv.plate))
			return true
		return false
	var was_visible := visible
	if String(nv.get("view", "")) != String(view.get("view", "")):
		_hide_note()
	view = nv
	page_idx = 0
	if tijera:
		set_tijera(false)
	for c in _fly.get_children():
		c.queue_free()
	_tijera_ok = UiFlags.on(UiFlags.now(), "desk.tijera")
	if not was_visible:
		_prepare_backdrop()
	_header_text()
	_compute_scale()
	_show_page(0, true)
	# la lectura de la primera hoja (acción `read`) puede encender banderas: en el prólogo, abrir el encargo trae la tijera
	_tijera_ok = UiFlags.on(UiFlags.now(), "desk.tijera")
	_sync_tools()
	visible = true
	if not was_visible:
		_fade_in()
	_sfx("sfx.papel")
	return true

func close() -> void:
	if not visible and view.is_empty():
		return
	if tijera:
		set_tijera(false)
	_set_cursor(false)
	visible = false
	_hide_note()
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
		"px_per_mm": px_per_mm, "paper_px": (page.size if page != null else Vector2.ZERO), "tools": tool_names(),
		"card": page != null and bool(page.card), "margin": page != null and bool(page.margin_col),
		"ficha": page != null and page.ficha_rtl != null, "blur": blur_mode}

# Controles a la vista (revelado progresivo; tests y capturas): nombres de nodo visibles.
func tool_names() -> Array:
	var out: Array = []
	if not _ui_built or not visible:
		return out
	for b in [_b_tijera, _b_zoom, _pager, _b_plate, _b_close]:
		if b != null and b.visible:
			out.append(String(b.name))
	return out

# RichTextLabel del bloque i de la hoja visible (tests, drivers).
func block_rtl(i: int) -> RichTextLabel:
	if page == null or i < 0 or i >= page.blocks.size():
		return null
	return page.blocks[i]

# Rectángulos en pantalla (canvas) del papel visible, del ícono de la tijera y de la paginación (tests, drivers).
func paper_rect() -> Rect2:
	if page == null:
		return Rect2()
	return Rect2(_stage.position + page.position * zoom, page.size * zoom)

func scissors_rect() -> Rect2:
	return _b_tijera.get_global_rect() if _ui_built and _b_tijera.visible else Rect2()

func pager_rect() -> Rect2:
	return _pager.get_global_rect() if _ui_built and _pager.visible else Rect2()

# Título, origen y «Volver» (arriba a la izquierda): GameScreen acopla debajo la nota del instructor (antes leía _header,
# que sigue como alias de este bloque).
func caption_rect() -> Rect2:
	return _caption.get_global_rect() if _ui_built and visible and _caption.is_visible_in_tree() else Rect2()

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

# Texto propio del lector v3 (ui_text lector.*); sin repo, el texto por defecto.
func _tl(key: String, def: String, vars := {}) -> String:
	var s := Widgets.t(key, vars)
	if s == key:
		s = def
		for k in vars:
			s = s.replace("${%s}" % k, str(vars[k]))
	return s

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
	# --- fondo: la pieza desenfocada
	_back = ColorRect.new()
	_back.name = "Fondo"
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_mat = ShaderMaterial.new()
	_back_mat.shader = BACKDROP
	_back_mat.set_shader_parameter("blur_lod", BLUR_LOD)
	_back_mat.set_shader_parameter("dim", DIM)
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
	# velo oscuro abajo: la paginación se lee aunque una hoja larga pase por debajo (y avisa que la hoja sigue)
	_scrim = TextureRect.new()
	_scrim.name = "Velo"
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var sg := Gradient.new()
	sg.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	sg.colors = PackedColorArray([Color(0.05, 0.04, 0.03, 0.0), Color(0.05, 0.04, 0.03, 0.42), Color(0.05, 0.04, 0.03, 0.72)])
	var gt := GradientTexture2D.new()
	gt.gradient = sg
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	_scrim.texture = gt
	_root.add_child(_scrim)
	# --- título, origen y enlaces (arriba a la izquierda, sin recuadro)
	_caption = VBoxContainer.new()
	_caption.name = "Titulo"
	_caption.position = Vector2(24, 20)
	_caption.custom_minimum_size = Vector2(CAPTION_W, 0)
	_caption.add_theme_constant_override("separation", 2)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header = _caption
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(CAPTION_W, 0)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_child(_title)
	_src = Label.new()
	_src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_src.custom_minimum_size = Vector2(CAPTION_W, 0)
	_src.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_child(_src)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_child(sp)
	_b_plate = _link(_t("reader.plate"), func(): plate_requested.emit(String(view.get("plate", ""))))
	_b_plate.name = "Lamina"
	_caption.add_child(_b_plate)
	_b_close = _link(_t("reader.close"), func(): close())
	_b_close.name = "Volver"
	_caption.add_child(_b_close)
	_root.add_child(_caption)
	# --- tijera: ícono suelto arriba a la derecha
	_b_tijera = ScissorsIcon.new()
	_b_tijera.name = "Tijera"
	_b_tijera.pressed_icon.connect(func(): set_tijera(not tijera))
	_root.add_child(_b_tijera)
	_tij_help = Label.new()
	_tij_help.name = "TijeraAyuda"
	_tij_help.text = _t("reader.tijera_ayuda")
	_tij_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tij_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tij_help.custom_minimum_size = Vector2(230, 0)
	_tij_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tij_help.visible = false
	_root.add_child(_tij_help)
	# --- abajo al centro: «‹  2 / 5  ›» y el indicador de zoom
	_bottom = HBoxContainer.new()
	_bottom.name = "Abajo"
	_bottom.add_theme_constant_override("separation", 12)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pager = PanelContainer.new()
	_pager.name = "Hojas"
	_pager.mouse_filter = Control.MOUSE_FILTER_STOP
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 6)
	ph.alignment = BoxContainer.ALIGNMENT_CENTER
	_b_prev = _arrow(_t("reader.prev"), func(): go_page(page_idx - 1))
	_b_prev.name = "Anterior"
	_b_next = _arrow(_t("reader.next"), func(): go_page(page_idx + 1))
	_b_next.name = "Siguiente"
	_page_label = Label.new()
	_page_label.name = "Numero"
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.custom_minimum_size = Vector2(64, 0)
	_page_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(_b_prev)
	ph.add_child(_page_label)
	ph.add_child(_b_next)
	_pager.add_child(ph)
	_bottom.add_child(_pager)
	_b_zoom = Button.new()
	_b_zoom.name = "Zoom"
	_b_zoom.focus_mode = Control.FOCUS_NONE
	_b_zoom.pressed.connect(func(): _fit_view())
	_b_zoom.tooltip_text = _t("v2d.reader.zoom_volver")
	_bottom.add_child(_b_zoom)
	_root.add_child(_bottom)
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

# Enlace de texto claro, sin recuadro (Volver, Ver la imagen).
func _link(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	return b

func _arrow(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(40, 0)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	return b

func _pill() -> StyleBoxFlat:
	var hcm := Paper.hc_on()
	var sb := Paper.flat(Color(0, 0, 0, 0.85) if hcm else Color(0.07, 0.055, 0.04, 0.72), Color(0, 0, 0, 0), [0, 0, 0, 0], 20, [16, 0, 16, 2])
	return sb

func _restyle_chrome() -> void:
	var ti := _ti()
	var hcm := Paper.hc_on()
	var ui_px := 19.0 if ti == null else float(ti.px("ui"))
	var small_px := 15.0 if ti == null else float(ti.px("small"))
	var light := Color(1, 1, 1, 1) if hcm else LIGHT
	var shadow := Color(0, 0, 0, 0.0 if hcm else 0.55)
	if _back != null:
		if hcm:
			_back.material = null
			_back.color = Color(0.16, 0.16, 0.16)
		else:
			_back.material = _back_mat
			_back.color = Color(1, 1, 1, 1)
	for l in [_title, _src, _page_label, _tij_help]:
		if l == null:
			continue
		l.add_theme_color_override("font_color", light)
		l.add_theme_color_override("font_shadow_color", shadow)
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
		l.add_theme_constant_override("shadow_outline_size", 0 if hcm else 3)
	if _title != null:
		_title.add_theme_font_override("font", ti.font("imprenta") if ti != null else ThemeDB.fallback_font)
		_title.add_theme_font_size_override("font_size", int(round(ui_px * 1.12)))
	if _src != null:
		_src.add_theme_font_override("font", ti.font("imprenta", true) if ti != null else ThemeDB.fallback_font)
		_src.add_theme_font_size_override("font_size", int(round(small_px + 1.0)))
		_src.add_theme_color_override("font_color", Color(light, 0.8))
	if _tij_help != null:
		_tij_help.add_theme_font_override("font", ti.font("imprenta", true) if ti != null else ThemeDB.fallback_font)
		_tij_help.add_theme_font_size_override("font_size", int(round(small_px + 1.0)))
	if _page_label != null:
		_page_label.add_theme_font_override("font", ti.font("imprenta") if ti != null else ThemeDB.fallback_font)
		_page_label.add_theme_font_size_override("font_size", int(round(ui_px)))
	for b in [_b_plate, _b_close, _b_prev, _b_next, _b_zoom]:
		if b == null:
			continue
		var big: bool = b == _b_prev or b == _b_next
		b.add_theme_font_override("font", ti.font("imprenta") if ti != null else ThemeDB.fallback_font)
		b.add_theme_font_size_override("font_size", int(round(ui_px * (1.9 if big else 1.0))))
		b.add_theme_color_override("font_color", Color(light, 0.88))
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		b.add_theme_color_override("font_pressed_color", Color(light, 0.7))
		b.add_theme_color_override("font_disabled_color", Color(light, 0.25))
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.0 if hcm else 0.45))
		b.add_theme_constant_override("outline_size", 0 if hcm else 3)
		var empty := Paper.empty([6, 2, 6, 2])
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(st, empty)
	if _pager != null:
		_pager.add_theme_stylebox_override("panel", _pill())
	if _b_zoom != null:
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			_b_zoom.add_theme_stylebox_override(st, _pill())
	if _b_tijera != null:
		_b_tijera.hc = hcm
		_b_tijera.queue_redraw()
	_layout_chrome()

func _layout_chrome() -> void:
	if not _ui_built or not is_inside_tree():
		return
	var vp := _vp_size()
	_caption.reset_size()
	_caption.position = Vector2(24, 20)
	_b_tijera.size = Vector2(ICON_BOX, ICON_BOX)
	_place_scissors()
	_bottom.reset_size()
	_bottom.position = Vector2(round((vp.x - _bottom.size.x) * 0.5), vp.y - _bottom.size.y - 16.0)
	_scrim.position = Vector2(0, vp.y - 120.0)
	_scrim.size = Vector2(vp.x, 120.0)
	_sync_scrim()
	_note.reset_size()
	_note.position = Vector2(22.0, vp.y - _note.size.y - 22.0)

# La tijera va anclada a la esquina de arriba a la derecha del papel, apenas afuera (playtest v3: en la esquina de la
# pantalla quedaba lejos de la hoja y no se encontraba); sigue al papel al desplazarlo o acercarlo y nunca sale de la
# pantalla. Su ayuda, debajo.
func _place_scissors() -> void:
	if not _ui_built or _b_tijera == null:
		return
	var vp := _vp_size()
	var pos := Vector2(vp.x - ICON_BOX - 22.0, 16.0)
	if page != null and page.size.x > 0.0:
		var pr := paper_rect()
		pos = Vector2(minf(pr.end.x + 10.0, vp.x - ICON_BOX - 8.0), clampf(pr.position.y, 16.0, maxf(16.0, vp.y - BOTTOM_BAND - ICON_BOX)))
	pos = pos.round()
	if _b_tijera.position != pos:
		_b_tijera.position = pos
	if _tij_help != null and _tij_help.visible:
		_tij_help.reset_size()
		_tij_help.position = Vector2(clampf(pos.x + ICON_BOX - _tij_help.size.x, 8.0, vp.x - _tij_help.size.x - 8.0), pos.y + ICON_BOX + 2.0)

func _process(_dt: float) -> void:
	if visible and _ui_built and page != null:
		_place_scissors()
		_sync_scrim()

# El velo de abajo sólo cuando la hoja sigue por debajo de la paginación (avisa que hay más); una hoja que cabe, o una
# larga ya desplazada hasta su pie, no se oscurece. En alto contraste nunca: bajaba el contraste de los últimos renglones.
func _sync_scrim() -> void:
	if _scrim == null:
		return
	var show := page != null and not Paper.hc_on() and paper_rect().end.y > _vp_size().y - BOTTOM_BAND + 2.0
	if _scrim.visible != show:
		_scrim.visible = show

func _vp_size() -> Vector2:
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	return Vector2(1600, 900)

# Límite del desplazamiento: toda la pantalla.
func _area_rect() -> Rect2:
	return Rect2(Vector2.ZERO, _vp_size())

# Donde se apoya la hoja al abrir: entre el título (izquierda) y la tijera (derecha), sobre la franja de la paginación.
func _read_rect() -> Rect2:
	var vp := _vp_size()
	var left := 24.0
	if _caption != null and _caption.visible:
		left = _caption.position.x + maxf(_caption.size.x, CAPTION_W) + 24.0
	var right := vp.x - SIDE_COL
	return Rect2(Vector2(left, TOP_PAD), Vector2(maxf(200.0, right - left), maxf(200.0, vp.y - TOP_PAD - BOTTOM_BAND)))

func _header_text() -> void:
	var t := String(view.get("title", ""))
	var s := String(view.get("src_line", ""))
	if t != "" and s.begins_with(t):
		s = s.substr(t.length()).lstrip(" ,.;:·—–-").strip_edges()
	_title.text = t
	_title.visible = t != ""
	_src.text = s
	_src.visible = s != ""
	_caption.reset_size()

# Todas las hojas de una vista usan la misma px_per_mm (la mayor que pida alguna), así el papel no cambia de tamaño. La
# tarjeta del cliente no cuenta (es más chica y toma la de la crónica).
func _compute_scale() -> void:
	var best := 0.0
	var best_card := 0.0
	var n: int = view.pages.size()
	for i in n:
		var pv = PageView.new()
		pv.visible = false
		_stage.add_child(pv)
		pv.setup(view, i, {"interactive": false, "measure_cap": MEASURE_CAP})
		if pv.card:
			best_card = maxf(best_card, pv.px_per_mm)
		else:
			best = maxf(best, pv.px_per_mm)
		_stage.remove_child(pv)
		pv.free()
	if best <= 0.0:
		best = best_card
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
	page.setup(view, i, {"px_per_mm": px_per_mm, "floating": true})
	page.block_pressed.connect(_on_block_pressed)
	page.block_released.connect(_on_block_released)
	page.set_tijera(tijera)
	if page.overflow and not page.card and px_per_mm >= PageView.P_MAX - 1e-3:
		L.w("reader", "%s hoja %d: el texto no cabe en el papel (%s mm)" % [view.get("view", ""), i, str(view.paper_mm)])
	if refit:
		_fit_view()
	else:
		_place(zoom)
		_clamp_pan()
	_sync_pager()
	_pointer_moved(_mouse)
	_emit_read(i)

func _fit_view() -> void:
	if page == null:
		return
	var ar := _read_rect()
	var ps: Vector2 = page.size
	# a lo ancho entra entera; a lo alto se lee desplazando (la letra no baja de 80 % por una hoja larga)
	var z := clampf(minf(1.0, ar.size.x / ps.x), ZOOM_MIN, ZOOM_MAX)
	if ps.y * z > ar.size.y and ps.y * ZOOM_MIN <= ar.size.y:
		z = maxf(ZOOM_MIN, minf(z, ar.size.y / ps.y))
	zoom = z
	fit_zoom = z
	_stage.scale = Vector2(z, z)
	_place(z)
	_sync_tools()

# Ubica la hoja a zoom z: centrada en la pantalla si no tapa el título ni la tijera (si no, centrada entre los dos); a lo
# alto, centrada si cabe y si no, desde arriba.
func _place(z: float) -> void:
	if page == null:
		return
	var vp := _vp_size()
	var ar := _read_rect()
	var w: float = page.size.x * z
	var h: float = page.size.y * z
	var x := (vp.x - w) * 0.5
	if x < ar.position.x or x + w > ar.end.x:
		x = ar.position.x + (ar.size.x - w) * 0.5
	var y := ar.position.y + (ar.size.y - h) * 0.5 if h <= ar.size.y else ar.position.y + 12.0
	if page.card:
		y += 14.0 * page.px_per_mm * z * 0.5   # el clip sobresale arriba de la tarjeta
	_stage.position = Vector2(round(x), round(maxf(y, 16.0)))

# Una hoja más alta (o más ancha) que el lugar de lectura no se pasa de sus bordes: con ↓ o arrastrando se llega hasta su
# último renglón, que queda arriba de la paginación, y nunca se ve fondo vacío ni se pierde la hoja (playtest de LECTOR:
# 40 × ↓ dejaba sólo 90 px de papel arriba). Una hoja que cabe se mueve libre, con al menos KEEP_VISIBLE_PX a la vista.
func _clamp_pan() -> void:
	if page == null:
		return
	var ar := _area_rect()
	var ps: Vector2 = page.size * zoom
	var p := _stage.position
	var top := TOP_PAD + 12.0
	var bot := ar.end.y - BOTTOM_BAND
	if ps.y > bot - top:
		p.y = clampf(p.y, bot - ps.y, top)
	else:
		p.y = clampf(p.y, ar.position.y + KEEP_VISIBLE_PX - ps.y, ar.end.y - KEEP_VISIBLE_PX)
	if ps.x > ar.size.x - 48.0:
		p.x = clampf(p.x, ar.end.x - 24.0 - ps.x, ar.position.x + 24.0)
	else:
		p.x = clampf(p.x, ar.position.x + KEEP_VISIBLE_PX - ps.x, ar.end.x - KEEP_VISIBLE_PX)
	_stage.position = p

func _sync_tools() -> void:
	if not _ui_built:
		return
	_b_tijera.visible = _tijera_ok
	_b_tijera.on = tijera
	_b_tijera.queue_redraw()
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
	_page_label.text = _tl("lector.pagina", "${n} / ${total}", {"n": page_idx + 1, "total": n})
	_b_prev.disabled = page_idx <= 0
	_b_next.disabled = page_idx >= n - 1
	_b_prev.tooltip_text = _tl("lector.pagina.anterior", "Hoja anterior")
	_b_next.tooltip_text = _tl("lector.pagina.siguiente", "Hoja siguiente")
	_layout_chrome.call_deferred()

# ------------------------------------------------------------------ fondo
func _prepare_backdrop() -> void:
	if _back_mat == null:
		return
	var use_cap := blur_mode == "captura" and DisplayServer.get_name() != "headless" and is_inside_tree()
	_back_mat.set_shader_parameter("use_capture", use_cap)
	if use_cap:
		var img := get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.resize(maxi(1, img.get_width() / 6), maxi(1, img.get_height() / 6), Image.INTERPOLATE_BILINEAR)
			img.generate_mipmaps()
			_back_mat.set_shader_parameter("capture_tex", ImageTexture.create_from_image(img))
			_back_mat.set_shader_parameter("cap_texel", Vector2(1.0 / float(img.get_width()), 1.0 / float(img.get_height())))
			_back_mat.set_shader_parameter("blur_lod", 0.8)
		else:
			_back_mat.set_shader_parameter("use_capture", false)
	else:
		_back_mat.set_shader_parameter("blur_lod", BLUR_LOD)

func _fade_in() -> void:
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	_root.modulate.a = 0.0
	if not is_inside_tree():
		_root.modulate.a = 1.0
		return
	_fade_tw = _root.create_tween()
	_fade_tw.tween_property(_root, "modulate:a", 1.0, FADE_S)

# ------------------------------------------------------------------ entrada
func _on_root_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventMouseMotion:
		var mp := _ev_pos(ev)
		_pointer_moved(mp)
		if _pan:
			_stage.position = _pan_start + (mp - _pan_from)
			_clamp_pan()
		_root.accept_event()     # nada de lo que pasa sobre el lector llega al 3D de abajo
		return
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev
		# playtest v3: la rueda DESPLAZA (las hojas largas se leían arrastrando, cosa que nada enseña); Ctrl + rueda (o
		# +/−) acerca. Mayúsculas + rueda o la rueda horizontal, de costado.
		var wb := mb.button_index
		if mb.pressed and not mb.ctrl_pressed and (wb == MOUSE_BUTTON_WHEEL_UP or wb == MOUSE_BUTTON_WHEEL_DOWN or wb == MOUSE_BUTTON_WHEEL_LEFT or wb == MOUSE_BUTTON_WHEEL_RIGHT):
			var amt := WHEEL_PX * (clampf(mb.factor, 0.2, 3.0) if mb.factor > 0.0 else 1.0)
			var d := Vector2.ZERO
			match wb:
				MOUSE_BUTTON_WHEEL_UP: d = Vector2(0, amt)
				MOUSE_BUTTON_WHEEL_DOWN: d = Vector2(0, -amt)
				MOUSE_BUTTON_WHEEL_LEFT: d = Vector2(amt, 0)
				MOUSE_BUTTON_WHEEL_RIGHT: d = Vector2(-amt, 0)
			if mb.shift_pressed: d = Vector2(d.y, d.x)
			_nudge(d)
			_root.accept_event()
			return
		# Ctrl + rueda = fe_zoom_mas / fe_zoom_menos del input map (§6.1)
		var zin := _is_action(mb, "fe_zoom_mas", MOUSE_BUTTON_WHEEL_UP)
		var zout := _is_action(mb, "fe_zoom_menos", MOUSE_BUTTON_WHEEL_DOWN)
		if mb.pressed and (zin or zout):
			var f := ZOOM_STEP if zin else 1.0 / ZOOM_STEP
			if mb.factor > 0.0 and mb.factor != 1.0:
				f = pow(f, clampf(mb.factor, 0.2, 3.0))
			set_zoom(zoom * f, _ev_pos(mb))
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
				_pan_from = _ev_pos(mb)
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

# Posición (canvas) de un evento de mouse que llega a _root: la del evento, no la del cursor del sistema (los eventos
# de los tests y drivers mandan; con el mouse real son lo mismo).
func _ev_pos(ev: InputEvent) -> Vector2:
	if ev is InputEventMouse:
		return _root.get_global_transform_with_canvas() * (ev as InputEventMouse).position
	return _canvas_mouse()

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
		_fly_strip(txt, pos, idx)
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
		for k in ["v3core.clip." + err, "clip." + err, "core.err." + err]:
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

# La línea de Lisle de un recorte fallido no sigue en pantalla al cerrar o al abrir otro papel.
func _hide_note() -> void:
	if _note_tw != null and _note_tw.is_valid():
		_note_tw.kill()
	_note_tw = null
	if _note != null:
		_note.visible = false
		_note.modulate.a = 0.0

func _fly_strip(text: String, from_pos: Vector2, idx := -1) -> void:
	if text == "":
		return
	var strip := PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bslot := ""
	if page != null and idx >= 0 and idx < page.slots.size():
		bslot = String(page.slots[idx])
	var spaper := "tarjeta" if bslot == "tarjeta" else String(view.get("paper", "cuaderno"))
	strip.add_theme_stylebox_override("panel", Paper.style(spaper, {"margin": 10, "margin_v": 4, "radius": 0, "shadow_size": 6, "shadow_y": 3}))
	var l := Label.new()
	var ti := _ti()
	if ti != null:
		var fslot := "manuscrito" if bslot in ["margen", "tarjeta"] else String(view.get("font", "imprenta"))
		l.add_theme_font_override("font", ti.font(fslot))
		l.add_theme_font_size_override("font_size", TextBuilder.slot_size(fslot, ti))
	l.add_theme_color_override("font_color", Paper.ink("lapiz" if bslot == "margen" else "negra"))
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

# Una bandera puede encenderse con el lector abierto (prólogo: leer el encargo -> paso «recortar» -> aparece la tijera).
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
