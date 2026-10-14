# ui/desk/speech.gd — líneas dichas en la escena (fixed scenes, líneas automáticas de un lugar, respuestas) cuando el
# panel de escena de W3-SCENEUI no las muestra, y nota del instructor del prólogo (pinned). Dueño: W3-SHELL.
# Cada línea: quién la dice (nombre sólo si se presentó: lo resuelve q_scene) y el texto, recortable con la tijera
# (src {kind:"line", ref:uid}). Cola: clic en la tarjeta o en «Seguir» (botón siempre a la vista; en la última línea
# cierra la tarjeta) pasa a la siguiente. Sin brillos ni contadores.
# Nota del instructor (pinned): dock = Rect2 libre donde acoplarse (un margen de un libro abierto; vacío = arriba a la
# izquierda) con letra algo menor; link_cb (Callable(ent)) hace clicables las menciones de la nota que nombran un
# objeto de la lámina (link_ok(ent) -> bool decide cuáles): se subrayan a lápiz (forma, no contenido: es la instrucción
# del instructor) y un clic las muestra.
# push_lines([{uid, who_label, parsed}]) · clear() · set_scissors(on) · showing() -> bool · señales clipped(result), emptied.
extends PanelContainer

signal clipped(result: Dictionary)
signal emptied

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const ClipLabel = preload("res://ui/desk/clip_label.gd")

const DOCK_PX := 17

var pinned := false
var max_w := 660.0
var queue: Array = []
var current := {}
var who_label: Label
var text: RichTextLabel
var more: Button
var link_cb: Callable = Callable()
var link_ok: Callable = Callable()
var dock := Rect2():
	set(v):
		if v.is_equal_approx(dock):
			return
		var was_docked := dock.size.x > 0.0
		dock = v
		if text != null:
			_apply_width()
			if was_docked != (dock.size.x > 0.0) and not current.is_empty():
				_show_current(false)
			elif visible:
				_place()
var _scissors := false
var _links: Array = []          # [{from, to, ent}] menciones clicables de la nota
var _underline: Control
var _refit_queued := false
var bottom_inset := 0.0:
	set(v):
		bottom_inset = v
		if visible and is_inside_tree():
			_place()

func _init(p_pinned := false) -> void:
	pinned = p_pinned
	name = "Tutor" if pinned else "Speech"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if pinned:
		max_w = 360.0
	Widgets.restyle(self, func(): add_theme_stylebox_override("panel", Paper.style("cuaderno" if pinned else "carta", {"margin": 16 if pinned else 22, "shadow": true, "shadow_size": 6 if pinned else 10})))

func _ready() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	who_label = Widgets.label("", "SourceLine")
	who_label.uppercase = true
	who_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who_label.clip_text = true
	who_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(who_label)
	text = ClipLabel.new()
	text.clipped.connect(func(r): clipped.emit(r))
	v.add_child(text)
	_underline = Underline.new()
	_underline.host = self
	text.add_child(_underline)
	_underline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# «Seguir» a la vista (W4: un «›» chico arriba no se veía y nada decía que la tarjeta pasaba con un clic)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	more = Widgets.button(Widgets.t("shell.speech.seguir"), advance)
	more.name = "Seguir"
	more.visible = false
	foot.add_child(more)
	_apply_width()
	gui_input.connect(_on_input)
	text.gui_input.connect(_on_text_input)
	get_viewport().size_changed.connect(_place)
	# el alto del texto (RichTextLabel con fit_content) se conoce recién con el ancho puesto: cuando cambia el mínimo, la
	# tarjeta se vuelve a ajustar (antes quedaba con el alto de la línea anterior o del texto medido angosto, con un hueco
	# grande debajo)
	minimum_size_changed.connect(func():
		if visible and not _refit_queued:
			_refit_queued = true
			_refit.call_deferred())

func _apply_width() -> void:
	var w := dock.size.x if dock.size.x > 0.0 else max_w
	text.custom_minimum_size = Vector2(maxf(120.0, w - (36.0 if pinned else 44.0)), 0)

func _on_input(ev: InputEvent) -> void:
	if pinned or _scissors:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		accept_event()
		advance()

# Nota del instructor: un clic sobre una mención clicable la muestra (link_cb); el cursor lo dice al pasar.
func _on_text_input(ev: InputEvent) -> void:
	if not pinned or _scissors or _links.is_empty():
		return
	if ev is InputEventMouseMotion:
		text.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if link_at((ev as InputEventMouseMotion).position) != "" else Control.CURSOR_ARROW
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		var ent := link_at((ev as InputEventMouseButton).position)
		if ent != "" and link_cb.is_valid():
			text.accept_event()
			link_cb.call(ent)

func showing() -> bool:
	return visible

func push_lines(lines: Array) -> void:
	if pinned:
		if lines.is_empty():
			return
		current = lines[-1]
		_show_current()
		return
	queue.append_array(lines)
	if not visible or current.is_empty():
		advance()
	else:
		more.visible = true

func advance() -> void:
	if queue.is_empty():
		current = {}
		visible = false
		emptied.emit()
		return
	current = queue.pop_front()
	_show_current()

func clear() -> void:
	var had := not current.is_empty() or not queue.is_empty()
	queue.clear()
	current = {}
	visible = false
	if had and not pinned:
		emptied.emit()

func _show_current(fade := true) -> void:
	who_label.text = String(current.get("who_label", ""))
	who_label.visible = who_label.text != ""
	var src := {"kind": "line", "ref": String(current.get("uid", ""))} if String(current.get("uid", "")) != "" else {}
	var px := DOCK_PX if pinned and dock.size.x > 0.0 else 0
	if px > 0:
		var ti := Widgets.ti()
		if ti != null:
			px = int(round(float(px) * float(ti.text_scale)))
	(text as ClipLabel).setup(current.get("parsed", {}), src, "imprenta", px)
	(text as ClipLabel).set_scissors(_scissors)
	_collect_links()
	# también en la última línea (verificador v3): al final de la presentación del prólogo la tarjeta de Harris quedaba
	# sin botón y la primera nota del instructor («abra el expediente») esperaba a que se fuera: nada decía qué hacer
	more.visible = not pinned
	visible = true
	if fade:
		modulate.a = 0.0
		Widgets.fade(self, 1.0, 0.2)
	_place.call_deferred()

# Menciones de la nota que nombran algo de la lámina (link_ok): clicables y subrayadas.
func _collect_links() -> void:
	_links = []
	if pinned and link_ok.is_valid():
		for m in current.get("parsed", {}).get("mentions", []):
			if typeof(m) == TYPE_DICTIONARY and bool(link_ok.call(String(m.get("ent", "")))):
				_links.append({"from": int(m.get("from", 0)), "to": int(m.get("to", 0)), "ent": String(m.get("ent", ""))})
	if _underline != null:
		_underline.queue_redraw()

func links() -> Array:
	return _links.duplicate(true)

# Vuelve a decidir qué menciones son clicables (cambió la lámina o el encuadre).
func refresh_links() -> void:
	if pinned and not current.is_empty():
		_collect_links()

# Entidad de la mención clicable bajo un punto (local del texto); "" si no hay.
func link_at(local: Vector2) -> String:
	for l in _links:
		for s in segments(int(l.from), int(l.to)):
			if Rect2(Vector2(s.x0, s.y0), Vector2(s.x1 - s.x0, s.y1 - s.y0)).grow(3.0).has_point(local):
				return String(l.ent)
	return ""

# Renglones que ocupa [from, to) del texto (local del RichTextLabel): [{x0, x1, y0, y1}].
func segments(from: int, to: int) -> Array:
	var out: Array = []
	if text == null or to <= from:
		return out
	var plain := text.get_parsed_text()
	if plain == "":
		return out
	var f: Font = text.get_theme_font("normal_font")
	var fs: int = text.get_theme_font_size("normal_font_size")
	var l0 := text.get_character_line(from)
	var l1 := text.get_character_line(maxi(from, to - 1))
	if l0 < 0 or l1 < 0:
		return out
	for ln in range(l0, l1 + 1):
		var lr: Vector2i = text.get_line_range(ln)
		var a := maxi(from, lr.x)
		var b := mini(to, lr.y)
		var seg := plain.substr(a, maxi(0, b - a)).strip_edges(false, true)
		var x0 := f.get_string_size(plain.substr(lr.x, a - lr.x), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x1 := x0 + f.get_string_size(seg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y0 := float(text.get_line_offset(ln))
		out.append({"x0": x0, "x1": x1, "y0": y0, "y1": y0 + float(text.get_line_height(ln))})
	return out

class Underline extends Control:
	var host = null
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if host == null:
			return
		var c := Paper.ink("lapiz")
		c.a = 0.8
		for l in host._links:
			for s in host.segments(int(l.from), int(l.to)):
				var y: float = s.y1 - 3.0
				draw_line(Vector2(s.x0, y), Vector2(s.x1, y + 0.5), c, 1.4, true)

func _refit() -> void:
	_refit_queued = false
	_place()

func set_scissors(on: bool) -> void:
	_scissors = on
	if text != null:
		(text as ClipLabel).set_scissors(on)

func _place() -> void:
	if not is_inside_tree():
		return
	var vs := get_viewport().get_visible_rect().size
	reset_size()
	if pinned:
		if dock.size.x > 0.0:
			size.x = dock.size.x
			position = dock.position.floor()
		else:
			size.x = minf(max_w, vs.x * 0.3)
			position = Vector2(22, 230)
	else:
		size.x = minf(max_w, vs.x - 80.0)
		position = Vector2((vs.x - size.x) * 0.5, vs.y - size.y - 34.0 - bottom_inset)
	if _underline != null:
		_underline.queue_redraw()
